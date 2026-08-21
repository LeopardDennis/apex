import ApexData
import Foundation

public enum FeatureFailureCode: String, Equatable, Sendable {
  case offline
  case timeout
  case rateLimited
  case server
  case invalidData
  case cacheUnavailable
  case unknown
}

public struct FeatureFailure: Error, Equatable, Sendable {
  public let code: FeatureFailureCode
  public let title: String
  public let message: String
  public let retryAfter: TimeInterval?

  public init(
    code: FeatureFailureCode,
    title: String,
    message: String,
    retryAfter: TimeInterval? = nil
  ) {
    self.code = code
    self.title = title
    self.message = message
    self.retryAfter = retryAfter
  }

  public init(error: any Error) {
    guard let dataError = error as? DataClientError else {
      self.init(
        code: .unknown,
        title: "暂时无法载入",
        message: "发生了未知错误，请稍后重试。"
      )
      return
    }

    switch dataError {
    case .offline:
      self.init(
        code: .offline,
        title: "当前处于离线状态",
        message: "连接网络后即可检查最新数据。"
      )
    case .timeout:
      self.init(
        code: .timeout,
        title: "连接超时",
        message: "数据源响应时间过长，请稍后重试。"
      )
    case .rateLimited(let retryAfter):
      self.init(
        code: .rateLimited,
        title: "请求过于频繁",
        message: "数据源暂时限制了请求，请稍后再试。",
        retryAfter: retryAfter
      )
    case .httpStatus:
      self.init(
        code: .server,
        title: "数据服务暂时不可用",
        message: "服务器未能返回有效数据，请稍后重试。"
      )
    case .cacheIO:
      self.init(
        code: .cacheUnavailable,
        title: "本地数据不可用",
        message: "无法读取已保存的数据，请重新载入。"
      )
    case .invalidResponse, .emptyPayload, .decoding, .mapping:
      self.init(
        code: .invalidData,
        title: "数据暂时无法解析",
        message: "数据格式发生变化，请稍后重试。"
      )
    case .network:
      self.init(
        code: .server,
        title: "无法连接数据服务",
        message: "请检查网络连接后重试。"
      )
    }
  }
}

public struct FeatureState<Content: Equatable & Sendable>: Equatable, Sendable {
  public internal(set) var content: Content?
  public internal(set) var isLoading: Bool
  public internal(set) var isRefreshing: Bool
  public internal(set) var failure: FeatureFailure?
  public internal(set) var lastUpdatedAt: Date?

  public init(
    content: Content? = nil,
    isLoading: Bool = false,
    isRefreshing: Bool = false,
    failure: FeatureFailure? = nil,
    lastUpdatedAt: Date? = nil
  ) {
    self.content = content
    self.isLoading = isLoading
    self.isRefreshing = isRefreshing
    self.failure = failure
    self.lastUpdatedAt = lastUpdatedAt
  }

  public var isInitialLoading: Bool { content == nil && isLoading }
  public var canRetry: Bool { !isLoading && !isRefreshing && failure != nil }

  mutating func beginRequest() {
    if content == nil {
      isLoading = true
    } else {
      isRefreshing = true
    }
    failure = nil
  }

  mutating func finish(with content: Content, at date: Date) {
    self.content = content
    isLoading = false
    isRefreshing = false
    failure = nil
    lastUpdatedAt = date
  }

  mutating func fail(with failure: FeatureFailure) {
    isLoading = false
    isRefreshing = false
    self.failure = failure
  }
}

public protocol FeatureClock: Sendable {
  func now() -> Date
}

public struct SystemFeatureClock: FeatureClock {
  public init() {}

  public func now() -> Date { Date() }
}

public struct FixedFeatureClock: FeatureClock {
  private let date: Date

  public init(_ date: Date) {
    self.date = date
  }

  public func now() -> Date { date }
}
