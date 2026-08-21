import Foundation

public struct CachedHTTPResponse: Codable, Equatable, Sendable {
  public let data: Data
  public let statusCode: Int
  public let headers: [String: String]
  public let fetchedAt: Date
  public let expiresAt: Date

  public var isExpired: Bool { isExpired(at: Date()) }

  public init(
    data: Data,
    statusCode: Int,
    headers: [String: String],
    fetchedAt: Date,
    expiresAt: Date
  ) {
    self.data = data
    self.statusCode = statusCode
    self.headers = headers
    self.fetchedAt = fetchedAt
    self.expiresAt = expiresAt
  }

  public func isExpired(at date: Date) -> Bool {
    expiresAt <= date
  }
}

public protocol HTTPResponseCache: Sendable {
  func response(for key: String) async throws -> CachedHTTPResponse?
  func store(_ response: CachedHTTPResponse, for key: String) async throws
  func removeResponse(for key: String) async throws
}

public actor MemoryHTTPResponseCache: HTTPResponseCache {
  private var responses: [String: CachedHTTPResponse]

  public init(responses: [String: CachedHTTPResponse] = [:]) {
    self.responses = responses
  }

  public func response(for key: String) -> CachedHTTPResponse? {
    responses[key]
  }

  public func store(_ response: CachedHTTPResponse, for key: String) {
    responses[key] = response
  }

  public func removeResponse(for key: String) {
    responses[key] = nil
  }
}

public actor FileHTTPResponseCache: HTTPResponseCache {
  private let directory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL, fileManager: FileManager = .default) {
    self.directory = directory
    self.fileManager = fileManager
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
  }

  public func response(for key: String) throws -> CachedHTTPResponse? {
    let url = fileURL(for: key)
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    do {
      return try decoder.decode(CachedHTTPResponse.self, from: Data(contentsOf: url))
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  public func store(_ response: CachedHTTPResponse, for key: String) throws {
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      let data = try encoder.encode(response)
      try data.write(to: fileURL(for: key), options: .atomic)
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  public func removeResponse(for key: String) throws {
    let url = fileURL(for: key)
    guard fileManager.fileExists(atPath: url.path) else { return }
    do {
      try fileManager.removeItem(at: url)
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  private func fileURL(for key: String) -> URL {
    directory.appendingPathComponent(stableHash(key)).appendingPathExtension("json")
  }
}

private func stableHash(_ value: String) -> String {
  var hash: UInt64 = 14_695_981_039_346_656_037
  for byte in value.utf8 {
    hash ^= UInt64(byte)
    hash &*= 1_099_511_628_211
  }
  return String(hash, radix: 16)
}
