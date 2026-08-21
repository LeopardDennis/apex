# Apex SwiftData adapter

`SwiftDataApexPersistenceStore.swift` 是 Apex App Target 的 SwiftData 适配器，实现 `ApexPersistenceStore`，与 ApexCore 内已经验证的 `FileApexPersistenceStore` 和 `MemoryApexPersistenceStore` 使用相同接口。

创建完整 Xcode 工程后：

1. 将此 Swift 文件加入 `Apex` App Target，不加入 Widget Target。
2. App 启动时通过 `SwiftDataApexPersistenceStore.make()` 创建存储。
3. 用它和 `ApexRepository` 组装 `OfflineFirstApexRepository`。
4. Widget 继续只读取 App Group 中的 `apex-widget-snapshot-v1.json`，不直接访问 SwiftData 或网络。

当前 Intel Mac 的 Command Line Tools 缺少 `SwiftDataMacros` 编译插件，因此该文件不能在当前 Package 构建中启用；它需要在安装完整 Xcode 的 M2 Mac 上编译和运行内存容器测试。
