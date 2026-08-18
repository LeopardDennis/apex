# Apex Atlas 数据方案

版本：0.1

状态：首发架构建议

## 1. 方案结论

首发采用“远程赛事数据 + 本地增强数据”的组合：

- 远程赛事数据：Jolpica F1 API
- 本地增强数据：中文名称、车队主题色、赛道路径、弯角编号、起终点、方向和维修区
- 本地持久化：保存当前赛季和最近一次成功响应，供离线与 Widget 使用
- OpenF1：首发不接入，未来需要实时或更细粒度 session 数据时再评估

选择 Jolpica 的原因：它提供赛历、车手、车队、比赛结果、排位结果以及车手/车队积分榜，覆盖首发信息范围；项目是 Ergast API 的后继并保持兼容接口。由于它是志愿者维护的非商业公共服务，客户端必须缓存、控制请求频率并准备失败降级。

## 2. 数据所有权

### 2.1 远程维护

- 赛季和轮次
- 大奖赛日期与环节时间
- 车手和车队参赛关系
- 正赛、冲刺赛和排位赛结果
- 车手积分榜
- 车队积分榜
- 基础赛道名称、国家和经纬度（数据源提供时）

### 2.2 App 本地维护

- 车手中文名称
- 车队中文名称
- 大奖赛中文名称
- 赛道中文名称
- 每赛季车队官方主题色
- 赛道预览路径
- 弯角编号和标注位置
- 起终点、方向和维修区标记
- 展示排序、别名和修正规则

本地增强数据随 App 版本发布，可在后续版本中增加远程配置，但首发不需要自建后台。

## 3. 核心实体

### Season

- `year`
- `rounds`
- `lastUpdatedAt`

### GrandPrix

- `season`
- `round`
- `raceId`
- `name`
- `localizedName`
- `circuitId`
- `weekendStart`
- `weekendEnd`
- `sessions`
- `status`

### Session

- `sessionId`
- `type`
- `startAt`
- `endAt`
- `status`
- `resultAvailability`

### Circuit

- `circuitId`
- `name`
- `localizedName`
- `countryCode`
- `lengthKm`
- `raceLaps`
- `cornerCount`
- `direction`
- `altitudeM`
- `trackAssetId`

### TrackAsset

- `trackAssetId`
- `normalizedPath`
- `corners`
- `startFinishMarker`
- `directionMarker`
- `pitLanePath`
- `previewInsets`

赛道路径使用归一化坐标保存，以便 App 和 Widget 在不同尺寸下重绘；弯角编号的锚点与赛道路径分离，避免缩放后文字压在线条上。

### Driver

- `driverId`
- `code`
- `number`
- `givenName`
- `familyName`
- `localizedName`
- `nationality`
- `teamId`

### Team

- `teamId`
- `name`
- `localizedName`
- `nationality`
- `season`
- `primaryColor`
- `secondaryColor`

### SessionResult

- `sessionId`
- `position`
- `driverId`
- `teamId`
- `laps`
- `timeOrGap`
- `points`
- `status`
- `fastestLap`

### StandingEntry

- `season`
- `round`
- `category`
- `position`
- `driverId` 或 `teamId`
- `points`
- `wins`

## 4. ID 与映射规则

- 远程数据源 ID 作为外部 ID 保存，不直接作为 UI 文案。
- App 内部使用稳定、不可本地化的 ID。
- 中文名称通过内部 ID 映射。
- 车队更名或同一车队跨赛季改变视觉时，主题色按 `teamId + season` 解析。
- 车手换队后，历史比赛使用当时所属车队颜色；当前积分榜和资料页使用当前赛季所属车队颜色。

## 5. 请求策略

建议的更新节奏：

- App 启动：读取本地数据立即渲染，然后后台检查远程更新。
- 非比赛周：赛历与积分榜最长缓存 12 小时。
- 比赛周末但非实时模式：环节结束后重新请求结果；其他时间最长缓存 1 小时。
- Widget：只读取 App Group 中的已整理数据，不直接高频请求 API。
- 手动“检查更新”：忽略普通缓存时长，但仍遵守数据源限流。

所有请求需要使用可识别的 User-Agent，例如 `ApexAtlas/1.0 iOS`，并遵守 Jolpica 的限流和使用条款。

## 6. 缓存与持久化

建议分成两层：

1. 原始响应缓存：用于排查解析错误和减少重复请求。
2. 领域模型存储：供 App 页面和 Widget 直接读取。

缓存键至少包含：

- 数据类型
- 赛季
- 轮次
- 环节
- API 版本

Widget 所需数据写入 App Group 的紧凑快照：

- 下一场比赛
- 比赛周末环节
- 当前车手积分榜摘要
- 当前车队积分榜摘要
- 最后更新时间

## 7. 时间处理

- 网络层保存带时区的原始时间。
- 领域模型统一转换为绝对时间点。
- UI 和 Widget 最终按设备当前时区格式化。
- 跨时区或夏令时切换后重新生成展示文本。
- 不把已经格式化的本地时间字符串作为持久化主数据。

## 8. 数据缺失处理

- 未公布环节时间：显示“时间待定”，不猜测时间。
- 未产生结果：显示“结果待公布”，不显示空排名。
- 车手或车队中文名缺失：回退英文名并记录映射缺口。
- 主题色缺失：回退通用中性色，不根据 Logo 自动猜色。
- 赛道标注缺失：先显示无标号的赛道预览，并明确标记素材待补。
- API 请求失败：使用缓存并显示最后更新时间。

## 9. 数据源边界与风险

- Jolpica 适合个人非商业使用，但属于志愿者维护服务，不能假设永久在线或永不变更。
- 其数据许可包含署名和非商业要求，README 与 App 内需要保留数据来源说明。
- 新版 alpha 结果接口仍可能变化，首发优先使用稳定的 Ergast 兼容接口。
- OpenF1 提供更细的 session、车手和实时数据，但首发不需要，避免增加数据合并复杂度。
- 车手照片、车队 Logo 和赛车图片存在单独的版权问题，不能因为 API 返回图片 URL 就默认可分发。

## 10. 首发数据验证

每个赛季发布前至少验证：

- 全部大奖赛轮次和日期
- 所有比赛周末环节类型
- 设备时区转换
- 当前正式车手及所属车队
- 中文名称映射完整性
- 车队主题色
- 每条赛道弯角编号数量和位置
- 结果与积分榜解析
- Sprint 周末与普通周末的差异
- 缓存数据在无网络环境下可读取
