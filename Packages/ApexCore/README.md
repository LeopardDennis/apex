# ApexCore

`ApexCore` 是 Apex App 与 Widget 共用的本地 Swift Package，最低支持 iOS 17、iPadOS 17 和 macOS 14。

## 模块

- `ApexDomain`：大奖赛、环节、车手、车队、赛果、积分榜、赛道和 Widget 快照领域模型，以及下一场比赛、下一环节和倒计时计算。
- `ApexResources`：解码并校验仓库中的赛历、中文名称、车队主题色和赛道 JSON。
- `ApexData`：Jolpica/OpenF1 Endpoint、网络客户端、原始响应缓存、DTO/领域映射和统一 Repository。
- `ApexFeatures`：赛历、大奖赛详情和积分榜的可观察 ViewModel、页面状态、中文错误文案与 iPad 稳定选择状态。

四个模块均不依赖 SwiftUI、SwiftData 或 WidgetKit，可以由 App、Widget 和测试共同使用。`ApexFeatures` 使用系统 `Combine.ObservableObject`，之后可直接由 SwiftUI 视图观察。

## 验证

在安装完整且版本匹配的 Apple Swift 工具链后运行：

```sh
cd Packages/ApexCore
swift build
swift test
```

测试会读取仓库中真实的 2026 种子数据与全部赛道资源，避免测试 Fixture 与实际发布资源脱节。

`ApexDataTests/Fixtures` 另外保存最小化的 Jolpica 与 OpenF1 固定响应，用来验证：

- 远程车手/车队 ID 与本地中文资料、官方主题色的稳定合并。
- OpenF1 meeting、session 和历史环节结果解析。
- 同 endpoint 并发请求合并。
- 网络失败时回退过期缓存。

## ApexData 行为

- `APIClient` 对相同缓存键只发起一次并发请求，并通过 `IntervalRequestLimiter` 将匿名请求控制在每秒 4 次以内。
- `MemoryHTTPResponseCache` 适合测试和短期会话；`FileHTTPResponseCache` 保存原始 JSON，供 App 离线启动使用。
- `ApexRepository` 以 OpenF1 补全周末与练习赛/Sprint Qualifying，以 Jolpica 提供正赛、冲刺、排位和积分榜。
- `OfflineFirstApexRepository` 先读取 `ApexPersistenceStore`，刷新成功后保存新领域数据，刷新失败时保留最后一次成功内容。
- `FileApexPersistenceStore` 是当前可验证的持久化实现；完整 Xcode App Target 可换用 `XcodeSupport/ApexSwiftData` 中的 SwiftData 适配器，Feature 接口不变。
- 本地 `SeasonResourceCatalog` 始终负责中文名称、车队主题色和赛道资源，远程响应不能覆盖这些展示资料。
- `WidgetSnapshotBuilder` 生成下一场比赛、周末日程、车手领跑者和车队领跑者摘要，`FileWidgetSnapshotStore` 将版本化 JSON 原子写入 App Group。

当前 Intel Mac 的 Command Line Tools 可以完成 `swift build`，但缺少 `Testing` 模块。完整 `swift test` 需要在安装完整 Xcode 的 Mac 上运行。

## Feature 使用约定

- 首次进入页面调用 `load()`，按 `cacheFirst` 策略尽快展示本地内容。
- 用户主动检查更新或 App 发起后台刷新时调用 `refresh()`，已有内容会保留，状态切换为 `isRefreshing`。
- `FeatureState` 区分首次载入、保留内容的刷新、失败和最后更新时间；失败不会清空已经展示的内容。
- `CalendarViewModel`、`StandingsViewModel` 保存稳定选中 ID，供 iPad `NavigationSplitView` 在列表刷新和窗口尺寸变化后维持右侧详情。
