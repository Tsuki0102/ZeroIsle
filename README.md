# 零屿 Zero Isle

![Platform](https://img.shields.io/badge/platform-OpenHarmony%20%2F%20HarmonyOS-1A4A3C) ![Language](https://img.shields.io/badge/language-ArkTS%20%2F%20ArkUI-2A7A65) ![Deps](https://img.shields.io/badge/第三方依赖-0-success) ![License](https://img.shields.io/badge/license-MIT-blue)

> 把每一次绿色行为,变成一座看得见生长的岛屿。
>
> A gamified carbon-footprint tracker on OpenHarmony — every green action grows your island.
>
> **版本** v1.1.0 · **包名** `com.zeroisle.isle` · **平台** HarmonyOS(ArkTS/ArkUI) · **API** 12+

零屿是一款碳普惠生活记录应用:记录日常绿色行为,按减排因子库自动折算 CO₂e 减排量与岛币,以岛屿生态从灰屿到绿屿的成长作为可视化激励,并配套看板分析、任务激励、徽章证书、家庭碳账本同步等完整闭环。

## 项目亮点

- **游戏化激励闭环** —— 五阶段岛屿生态成长(Canvas 场景动画)、10 物种收藏图鉴、8 枚徽章、每日/周任务判定式引擎、岛币商城与电子植树证书,奖励按「任务+周期键」唯一发放防重复领取
- **30 项碳排放因子库 × 7 种录入通道** —— 手动选择、一句话语义、拍照 OCR、电表抄表、扫码解析、互动仪器、对话式记账;逐条标注取值口径,来源可追溯、明细可更正
- **零第三方依赖** —— 折线/柱状/饼图/雷达图全部 Canvas 手绘,语义解析为自研规则引擎,安装包 14.64MB(基础包 3.30MB)
- **鸿蒙分布式能力真实落地** —— 基于 distributedKVStore 的超级终端多设备碳账本同步(双真机实测),跨账号家庭碳积分包合并
- **端侧 AI 录入矩阵** —— CoreVisionKit 文字识别 / ScanKit 扫码 / 语义解析 / 语音交互,LLM 混合增强架构失败自动降级本地规则,全功能离线可用
- **实测性能** —— 冷启动至首帧 1.07s,前台 PSS 约 85MB(测试方法与数据见 [`docs/性能实测记录.md`](docs/性能实测记录.md))

## 核心功能

应用主框架为五个 Tab:

| Tab | 页面 | 说明 |
|---|---|---|
| 岛 | `pages/island` | 岛屿成长主页:生态值驱动的岛屿场景动画 + 核心数据总览 |
| 记 | `pages/record` | 行为快速记录:文本语义解析、拍照估算(碳+)、因子选择 |
| 析 | `pages/stats` | 碳足迹看板:趋势图 / 分类占比 / 碳画像雷达 / 等价物换算 |
| 营 | `pages/task` | 任务营:周期任务、岛币激励、兑换商城 |
| 验 | `pages/lab` | 碳知实验室:碳小知识每日一签、低碳工具与实验 |

次级页面:我的(`mine`)、徽章墙(`badge`)、电子证书(`certificate`)、收藏图鉴(`dex`)、分享海报(`poster`)、周榜(`rank`)、记录明细(`records`)、碳+(`carbon`)。

特色能力(均在 `service/`,全离线可用):

- **岛灵 Agent** `AgentService` + `pages/agent` —— 对话式碳账本管家,**LLM 混合架构**:开启「智能增强」后优先用大模型(DeepSeek 兼容,设置页配 Key,仅上传意图短语)理解自然语言,无网络/无余额/失败时自动降级本地规则引擎,离线全功能可用;支持一句话记账(中文数字/日期补录/时间归一/否定守卫)、改账二次确认、周报/任务/商城查询、每日简报主动播报、富卡片回复(迷你趋势图/任务进度条)、语音输入 + TTS 播报、打字机流式输出与会话持久化
- **语义解析** `SemanticParser` —— 输入一句话拆解为多条结构化行为记录(因子/数量/减排量/积分)
- **碳+ 识别** `VisionService` —— 拍照/选图辅助估算减控行为
- **岛灵建议** `AdvisorService` —— 本地规则引擎,基于个人数据生成个性化低碳建议
- **超级终端同步** `DistributedSync` —— 基于分布式 KV 库,同华为账号多设备碳账本自动同步、家庭碳积分合并统计（已真机双设备实测）
- **每日提醒** `ReminderService` —— 系统级定时提醒(19:30),重启后仍生效
- **桌面卡片** `widget/` + `entryformability` —— 万能卡片展示岛屿状态
- **备份恢复** `entrybackupability` —— 系统级备份接入

## 技术栈

- **语言/UI**:ArkTS + ArkUI 声明式开发,零第三方依赖(仅系统 Kit)
- **存储**:关系型数据库(RDB)本地持久化 `data/Database.ets`;分布式 KV 库多设备同步
- **图表**:Canvas 手绘趋势图 / 饼图 / 雷达图(`components/Charts.ets`),无需图表库
- **设计系统**:统一主题 Token(`common/Theme.ets`)与动效 Token(`common/Motion.ets`),全组件深浅色适配
- **API 版本**:compatibleSdkVersion `6.1.1(24)` / targetSdkVersion `26.0.0`

## 工程结构

```
ZeroIsle/
├─ AppScope/                    # 应用级配置(app.json5、应用分层图标)
├─ entry/                       # 主模块(HAP)
│  └─ src/main/
│     ├─ ets/
│     │  ├─ entryability/       # EntryAbility 应用入口
│     │  ├─ entryformability/   # 桌面卡片 Form 能力
│     │  ├─ entrybackupability/ # 系统备份恢复能力
│     │  ├─ pages/              # 业务页面(14 个子模块 + Index Tabs 容器)
│     │  ├─ components/         # 复用组件:图表 / 岛屿场景 / 迷你场景 / 收藏品绘制
│     │  ├─ service/            # 领域服务:解析 / 识别 / 建议 / 同步 / 提醒 / 证书
│     │  ├─ data/               # RDB 持久化 + 减排因子库
│     │  ├─ model/              # 数据模型 + 游戏化数值配置
│     │  └─ common/             # 主题 Token / 动效 Token / 通用工具
│     └─ resources/             # media(应用图标等) + rawfile(图标/字体/插画)
├─ docs/                        # 说明文档(见下文索引)
├─ hvigor/ · hvigorfile.ts      # 构建工具链
└─ build-profile.json5 等       # 工程配置
```

## 构建与运行

**方式一:DevEco Studio(推荐)**

1. 使用 DevEco Studio 打开本工程根目录,等待 Sync 完成;
2. 配置签名:`File → Project Structure → Signing Configs` → 勾选 *Automatically generate signature*(需登录华为账号);
3. 设备下拉选择模拟器/真机,`Shift + F10` 运行(构建 → 签名 → 安装 → 启动)。

**方式二:命令行构建**

```powershell
$env:DEVECO_SDK_HOME = "<DevEco 安装目录>\sdk"
& "<DevEco 安装目录>\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default assembleHap --no-daemon
# 产物:entry/build/default/outputs/default/entry-default-unsigned.hap
```

安装:`hdc install -r <hap 路径>`(需已签名;命令行直接构建的产物为未签名包)。

**冷启动品牌进场**:深青启动窗 → 全屏进场图淡入停留后淡出进入主页;桌面图标与进场视觉同源。更换图标/进场图请同步修改 `AppScope/resources/base/media/` 与 `entry/src/main/resources/base/media/` 两处,避免资源不一致。

## 文档索引

| 文档 | 内容 |
|---|---|
| [`docs/零屿-参赛作品设计方案.docx`](docs/零屿-参赛作品设计方案.docx) | 完整设计方案 Word 版:设计思路、架构、实现逻辑、测试结果 |
| [`docs/零屿-参赛作品设计方案-预览.pdf`](docs/零屿-参赛作品设计方案-预览.pdf) | 设计方案 PDF 预览版 |
| [`docs/性能实测记录.md`](docs/性能实测记录.md) | 冷启动 / 内存 / 包体积实测数据与复测方法 |
| [`docs/零屿参赛优化升级路线图.md`](docs/零屿参赛优化升级路线图.md) | 完整开发与优化记录(功能、动效、验证结论) |
| [`docs/碳普惠模拟接口协议.md`](docs/碳普惠模拟接口协议.md) | 碳普惠平台模拟接口协议 |
| [`docs/参考-大赛通知全文提取.txt`](docs/参考-大赛通知全文提取.txt) | 大赛通知参考资料 |
