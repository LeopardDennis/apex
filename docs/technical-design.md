# Apex Atlas 技术设计

版本：0.1

状态：首发实现基线

## 1. 技术结论

Apex Atlas 首发采用原生 Apple 技术栈：

- 最低系统：iOS 17、iPadOS 17
- 界面：SwiftUI
- 自适应导航：`TabView`、`NavigationStack`、`NavigationSplitView`
- 并发：Swift Concurrency，网络与存储服务使用 `actor`
- 网络：Foundation `URLSession` + `Codable`
- 持久化：SwiftData 保存规范化领域数据
- Widget：WidgetKit + App Group JSON 快照
- 后台刷新：前台启动刷新为主，`BGAppRefreshTask` 仅作机会性补充
- 测试：Swift Testing / XCTest、固定 API Fixture、Snapshot 验收

首发不引入第三方网络层、数据库库、依赖注入框架或图片下载框架。当前数据量和功能范围不需要这些依赖。

## 2. 数据源决策

### 2.1 Jolpica F1：主要赛事数据

基础地址：`https://api.jolpi.ca/ergast/f1/`

负责：

- 赛季赛历与基础比赛周末时间
- 正赛结果
- 排位赛结果
- 冲刺赛结果
- 车手积分榜
- 车队积分榜
- 车手与车队基础资料

首发使用的稳定接口：

| 用途 | 路径 |
| --- | --- |
| 赛季赛历 | `{season}.json?limit=100` |
| 下一场比赛 | `current/next.json` |
| 正赛结果 | `{season}/{round}/results.json?limit=100` |
| 排位结果 | `{season}/{round}/qualifying.json?limit=100` |
| 冲刺结果 | `{season}/{round}/sprint.json?limit=100` |
| 车手积分榜 | `{season}/driverstandings.json?limit=100` |
| 车队积分榜 | `{season}/constructorstandings.json?limit=100` |
| 车手列表 | `{season}/drivers.json?limit=100` |
| 车队列表 | `{season}/constructors.json?limit=100` |

客户端必须发送类似 `ApexAtlas/1.0 iOS` 的自定义 User-Agent。匿名访问限流当前为每秒 4 次、每小时 500 次，因此所有请求都必须经过本地缓存、请求合并和退避处理。

### 2.2 OpenF1：环节补充数据

基础地址：`https://api.openf1.org/v1/`

负责：

- 补全比赛周末全部环节及准确起止时间
- Practice 1 / 2 / 3 结果
- Sprint Qualifying 结果
- 在 Jolpica 数据缺失时补充普通排位或其他已结束环节结果

首发只调用：

| 用途 | 路径 |
| --- | --- |
| 比赛周末 | `meetings?year={season}` |
| 周末环节 | `sessions?meeting_key={meetingKey}` |
| 环节车手 | `drivers?session_key={sessionKey}` |
| 环节结果 | `session_result?session_key={sessionKey}` |

不接入实时位置、遥测、圈速流、车手间隔、天气流或车队无线电。OpenF1 的免费历史数据从 2023 年开始；首发只保证当前赛季，因此满足需求。

### 2.3 不直接使用 Jolpica Alpha 结果接口

Jolpica 在 2026 年提供了可覆盖练习赛与 Sprint Qualifying 的 Alpha 结果接口，但仍存在 opaque round ID、额外分页请求和结构变化风险。首发不把它作为生产依赖。等接口稳定后再通过数据源适配器替换 OpenF1，不影响领域模型和 UI。

### 2.4 本地增强数据

以下数据随 App 版本发布，不依赖远程 API：

- 中文大奖赛、赛道、车手和车队名称
- 每赛季车队官方主题色
- 赛道归一化路径
- 弯角编号及锚点
- 起终点、行驶方向和维修区标记
- 外部 ID 别名及人工修正规则

首发不分发未经许可的官方 Logo、车手照片、赛车照片或 F1 官方字体。资料页使用主题色、文字、号码和自制图形表达身份。

## 3. 外部数据合并

### 3.1 内部稳定 ID

