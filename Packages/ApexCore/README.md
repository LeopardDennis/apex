# ApexCore

`ApexCore` 是 Apex App 与 Widget 共用的本地 Swift Package，最低支持 iOS 17、iPadOS 17 和 macOS 14。

## 模块

- `ApexDomain`：大奖赛、环节、车手、车队、赛果、积分榜和赛道领域模型，以及下一场比赛、下一环节和倒计时计算。
- `ApexResources`：解码并校验仓库中的赛历、中文名称、车队主题色和赛道 JSON。
- `ApexData`：Jolpica/OpenF1 Endpoint、统一请求头和 Repository 协议。网络客户端与缓存实现在后续阶段补充。

三个模块均不依赖 SwiftUI、SwiftData 或 WidgetKit，可以由 App、Widget 和测试共同使用。

## 验证

在安装完整且版本匹配的 Apple Swift 工具链后运行：

```sh
cd Packages/ApexCore
swift build
swift test
```

测试会读取仓库中真实的 2026 种子数据与全部赛道资源，避免测试 Fixture 与实际发布资源脱节。
