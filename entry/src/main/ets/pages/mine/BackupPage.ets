import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { util } from '@kit.ArkTS'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { csvField } from '../../common/TextUtil'
import { emitter } from '@kit.BasicServicesKit'
import { Database, HistoryItem, Summary, CategorySum, PeriodSum } from '../../data/Database'
import { FactorLibrary } from '../../data/FactorLibrary'

interface BackupRow {
  factor_id: string
  amount: number
  record_date: string
  note: string
  source: string
}

/** 备份与导出:JSON 全量备份/恢复 + CSV 报表(系统文件选择器) */
@Entry
@Component
struct BackupPage {
  // CSV 报表统计范围
  @State csvRangeIdx: number = 3
  private csvRanges: string[] = ['近7天', '近30天', '近90天', '全部']
  private csvDays: number[] = [7, 30, 90, 0]

  /** 把 rawfile 示例图复制到沙箱并写入图库(配合安全控件临时授权) */
  private importSample(fileName: string): Promise<void> {
    return new Promise<void>((resolve) => {
      const ctx = getContext(this) as common.UIAbilityContext
      ctx.resourceManager.getRawFileContent(fileName).then((data: Uint8Array) => {
        const dst: string = `${ctx.filesDir}/${fileName}`
        const f: fs.File = fs.openSync(dst, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        fs.writeSync(f.fd, data.buffer)
        fs.closeSync(f)
        const fileUri: string = `file://${dst}`
        const request = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(ctx, fileUri)
        const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx)
        helper.applyChanges(request).then(() => {
          resolve()
        }).catch(() => {
          resolve()
        })
      }).catch(() => {
        resolve()
      })
    })
  }

  private doImportSamples(): void {
    const names: string[] = ['meter_sample.jpg', 'guangpan_sample.jpg', 'bike_qr_sample.png']
    let done: number = 0
    for (const n of names) {
      this.importSample(n).then(() => {
        done++
        if (done === names.length) {
          toast('示例素材已导入图库,可在「记」页体验拍照识别 / 电表抄表 / 扫码录入')
        }
      })
    }
  }