- 大奖赛：`{season}-{round}`，例如 `2026-05`
- 环节：`{season}-{round}-{sessionKind}`
- 车手：优先使用 Jolpica `driverId`
- 车队：使用 Jolpica `constructorId`，视觉数据再加 `season`
- 赛道：使用 Jolpica `circuitId`，通过本地别名修正改名情况

外部 ID 单独保存：

```text
ExternalIDLink
├── entityType
├── internalID
├── provider        jolpica | openf1
├── externalID      meeting_key | session_key | driver number
├── season
└── updatedAt
```

### 3.2 大奖赛匹配

OpenF1 没有与 Jolpica round 完全相同的公共主键，因此按以下顺序匹配：

1. 同一赛季。
2. 国家代码或本地赛道别名一致。
3. OpenF1 环节时间落在 Jolpica 比赛周末日期前后一天范围内。
4. 匹配后保存 `meeting_key`，后续不再重复推断。
5. 多个候选或没有候选时使用随 App 发布的人工映射，不自动猜测。

### 3.3 车手匹配

环节内以 `session_key + driver_number` 读取 OpenF1 车手，再按三字母代码、车号和规范化姓名映射 Jolpica `driverId`。替补车手或车号冲突必须进入人工别名表，不能只用车号作为永久主键。

### 3.4 结果优先级

| 环节 | 首选 | 回退 |
| --- | --- | --- |
| Race | Jolpica | OpenF1 |
| Sprint | Jolpica | OpenF1 |
| Qualifying | Jolpica | OpenF1 |
| Sprint Qualifying | OpenF1 | 缓存 / 待公布 |
| Practice 1 / 2 / 3 | OpenF1 | 缓存 / 待公布 |

同一环节出现冲突时不拼接两份排名。首选来源成功解析后整份使用；只有首选来源不可用或缺失该环节时才启用回退来源。

## 4. 工程结构

建议创建两个 Target 和一个本地 Swift Package：

```text
ApexAtlas/
├── ApexAtlas.xcodeproj
├── App/
│   ├── ApexAtlasApp.swift
│   ├── AppEnvironment.swift
│   └── Features/
│       ├── Home/
│       ├── Calendar/
│       ├── GrandPrix/
│       ├── Results/
│       ├── Standings/
│       ├── Profiles/
│       └── Settings/
├── Widgets/
│   ├── ApexAtlasWidgets.swift
│   ├── ScheduleWidget/
│   ├── CountdownWidget/
│   ├── DriverLeaderWidget/
│   └── TeamLeaderWidget/
├── Packages/ApexAtlasCore/
│   ├── Sources/ApexAtlasDomain/
│   ├── Sources/ApexAtlasData/
│   ├── Sources/ApexAtlasResources/
│   └── Tests/
└── Resources/
    ├── Localization/
    ├── TeamThemes/
    ├── TrackAssets/
    └── Fixtures/
```

### 4.1 Target

- `ApexAtlas`：iPhone 与 iPad 主 App。
- `ApexAtlasWidgets`：Widget Extension，不包含 Live Activity 和可配置 App Intent。

### 4.2 ApexAtlasCore

- `ApexAtlasDomain`：纯 Swift 领域模型、状态枚举和业务规则。
- `ApexAtlasData`：DTO、API 客户端、Repository、SwiftData 记录和映射器。
- `ApexAtlasResources`：中文映射、主题色和赛道静态资源解析。

Feature View 不直接访问 URLSession 或 SwiftData，只依赖 Repository 协议。

## 5. 分层与数据流

```text
SwiftUI Feature
    ↓
Feature Store / View Model (@Observable, @MainActor)
    ↓
Repository Protocol
    ├── Remote Provider (Jolpica / OpenF1)
    ├── SwiftData Store
    └── Bundled Resource Store
```

刷新流程：

1. 从 SwiftData 读取缓存并立即展示。
2. Repository 判断资源是否过期。
3. 过期时合并相同 endpoint 的并发请求。
4. 远程 DTO 解码为领域模型。
5. 应用中文映射、主题色和赛道资源。
6. 在单次事务中写入 SwiftData。
7. 生成 Widget JSON 快照并请求 WidgetKit 刷新时间线。
8. 失败时继续显示旧数据，同时保留最后更新时间和错误原因。

