import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'
import { Database } from '../data/Database'

/** LLM 解析出的结构化意图 */
export class AgentIntent {
  action: string = 'help'
  /** 规范化后的记录短语(record 用) */
  normalized: string = ''
  /** 补录天数(0=今天) */
  daysAgo: number = 0
}

interface LlmChatResponse {
  choices: LlmChoice[]
}

interface LlmChoice {
  message: LlmMessage
}

interface LlmMessage {
  content: string
}

interface LlmIntentRaw {
  action: string
  normalized?: string
  daysAgo?: number
}

interface LlmMsg {
  role: string
  content: string
}

const ACTIONS: string[] = [
  'record', 'query_week', 'query_month', 'query_today', 'query_total', 'query_coins',
  'query_cats', 'query_tasks', 'query_shop', 'query_report', 'briefing', 'advice', 'delete', 'help'
]

const SYSTEM_PROMPT: string =
  '你是「零屿」低碳记录应用的意图解析器。把用户输入分类为下面的动作之一,只输出一个 JSON 对象,不要输出任何其他文字:\n' +
  '{"action":"record","normalized":"<把输入规范化成 行为+数量+单位 的简短中文短语,如 骑车3公里 / 光盘2次 / 节水1次;保留原文中的数量>","daysAgo":0}\n' +
  '{"action":"query_week"} {"action":"query_month"} {"action":"query_today"} {"action":"query_total"} {"action":"query_coins"} {"action":"query_cats"} {"action":"query_tasks"} {"action":"query_shop"} {"action":"query_report"} {"action":"briefing"} {"action":"advice"} {"action":"delete"} {"action":"help"}\n' +
  '规则:删除/撤销/不算了→delete;商城/兑换→query_shop;周报/报告/总结→query_report;简报/播报→briefing;建议/推荐→advice;任务/进度→query_tasks;岛币/积分/余额→query_coins;分类/占比→query_cats;本周/这周→query_week;本月→query_month;今天→query_today;累计/岛屿阶段→query_total;提到骑车/步行/公交/地铁/光盘/节电/节水/回收/自带杯/植树等具体行为→record(提到昨天/前天/N天前时 daysAgo 相应设为 1/2/3/N);无法判断→help。'

/**
 * LLM 智能增强(DeepSeek 兼容接口):
 * 把用户输入分类为结构化意图,交给 AgentService 的同一套工具执行。
 * 任何失败(无 Key / 未开启 / 无网络 / 无余额 / 超时)都返回 null,
 * 由调用方无缝降级到本地规则引擎 —— 演示与离线场景零风险。
 */
export class LlmService {
  /** 是否已开启且配置了 Key */
  static async enabled(ctx: common.UIAbilityContext): Promise<boolean> {
    const on: string = await Database.kvGet(ctx, 'agent_llm_on', '')
    if (on !== '1') {
      return false
    }
    const key: string = await Database.kvGet(ctx, 'agent_llm_key', '')
    return key !== ''
  }

  /** 输入 → 结构化意图;失败返回 null */
  static async classify(ctx: common.UIAbilityContext, input: string): Promise<AgentIntent | null> {
    if (!(await LlmService.enabled(ctx))) {
      return null
    }
    const key: string = await Database.kvGet(ctx, 'agent_llm_key', '')
    const httpRequest = http.createHttp()
    try {
      const resp = await httpRequest.request('https://api.deepseek.com/chat/completions', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${key}`
        },
        extraData: JSON.stringify({
          model: 'deepseek-chat',
          messages: [
            { role: 'system', content: SYSTEM_PROMPT } as LlmMsg,
            { role: 'user', content: input } as LlmMsg
          ],
          temperature: 0.1,
          max_tokens: 200,
          stream: false
        }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000
      })
      const raw: string = resp.result as string
      const root = JSON.parse(raw) as LlmChatResponse
      const content: string = root.choices[0].message.content
      const cleaned: string = content.replace(/```json|```/g, '').trim()
      const intentRaw = JSON.parse(cleaned) as LlmIntentRaw
      if (ACTIONS.indexOf(intentRaw.action) < 0) {
        return null
      }
      const intent = new AgentIntent()
      intent.action = intentRaw.action
      intent.normalized = intentRaw.normalized !== undefined ? intentRaw.normalized : ''
      intent.daysAgo = intentRaw.daysAgo !== undefined && intentRaw.daysAgo > 0 ? intentRaw.daysAgo : 0
      return intent
    } catch (e) {
      // 无余额 / 无网络 / 超时 / 解析失败:统一降级到本地规则引擎
      console.info('ZeroIsle LLM classify failed, fallback to local rules')
      return null
    } finally {
      httpRequest.destroy()
    }
  }
}
