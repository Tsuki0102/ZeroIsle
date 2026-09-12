import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { emitter } from '@kit.BasicServicesKit'
import { Database, HistoryItem } from '../../data/Database'
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
    const names: string[] = ['meter_sample.jpg', 'guangpan_sample.jpg']
    let done: number = 0
    for (const n of names) {
      this.importSample(n).then(() => {
        done++
        if (done === names.length) {
          toast('示例图片已导入图库,可在「记」页体验拍照识别与电表抄表')
        }
      })
    }
  }

  private async exportJson(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const rows: HistoryItem[] = await Database.history(ctx, 100000)
    const data: string = JSON.stringify({
      app: 'ZeroIsle',
      version: 1,
      exportedAt: new Date().toISOString(),
      records: rows.map((r: HistoryItem): BackupRow => {
        return {
          factor_id: r.factorId,
          amount: r.amount,
          record_date: r.date,
          note: '',
          source: r.source
        }
      })
    })
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    opt.newFileNames = [`zeroisle-backup-${Database.today()}.json`]
    new picker.DocumentViewPicker().save(opt).then((uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(file.fd, data)
      fs.closeSync(file)
      toast(`备份完成,共 ${rows.length} 条记录`)
    }).catch(() => {
      toast('已取消保存')
    })
  }

  private async importJson(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const opt: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
    new picker.DocumentViewPicker().select(opt).then((uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
      const stat: fs.Stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      const text: string = String.fromCharCode(...new Uint8Array(buf))
      const parsed = JSON.parse(text) as Record<string, Object>
      const records = parsed['records'] as Array<BackupRow>
      if (!Array.isArray(records)) {
        toast('文件格式不正确')
        return
      }
      let ok: number = 0
      const total: number = records.length
      for (const r of records) {
        if (typeof r.factor_id === 'string' && r.amount > 0 && typeof r.record_date === 'string') {
          Database.insertRow(ctx, r.factor_id, r.amount, r.record_date, r.source ?? '备份', r.note ?? '').then(() => {
            ok++
            if (ok === total) {
              emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
              toast(`恢复完成,导入 ${ok} 条记录`)
            }
          })
        }
      }
    }).catch(() => {
      toast('已取消导入')
    })
  }

  private async exportCsv(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const rows: HistoryItem[] = await Database.history(ctx, 100000)
    let csv: string = '日期,行为,分类,数量,单位,减排(kg),岛币,来源\n'
    for (const r of rows) {
      csv += `${r.date},"${r.name}",${FactorLibrary.categoryName(FactorLibrary.categoryOf(r.factorId))},${r.amount},${r.unit},${r.co2Kg.toFixed(2)},${r.points},${r.source}\n`
    }
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    opt.newFileNames = [`zeroisle-report-${Database.today()}.csv`]
    new picker.DocumentViewPicker().save(opt).then((uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(file.fd, csv)
      fs.closeSync(file)
      toast(`报表已导出,共 ${rows.length} 行`)
    }).catch(() => {
      toast('已取消保存')
    })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(ZeroTheme.textMain)
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('备份与导出').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Column() {
        this.actionCard('💾', '导出 JSON 备份', '全部行为记录打包为 JSON,可跨设备恢复', '导出', (): void => {
          this.exportJson()
        })
        this.actionCard('📥', '导入 JSON 恢复', '从备份文件恢复记录(追加导入,不覆盖现有)', '导入', (): void => {
          this.importJson()
        })
        this.actionCard('📊', '导出 CSV 报表', '日期/行为/分类/减排量表,可用 Excel 打开', '导出', (): void => {
          this.exportCsv()
        })

        Column() {
          Row() {
            Text('🖼️').fontSize(26)
            Column() {
              Text('导入示例图片到图库').fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
              Text('预置电表图与低碳行动海报,用于体验拍照识别与电表抄表').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 3 })
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
        .backgroundColor(ZeroTheme.cardBg)
        .borderRadius(ZeroTheme.radiusM)
        .margin({ top: 12 })

              Column() {
          Text('说明').fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
          Text('· 全部数据存储在本机,不依赖任何云端\n· JSON 备份可用于换机迁移与宿舍数据包合并\n· CSV 报表满足碳普惠平台申报留存需求')
            .fontSize(11)
            .fontColor(ZeroTheme.textSub)
            .lineHeight(18)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(ZeroTheme.padM)
        .backgroundColor(ZeroTheme.bg)
        .borderRadius(ZeroTheme.radiusM)
        .margin({ top: 12 })
      }
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZeroTheme.bg)
  }

  @Builder
  actionCard(icon: string, title: string, desc: string, btn: string, action: () => void) {
    Row() {
      Text(icon).fontSize(26)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
        Text(desc).fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
      Button(btn)
        .fontSize(13)
        .height(34)
        .backgroundColor(ZeroTheme.primary)
        .onClick(() => {
          action()
        })
    }
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor(ZeroTheme.cardBg)
    .borderRadius(ZeroTheme.radiusM)
    .margin({ top: 10 })
  }
}