## 6. 核心领域模型

领域模型使用不可变 `struct`，不直接暴露 SwiftData `@Model`：

```text
Season
GrandPrix
RaceSession
Circuit
TrackAsset
Driver
Team
SessionResult
StandingTable
StandingEntry
TeamTheme
ExternalIDLink
WidgetSnapshot
```

关键枚举：

```text
SessionKind
├── practice1
├── practice2
├── practice3
├── sprintQualifying
├── sprint
├── qualifying
└── race

SessionState
├── scheduled
├── completed
├── cancelled
├── resultPending
└── resultAvailable
```

网络 DTO、持久化记录和 UI 领域模型相互独立，避免 API 字段变化直接影响页面。

## 7. 持久化与离线

### 7.1 SwiftData

主 App 的 SwiftData 保存：

- 赛季、大奖赛和环节
- 车手、车队与积分榜
- 已结束环节结果
- 外部 ID 映射
- 原始响应元数据与最后更新时间

不保存已经格式化的日期文字；只保存绝对 `Date` 和必要的原始时区信息。

### 7.2 原始响应缓存

原始 JSON 单独存入 `Application Support/RawCache`，按 provider、endpoint、season、round 和 schemaVersion 生成键。它用于离线恢复、解析问题排查和 Fixture 回归，不直接驱动 UI。

### 7.3 Widget 快照

Widget 不直接打开完整 SwiftData 数据库，也不主动请求网络。主 App 把紧凑 `WidgetSnapshot.json` 原子写入 App Group：

```text
WidgetSnapshot
├── generatedAt
├── nextGrandPrix
├── sessions
├── driverLeader
├── teamLeader
└── sourceUpdatedAt
```

建议 Bundle ID：`com.leoparddennis.apexatlas`

建议 App Group：`group.com.leoparddennis.apexatlas`

正式创建开发者签名配置时再确认最终标识符。

## 8. 更新策略

| 数据 | 普通日期 | 比赛周末 | 已结束赛季 |
| --- | --- | --- | --- |
| 赛历 | 12 小时 | 6 小时 | 7 天 |
| 积分榜 | 12 小时 | 1 小时 | 7 天 |
| 环节结果 | 已有结果不重复刷新 | 环节结束 10 分钟后检查 | 永久缓存 |
| 本地增强数据 | 随 App 发布 | 随 App 发布 | 随 App 发布 |

规则：

- 启动时始终先展示缓存，再异步刷新。
- 请求返回 429 时遵循 `Retry-After`；没有该字段则指数退避。
- 同一 endpoint 在进程内只允许一个进行中的请求。
- 手动检查更新绕过 TTL，但不绕过限流。
- `BGAppRefreshTask` 只作机会性刷新，UI 不承诺准确的后台更新时间。

## 9. iPhone 与 iPad 导航

### 9.1 根导航

根页面保持三个 Tab：

- 首页
- 赛历
- 积分榜

设置通过首页 toolbar 进入，不增加第四个 Tab。

### 9.2 iPhone

- 每个 Tab 使用 `NavigationStack` 或折叠后的 `NavigationSplitView`。
- 列表选择后进入详情页。
- 返回手势和系统返回按钮保持默认行为。

### 9.3 iPad

- 赛历和积分榜使用两栏 `NavigationSplitView`。
- 左侧选择绑定稳定 ID，右侧详情随选择更新。
- 使用可调的理想栏宽，不写死设备型号或横竖屏判断。
- iPad Split View、Slide Over 或 compact size class 下自动折叠为单栏。
- 选择状态在窗口尺寸变化后保留。

## 10. Widget 技术方案

首发创建四个静态 Widget，不提供“我的车手”或收藏配置：

1. `NextRaceWidget`：下一场比赛与倒计时。
2. `WeekendScheduleWidget`：完整比赛周末日程。
3. `DriverLeaderWidget`：当前车手积分榜领跑者摘要。
4. `TeamLeaderWidget`：当前车队积分榜领跑者摘要。

