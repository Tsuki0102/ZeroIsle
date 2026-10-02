import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'
import { textRecognition } from '@kit.CoreVisionKit'
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { camera, cameraPicker } from '@kit.CameraKit'

export interface OcrOutcome {
  ok: boolean
  text: string
  msg: string
}

export interface QrOutcome {
  ok: boolean
  payload: string
  msg: string
}

/**
 * 端侧视觉服务(AI 录入矩阵)
 * ①拍照/相册 → Core Vision Kit 文字识别(OCR) ②相册图 → ScanKit 二维码检测(共享单车骑行码)
 * 全程端侧推理,数据不出设备
 */
export class VisionService {
  /** 拍照(后置)→ OCR */
  static async recognizeFromCamera(ctx: common.UIAbilityContext): Promise<OcrOutcome> {
    let uri: string = ''
    try {
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      }
      const result: cameraPicker.PickerResult =
        await cameraPicker.pick(ctx, [cameraPicker.PickerMediaType.PHOTO], profile)
      if (result.resultCode !== 0 || result.resultUri === '') {
        return { ok: false, text: '', msg: '已取消' }
      }
      uri = result.resultUri
    } catch (e) {
      return { ok: false, text: '', msg: '无法打开相机,可改用相册识别' }
    }
    return VisionService.recognizeUri(uri)
  }

  /** 相册选图 → OCR */
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
    return VisionService.recognizeUri(uri)
  }

  /** 对指定图片 URI 做端侧 OCR(大图先降采样:长边 ≤1280,足够识别且降低内存峰值) */
  private static async recognizeUri(uri: string): Promise<OcrOutcome> {
    let pixelMap: image.PixelMap | undefined
    let file: fs.File | null = null
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const source: image.ImageSource = image.createImageSource(file.fd)
      const info: image.ImageInfo = await source.getImageInfo()
      const maxEdge: number = Math.max(info.size.width, info.size.height)
      const opts: image.DecodingOptions = maxEdge > 1280
        ? {
          desiredSize: {
            width: Math.round(info.size.width * 1280 / maxEdge),
            height: Math.round(info.size.height * 1280 / maxEdge)
          }
        }
        : {}
      pixelMap = await source.createPixelMap(opts)
    } catch (err) {
      console.error(`[ZeroIsleOCR] createPixelMap failed: ${JSON.stringify(err)}`)
      return { ok: false, text: '', msg: '图片读取失败' }
    } finally {
      // 无论解码成败都关闭 fd,避免异常路径泄漏文件句柄
      if (file !== null) {
        try {
          fs.closeSync(file)
        } catch (e) {
          // fd 已失效时忽略
        }
      }
    }
    if (pixelMap === undefined) {
      return { ok: false, text: '', msg: '图片读取失败' }
    }
    try {
      const info: textRecognition.VisionInfo = { pixelMap: pixelMap }
      const res: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(info)
      return { ok: true, text: res.value, msg: '识别成功' }
    } catch (err) {
      console.error(`[ZeroIsleOCR] recognize failed: ${JSON.stringify(err)}`)
      const be = err as BusinessError
      return { ok: false, text: '', msg: `识别失败(${be.code ?? '未知'}),已降级手动确认` }
    }
  }

  /** 相册选图 → ScanKit 静态二维码检测(共享单车骑行码场景) */
  static async decodeQrFromGallery(): Promise<QrOutcome> {
    let uri: string = ''
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const opt = new photoAccessHelper.PhotoSelectOptions()
      opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      opt.maxSelectNumber = 1
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(opt)
      if (result.photoUris.length === 0) {
        return { ok: false, payload: '', msg: '已取消' }
      }
      uri = result.photoUris[0]
    } catch (e) {
      return { ok: false, payload: '', msg: '无法打开相册' }
    }
    try {
      const input: detectBarcode.InputImage = { uri: uri }
      const options: scanBarcode.ScanOptions = { scanTypes: [scanCore.ScanType.QR_CODE] }
      const results: scanBarcode.ScanResult[] = await detectBarcode.decode(input, options)
      if (results.length === 0) {
        return { ok: false, payload: '', msg: '图中未检出二维码' }
      }
      return { ok: true, payload: results[0].originalValue, msg: '识别成功' }
    } catch (e) {
      console.error(`[ZeroIsleScan] decode failed: ${JSON.stringify(e)}`)
      return { ok: false, payload: '', msg: '二维码识别失败,请换一张图' }
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
