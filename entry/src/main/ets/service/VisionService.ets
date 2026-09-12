import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import { textRecognition } from '@kit.CoreVisionKit'
import { fileIo as fs } from '@kit.CoreFileKit'

export interface OcrOutcome {
  ok: boolean
  text: string
  msg: string
}

/**
 * 端侧视觉服务
 * 拍照/选图 → Core Vision Kit 文字识别(全离线,不上传)
 * 用于:①低碳行为拍照辅助识别 ②宿舍电表 OCR 抄表
 */
export class VisionService {
  /** 打开相册选图,返回 OCR 文本 */
  static async recognizeFromGallery(): Promise<OcrOutcome> {
    let uri: string = ''
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const opt = new photoAccessHelper.PhotoSelectOptions()
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      opt.maxSelectNumber = 1
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(opt)
      if (result.photoUris.length === 0) {
        return { ok: false, text: '', msg: '已取消' }
      }
      uri = result.photoUris[0]
    } catch (e) {
      return { ok: false, text: '', msg: '无法打开相册' }
    }

    let pixelMap: image.PixelMap | undefined
    try {
      console.info(`[ZeroIsleOCR] opening media uri via fs`)
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const source: image.ImageSource = image.createImageSource(file.fd)
      pixelMap = await source.createPixelMap()
      fs.closeSync(file)
      console.info(`[ZeroIsleOCR] pixelMap ready`)
    } catch (err) {
      console.error(`[ZeroIsleOCR] createPixelMap failed: ${JSON.stringify(err)}`)
      return { ok: false, text: '', msg: '图片读取失败' }
    }
    if (pixelMap === undefined) {
      return { ok: false, text: '', msg: '图片读取失败' }
    }

    try {
      const info: textRecognition.VisionInfo = { pixelMap: pixelMap }
      console.info(`[ZeroIsleOCR] recognizeText start`)
      const res: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(info)
      console.info(`[ZeroIsleOCR] recognize ok, len=${res.value.length}`)
      return { ok: true, text: res.value, msg: '识别成功' }
    } catch (err) {
      console.error(`[ZeroIsleOCR] recognize failed: ${JSON.stringify(err)}`)
      const be = err as BusinessError
      return { ok: false, text: '', msg: `识别失败(${be.code ?? '未知'}),已降级手动确认` }
    }
  }

  /** 从文本中抽取数字串(电表读数候选) */
  static extractNumbers(text: string): string[] {
    const out: string[] = []
    const matches: RegExpMatchArray | null = text.match(/\d{2,7}/g)
    if (matches !== null) {
      for (const m of matches) {
        if (!out.includes(m)) {
          out.push(m)
        }
      }
    }
    return out
  }
}