支持尺寸：

- iPhone：Small、Medium、Large，按内容裁剪。
- iPad：Small、Medium、Large、Extra Large。

Timeline 原则：

- 读取 App Group 快照。
- 在下一环节开始、结束和当地日期切换处安排 timeline entry。
- 数据过期时继续显示缓存，并显示简短更新时间。
- 无缓存时使用清晰的占位内容，不让 Widget 自行高频联网。

不创建 Live Activity、通知能力或日历权限。

## 11. 网络与错误模型

统一错误类型：

```text
DataError
├── offline
├── timeout
├── rateLimited(retryAfter)
├── server(statusCode)
├── invalidPayload
├── mappingFailed(entity)
├── cacheUnavailable
└── noData
```

UI 映射：

- 有缓存：继续展示内容，在页面内显示最后更新时间。
- 无缓存：显示错误说明和重新加载按钮。
- 结果未产生：显示“结果待公布”，不当作错误。
- 时间未发布：显示“时间待定”，不猜测。
- 映射缺失：回退英文名称或中性色，并记录日志。

日志统一使用 `OSLog`，禁止记录完整响应中的无关信息。

## 12. 测试策略

### 12.1 单元测试

- Jolpica 与 OpenF1 DTO 解码。
- 两个数据源的大奖赛与车手匹配。
- Sprint 周末和普通周末环节排序。
- 设备时区与夏令时转换。
- 结果优先级和回退逻辑。
- 缓存 TTL、429 退避和并发请求合并。
- Widget 快照生成。

### 12.2 Repository 测试

- 首次在线加载。
- 有缓存的后台刷新。
- 完全离线启动。
- 一方数据源失败。
- 两方数据冲突。
- API 新增未知字段或缺失可选字段。

### 12.3 UI 验收矩阵

- 窄屏 iPhone。
- 常规尺寸 iPhone。
- iPad mini 竖屏与横屏。
- 11 英寸 iPad 横屏。
- iPad 约半屏与 Slide Over。
- 所有支持的 Widget family。
- 大号辅助字体下的主要列表与详情。

## 13. 权限与隐私

首发只需要：

- 网络访问。
- App Group，用于主 App 与 Widget 共享快照。

明确不申请：

- 通知权限。
- 日历权限。
- 定位、照片、联系人或账户权限。
- CloudKit 或用户追踪权限。

## 14. 数据署名与合规

- Jolpica API 数据受 CC BY-NC-SA 4.0 条款约束，App 保持非商业并提供署名和来源链接。
- OpenF1 仓库同样采用 CC BY-NC-SA 4.0；App 内“数据与版权”页面同时注明 OpenF1。
- 两个服务均为非官方服务，不能把数据准确性或可用性描述为官方保证。
- API 数据许可不自动授予 Formula 1、车队、车手照片、Logo、商标或官方字体的使用权。

## 15. 实施顺序

1. 创建 Xcode 工程、两个 Target 和 App Group。
2. 建立 ApexAtlasCore 与领域模型。
3. 完成 Jolpica 客户端、Fixture 和 Decoder 测试。
4. 完成 OpenF1 补充客户端与映射测试。
5. 建立 SwiftData 与离线 Repository。
6. 实现赛历列表和大奖赛详情作为第一条垂直切片。
7. 接入结果页、积分榜、资料页和首页。
8. 生成 Widget 快照并完成四个 Widget。
9. 做 iPhone/iPad/分屏和离线验收。

## 16. 参考资料

- [Jolpica F1 文档](https://github.com/jolpica/jolpica-f1/blob/main/docs/README.md)
- [Jolpica F1 限流](https://github.com/jolpica/jolpica-f1/blob/main/docs/rate_limits.md)
- [Jolpica F1 使用条款](https://github.com/jolpica/jolpica-f1/blob/main/TERMS.md)
- [OpenF1 API 文档](https://openf1.org/docs/)
- [OpenF1 许可](https://github.com/br-g/openf1/blob/main/LICENSE)
- [Apple NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Apple SwiftData ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Apple WidgetKit 策略](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy)
- [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
