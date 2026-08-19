# Apex Atlas 数据方案

版本：0.2

状态：首发数据基线

## 1. 方案结论

首发采用“主要赛事数据 + 环节补充数据 + 本地增强数据”的组合：

- 主要赛事数据：Jolpica F1 稳定 Ergast 兼容接口
- 环节补充数据：OpenF1 Meetings、Sessions、Drivers 和 Session Result
- 本地增强数据：中文名称、车队主题色、赛道路径、弯角编号、起终点、方向和维修区
- 本地持久化：保存当前赛季和最近一次成功响应，供离线与 Widget 使用

Jolpica 提供赛历、车手、车队、正赛、冲刺赛、普通排位结果和积分榜，但稳定接口不能完整覆盖练习赛与 Sprint Qualifying 结果。OpenF1 从 2023 年起提供全部环节和 session result，首发用它补足这两个缺口，不调用实时位置或遥测数据。

两个来源都属于非官方公共服务，客户端必须缓存、控制请求频率并准备失败降级。Jolpica Alpha 结果接口暂不作为生产依赖，等结构稳定后再评估替换 OpenF1。

## 2. 数据所有权

### 2.1 Jolpica 远程维护

- 赛季和轮次
- 大奖赛日期与环节时间
- 车手和车队参赛关系
- 正赛、冲刺赛和排位赛结果
- 车手积分榜
- 车队积分榜
- 基础赛道名称、国家和经纬度（数据源提供时）

### 2.2 OpenF1 远程维护

- 比赛周末 meeting 和全部 session 起止时间
- Practice 1 / 2 / 3 结果
- Sprint Qualifying 结果
- 环节级 driver number、session key 和 meeting key

### 2.3 App 本地维护

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
- OpenF1 `meeting_key`、`session_key` 和环节车号只作为外部 ID，不替代 App 内部 ID。
- Jolpica 大奖赛与 OpenF1 meeting 首次匹配后保存映射；存在歧义时使用本地人工映射，不按名称强行猜测。

## 5. 请求策略

建议的更新节奏：

- App 启动：读取本地数据立即渲染，然后后台检查远程更新。
- 非比赛周：赛历与积分榜最长缓存 12 小时。
- 比赛周末但非实时模式：环节结束后重新请求结果；其他时间最长缓存 1 小时。
- Widget：只读取 App Group 中的已整理数据，不直接高频请求 API。
- 手动“检查更新”：忽略普通缓存时长，但仍遵守数据源限流。

Jolpica 请求使用可识别的 User-Agent，例如 `ApexAtlas/1.0 iOS`。匿名访问当前限制为每秒 4 次、每小时 500 次；收到 429 时优先遵循 `Retry-After`，否则指数退避。

OpenF1 首发只请求已结束环节的历史结果，不请求需要付费订阅的实时数据。相同 endpoint 的并发请求必须合并。

## 6. 缓存与持久化

建议分成两层：

1. 原始响应缓存：用于排查解析错误和减少重复请求。
2. 领域模型存储：供 App 页面读取，并用于生成 Widget 快照。

缓存键至少包含：

- 数据类型
- 赛季
- 轮次
- 环节
- API 版本

Widget 所需数据写入 App Group 的紧凑 JSON 快照，Widget 不直接访问网络：

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
- Jolpica 数据条款要求署名、非商业和相同方式共享，README 与 App 内需要保留数据来源说明。
- Jolpica Alpha 结果接口仍可能变化，首发优先使用稳定 Ergast 兼容接口。
- OpenF1 历史数据从 2023 年开始，足够支持当前赛季，但不能用于完整历史赛季浏览。
- OpenF1 实时数据需要付费订阅；首发没有实时需求，不接入认证或实时端点。
- OpenF1 数据采用 CC BY-NC-SA 4.0，App 内必须同时提供署名和来源链接。
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
- Jolpica 大奖赛与 OpenF1 meeting/session 的映射
- Practice 与 Sprint Qualifying 结果解析
- 首选数据源失败时的整份结果回退
- Sprint 周末与普通周末的差异
- 缓存数据在无网络环境下可读取