  private async exportJson(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    opt.newFileNames = [`zeroisle-backup-${Database.today()}.json`]
    new picker.DocumentViewPicker().save(opt).then(async (uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      // 流式导出(E5):按分页拉取逐条落盘,避免大账本一次性进内存
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(file.fd, `{"app":"ZeroIsle","version":1,"exportedAt":"${new Date().toISOString()}","records":[`)
      const PAGE: number = 500
      let offset: number = 0
      let total: number = 0
      let first: boolean = true
      let go: boolean = true
      while (go) {
        const rows: HistoryItem[] = await Database.history(ctx, PAGE, offset)
        if (rows.length === 0) {
          go = false
          break
        }
        for (const r of rows) {
          const row: BackupRow = {
            factor_id: r.factorId,
            amount: r.amount,
            record_date: r.date,
            note: r.note ?? '',
            source: r.source
          }
          fs.writeSync(file.fd, (first ? '' : ',') + JSON.stringify(row))
          first = false
        }
        offset += rows.length
        total += rows.length
      }
      fs.writeSync(file.fd, ']}')
      fs.closeSync(file)
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`备份完成,共 ${total} 条记录`)
    }).catch(() => {
      toast('已取消保存')
    })
  }

  private async importJson(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const opt: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
    new picker.DocumentViewPicker().select(opt).then(async (uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
      const stat: fs.Stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
      let parsed: Record<string, Object>
      try {
        parsed = JSON.parse(text) as Record<string, Object>
      } catch (e) {
        toast('文件格式不正确(无法解析 JSON),请选择本应用导出的备份文件')
        return
      }
      const records = parsed['records'] as Array<BackupRow>
      if (!Array.isArray(records)) {
        toast('文件格式不正确')
        return
      }
      // 去重:按「日期|因子|数量」跳过库里已有与文件内重复的行,防止重复导入双倍记账
      const existing: Set<string> = await Database.existingRecordKeys(ctx)
      let ok: number = 0
      let done: number = 0
      let attempted: number = 0
      let dupSkipped: number = 0
      let invalid: number = 0
      for (const r of records) {
        if (typeof r.factor_id === 'string' && r.factor_id !== '' && r.amount > 0 && typeof r.record_date === 'string') {
          const key: string = `${r.record_date}|${r.factor_id}|${r.amount}`
          if (existing.has(key)) {
            dupSkipped++
            continue
          }
          existing.add(key)
          attempted++
          Database.insertRow(ctx, r.factor_id, r.amount, r.record_date, r.source ?? '备份', r.note ?? '').then(() => {
            ok++
            done++
            if (done === attempted) {
              emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
              this.importDoneToast(ok, attempted - ok, dupSkipped, invalid)
            }
          }).catch(() => {
            done++
            if (done === attempted) {
              emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
              this.importDoneToast(ok, attempted - ok, dupSkipped, invalid)
            }
          })
        } else {
          invalid++
        }
      }
      if (attempted === 0) {
        this.importDoneToast(0, 0, dupSkipped, invalid)
      }
    }).catch(() => {
      toast('已取消导入')
    })
  }

  /** 导入结束的汇总提示(按实际导入/失败/跳过原因分口径) */
  private importDoneToast(ok: number, failed: number, dup: number, invalid: number): void {
    let msg: string = `恢复完成,导入 ${ok} 条`
    if (failed > 0) {
      msg += `,失败 ${failed} 条`
    }
    if (dup > 0) {
      msg += `,跳过重复 ${dup} 条`
    }
    if (invalid > 0) {
      msg += `,无效 ${invalid} 条`
    }
    if (ok === 0 && failed === 0 && dup > 0 && invalid === 0) {
      msg = '备份里的记录都已存在,没有导入新数据(重复导入已拦截)'
    }
    toast(msg)
  }

  /** 报表统计范围的起始日期(空串=全部) */
  private csvStart(): string {
    const days: number = this.csvDays[this.csvRangeIdx]
    return days === 0 ? '' : Database.dateBefore(days - 1)
  }

  private nowText(): string {
    const d = new Date()
    const hh: string = d.getHours() < 10 ? '0' + d.getHours() : '' + d.getHours()
    const mi: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : '' + d.getMinutes()
    return `${Database.fmtDate(d)} ${hh}:${mi}`
  }

  /**
   * 导出统计报表(CSV):四段式结构 —— 报表概况 / 分类汇总 / 月度汇总 / 逐条明细
   * 汇总段先算好再流式写明细,避免大账本一次性进内存
   */
  private async exportCsv(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const start: string = this.csvStart()
    const sum: Summary = await Database.filterSummary(ctx, start, '', '')
    if (sum.count === 0) {
      toast('当前范围内暂无记录,换个统计范围再试')
      return
    }
    const cats: CategorySum[] = await Database.categoryStats(ctx, start, '')
    const months: PeriodSum[] = await Database.monthlySeries(ctx, start, '')
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    opt.newFileNames = [`zeroisle-report-${Database.today()}.csv`]
    new picker.DocumentViewPicker().save(opt).then(async (uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      // \uFEFF BOM:保证 Excel 直接打开不乱码
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      const rangeText: string = start === '' ? '全部记录' : `${start} ~ ${Database.today()}`
      fs.writeSync(file.fd, '\uFEFF零屿 ZeroIsle · 低碳行为统计报表\n')
      fs.writeSync(file.fd, `统计范围,${rangeText}\n`)
      fs.writeSync(file.fd, `生成时间,${this.nowText()}\n\n`)

      // 一、报表概况
      fs.writeSync(file.fd, '一、报表概况\n')
      fs.writeSync(file.fd, '记录条数,减排合计(kg CO2e),岛币合计,相当于少开车(km),相当于种树(棵)\n')
      fs.writeSync(file.fd, `${sum.count},${sum.totalCo2.toFixed(2)},${sum.totalPoints},${(sum.totalCo2 / 0.2).toFixed(0)},${(sum.totalCo2 / 10).toFixed(1)}\n\n`)

      // 二、分类汇总
      fs.writeSync(file.fd, '二、分类汇总\n')
      fs.writeSync(file.fd, '分类,记录条数,减排(kg CO2e),占比(%)\n')
      for (const c of cats) {
        const pct: number = sum.totalCo2 > 0 ? c.co2 / sum.totalCo2 * 100 : 0
        fs.writeSync(file.fd,
          `${csvField(FactorLibrary.categoryName(c.categoryId))},${c.cnt},${c.co2.toFixed(2)},${pct.toFixed(1)}\n`)
      }
      fs.writeSync(file.fd, '\n')

      // 三、月度汇总
      fs.writeSync(file.fd, '三、月度汇总\n')
      fs.writeSync(file.fd, '月份,记录条数,减排(kg CO2e)\n')
      for (const m of months) {
        fs.writeSync(file.fd, `${m.key},${m.cnt},${m.co2.toFixed(2)}\n`)
      }
      fs.writeSync(file.fd, '\n')

      // 四、逐条明细(分页流式)
      fs.writeSync(file.fd, '四、逐条明细\n')
      fs.writeSync(file.fd, '日期,行为,分类,数量,单位,减排(kg),岛币,来源,备注\n')
      const PAGE: number = 500
      let offset: number = 0
      let total: number = 0
      let go: boolean = true
      while (go) {
        const rows: HistoryItem[] = await Database.historyFilter(ctx, start, '', '', PAGE, offset)
        if (rows.length === 0) {
          go = false
          break
        }
        let chunk: string = ''
        for (const r of rows) {
          const fields: string[] = [
            r.date,
            csvField(r.name),
            csvField(FactorLibrary.categoryName(FactorLibrary.categoryOf(r.factorId))),
            `${r.amount}`,
            csvField(r.unit),
            r.co2Kg.toFixed(2),
            `${r.points}`,
            csvField(r.source),
            csvField(r.note)
          ]
          chunk += fields.join(',') + '\n'
        }
        fs.writeSync(file.fd, chunk)
        offset += rows.length
        total += rows.length
      }
      fs.closeSync(file)
      toast(`报表已导出:概况 + ${cats.length} 类汇总 + ${months.length} 个月汇总 + 明细 ${total} 行`)
    }).catch(() => {
      toast('已取消保存')
    })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text($r('app.string.title_backup')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Column() {
        this.actionCard('ic_backup', $r('app.color.brand_deep'), '导出 JSON 备份', '全部行为记录打包为 JSON,可跨设备恢复', '导出', (): void => {
          this.exportJson()
        })
        this.actionCard('ic_bill', $r('app.color.gold_deep'), '导入 JSON 恢复', '从备份文件恢复记录(追加导入,不覆盖现有)', '导入', (): void => {
          this.importJson()
        })
        // CSV 统计报表:可选统计范围,输出「概况 + 分类汇总 + 月度汇总 + 逐条明细」
        Column() {
          Row() {
            Column() {
              Image($rawfile('icons/ic_rank.svg'))
                .width(22).height(22).fillColor($r('app.color.text_light'))
            }
            .justifyContent(FlexAlign.Center)
            .width(42).height(42)
            .borderRadius(13)
            .backgroundColor('#4E8FB8')
            Column() {
              Text('导出统计报表').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
              Text('概况 / 分类汇总 / 月度汇总 / 逐条明细 四段式,Excel 可直接打开').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')

          Row({ space: 8 }) {
            Text('统计范围').fontSize(11).fontColor($r('app.color.text_sub'))
            ForEach(this.csvRanges, (r: string, idx: number) => {
              Text(r)
                .fontSize(11)
                .fontColor(this.csvRangeIdx === idx ? $r('app.color.text_light') : $r('app.color.text_main'))
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(this.csvRangeIdx === idx ? $r('app.color.primary') : $r('app.color.bg'))
                .borderRadius(999)
                .onClick(() => {
                  this.csvRangeIdx = idx
                })
            }, (r: string) => r)
          }
          .width('100%')
          .margin({ top: 10 })

          Button('导出报表')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .height(38)
            .backgroundColor($r('app.color.primary'))
            .borderRadius(ZeroTheme.radiusPill)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.exportCsv()
            })
            .margin({ top: 10 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(ZeroTheme.padM)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(ZeroTheme.radiusM)
        .margin({ top: 12 })

        Column() {
          Row() {
            Column() {
              Image($rawfile('icons/ic_camera.svg'))
                .width(22).height(22).fillColor($r('app.color.text_light'))
            }
            .justifyContent(FlexAlign.Center)
            .width(42).height(42)
            .borderRadius(13)
            .backgroundColor('#C583D6')
            Column() {
              Text('导入示例图片到图库').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
              Text('预置电表图、光盘海报与共享单车骑行码,用于体验 AI 录入矩阵').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')

          Row() {
            SaveButton({ text: SaveDescription.SAVE_IMAGE })
              .fontSize(13)
              .width('100%')
              .height(38)
              .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  this.doImportSamples()
                } else {
                  toast('临时授权未通过,无法写入图库')
                }
              })
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(ZeroTheme.padM)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(ZeroTheme.radiusM)
        .margin({ top: 12 })

              Column() {
          Text('说明').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text('· 全部数据存储在本机,不依赖任何云端\n· JSON 备份可用于换机迁移与宿舍数据包合并\n· CSV 报表满足碳普惠平台申报留存需求')
            .fontSize(11)
            .fontColor($r('app.color.text_sub'))
            .lineHeight(18)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(ZeroTheme.padM)
        .backgroundColor($r('app.color.bg'))
        .borderRadius(ZeroTheme.radiusM)
        .margin({ top: 12 })
      }
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: ZeroMotion.pageDurIn, curve: Curve.Friction })
      .opacity(0)
      .translate({ y: 16 })
    PageTransitionExit({ duration: ZeroMotion.pageDurOut, curve: Curve.Friction })
      .opacity(0)
  }

  @Builder
  actionCard(icon: string, tint: ResourceColor, title: string, desc: string, btn: string, action: () => void) {
    Row() {
      Column() {
        Image($rawfile(`icons/${icon}.svg`))
          .width(22).height(22).fillColor($r('app.color.text_light'))
      }
      .justifyContent(FlexAlign.Center)
      .width(42).height(42)
      .borderRadius(13)
      .backgroundColor(tint)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
        Text(desc).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
      Button(btn)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .height(ZeroTheme.btnHeightS)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(ZeroTheme.radiusPill)
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => {
          action()
        })
    }
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusM)
    .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
    .margin({ top: 10 })
  }
}
