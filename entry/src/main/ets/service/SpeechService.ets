import { common } from '@kit.AbilityKit'
import { abilityAccessCtrl } from '@kit.AbilityKit'
import { speechRecognizer, textToSpeech } from '@kit.CoreSpeechKit'

/** 语音回调集合 */
export interface VoiceCallbacks {
  /** 中间识别结果(实时刷新输入框) */
  onPartial?: (text: string) => void
  /** 一次识别完成(最终文本) */
  onFinal?: (text: string) => void
  /** 失败原因(权限/设备不支持等) */
  onError?: (msg: string) => void
}

/**
 * 语音服务:端侧语音识别(语音输入)+ TTS 播报。
 * 全部带可用性降级:权限被拒/设备不支持时以文案提示,不影响主流程。
 */
export class SpeechService {
  private static recEngine: speechRecognizer.SpeechRecognitionEngine | null = null
  private static ttsEngine: textToSpeech.TextToSpeechEngine | null = null
  private static ttsSeq: number = 0
  private static readonly SESSION_ID: string = 'zeroisle_voice_session'

  /** 申请麦克风权限(用户拒绝返回 false) */
  private static async ensureMic(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const res = await atManager.requestPermissionsFromUser(ctx, ['ohos.permission.MICROPHONE'])
      return res.authResults.length > 0 && res.authResults[0] === 0
    } catch (e) {
      return false
    }
  }

  /** 一次性语音识别:说完一句话 → onFinal 文本(系统语音引擎;设备不支持或引擎异常时经 onError 降级,不影响主流程) */
  static async listenOnce(ctx: common.UIAbilityContext, cb: VoiceCallbacks): Promise<void> {
    if (!(await SpeechService.ensureMic(ctx))) {
      cb.onError?.('需要麦克风权限,请在系统设置中允许')
      return
    }
    try {
      if (SpeechService.recEngine === null) {
        SpeechService.recEngine = await speechRecognizer.createEngine({
          language: 'zh-CN',
          online: 1
        })
      }
      let last: string = ''
      SpeechService.recEngine.setListener({
        onStart: (sessionId: string, eventMessage: string) => {
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          last = result.result
          cb.onPartial?.(last)
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          cb.onFinal?.(last)
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          cb.onError?.(errorMessage !== '' ? errorMessage : '语音识别失败')
        }
      })
      SpeechService.recEngine.startListening({
        sessionId: SpeechService.SESSION_ID,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      })
    } catch (e) {
      cb.onError?.('当前设备不支持语音识别')
    }
  }

  /** 结束本次识别并取最终结果(用户再按一次麦克风) */
  static finishListening(): void {
    try {
      SpeechService.recEngine?.finish(SpeechService.SESSION_ID)
    } catch (e) {
      // 引擎未就绪时忽略
    }
  }

  /** 取消本次识别(不取结果) */
  static cancelListening(): void {
    try {
      SpeechService.recEngine?.cancel(SpeechService.SESSION_ID)
    } catch (e) {
      // 引擎未就绪时忽略
    }
  }

  /** TTS 播报一段文本(设备不支持时静默降级) */
  static async speak(ctx: common.UIAbilityContext, text: string): Promise<void> {
    try {
      if (SpeechService.ttsEngine === null) {
        SpeechService.ttsEngine = await textToSpeech.createEngine({
          language: 'zh-CN',
          person: 0,
          online: 1
        })
        SpeechService.ttsEngine.setListener({
          onStart: (requestId: string, response: textToSpeech.StartResponse) => {
          },
          onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
          },
          onStop: (requestId: string, response: textToSpeech.StopResponse) => {
          },
          onError: (requestId: string, errorCode: number, errorMessage: string) => {
          }
        })
      }
      SpeechService.ttsSeq++
      SpeechService.ttsEngine.speak(text, {
        requestId: `zeroisle_tts_${SpeechService.ttsSeq}`,
        extraParams: {
          'style': 'interaction-broadcast',
          'locate': 'CN',
          'name': 'EngineName'
        }
      })
    } catch (e) {
      // 无 TTS 引擎时静默降级
    }
  }
}
