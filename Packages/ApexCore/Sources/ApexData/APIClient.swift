import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public final class URLSessionHTTPTransport: HTTPTransport, @unchecked Sendable {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw DataClientError.invalidResponse
    }
    return (data, response)
  }
}

public protocol RequestLimiter: Sendable {
  func waitForPermission() async
}

public actor IntervalRequestLimiter: RequestLimiter {
  private let minimumInterval: TimeInterval
  private var nextRequestDate: Date

  public init(requestsPerSecond: Double = 4) {
    self.minimumInterval = requestsPerSecond > 0 ? 1 / requestsPerSecond : 0
    self.nextRequestDate = .distantPast
  }

  public func waitForPermission() async {
    let now = Date()
    let reservedDate = max(now, nextRequestDate)
    nextRequestDate = reservedDate.addingTimeInterval(minimumInterval)
    let delay = reservedDate.timeIntervalSince(now)
    if delay > 0 {
      try? await Task.sleep(for: .seconds(delay))
    }
  }
}

public struct APIDataResponse: Equatable, Sendable {
  public let data: Data
  public let statusCode: Int
  public let fetchedAt: Date
  public let isStale: Bool

  public init(data: Data, statusCode: Int, fetchedAt: Date, isStale: Bool) {
    self.data = data
    self.statusCode = statusCode
    self.fetchedAt = fetchedAt
    self.isStale = isStale
  }
}

public actor APIClient {
  private let transport: any HTTPTransport
  private let cache: any HTTPResponseCache
  private let limiter: any RequestLimiter
  private var inFlight: [String: Task<APIDataResponse, Error>] = [:]

  public init(
    transport: any HTTPTransport = URLSessionHTTPTransport(),
    cache: any HTTPResponseCache = MemoryHTTPResponseCache(),
    limiter: any RequestLimiter = IntervalRequestLimiter()
  ) {
    self.transport = transport
    self.cache = cache
    self.limiter = limiter
  }

  public func data(
    for request: URLRequest,
    cacheKey: String,
    timeToLive: TimeInterval,
    policy: LoadPolicy
  ) async throws -> APIDataResponse {
    let cached = try? await cache.response(for: cacheKey)
    if policy == .cacheFirst, let cached, !cached.isExpired {
      return APIDataResponse(
        data: cached.data,
        statusCode: cached.statusCode,
        fetchedAt: cached.fetchedAt,
        isStale: false
      )
    }

    if let task = inFlight[cacheKey] {
      do {
        return try await task.value
      } catch {
        if policy == .cacheFirst, let cached {
          return staleResponse(from: cached)
        }
        throw error
      }
    }

    let transport = self.transport
    let cache = self.cache
    let limiter = self.limiter
    let task = Task<APIDataResponse, Error> {
      await limiter.waitForPermission()
      let data: Data
      let response: HTTPURLResponse
      do {
        (data, response) = try await transport.data(for: request)
      } catch let error as DataClientError {
        throw error
      } catch let error as URLError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
          throw DataClientError.offline
        case .timedOut:
          throw DataClientError.timeout
        default:
          throw DataClientError.network(error.localizedDescription)
        }
      } catch {
        throw DataClientError.network(String(describing: error))
      }
      let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(
        TimeInterval.init)
      if response.statusCode == 429 {
        throw DataClientError.rateLimited(retryAfter: retryAfter)
      }
      guard (200..<300).contains(response.statusCode) else {
        throw DataClientError.httpStatus(response.statusCode)
      }
      guard !data.isEmpty else { throw DataClientError.emptyPayload }

      let fetchedAt = Date()
      let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
        result[String(describing: item.key)] = String(describing: item.value)
      }
      let cachedResponse = CachedHTTPResponse(
        data: data,
        statusCode: response.statusCode,
        headers: headers,
        fetchedAt: fetchedAt,
        expiresAt: fetchedAt.addingTimeInterval(max(0, timeToLive))
      )
      try? await cache.store(cachedResponse, for: cacheKey)
      return APIDataResponse(
        data: data,
        statusCode: response.statusCode,
        fetchedAt: fetchedAt,
        isStale: false
      )
    }
    inFlight[cacheKey] = task

    do {
      let response = try await task.value
      inFlight[cacheKey] = nil
      return response
    } catch {
      inFlight[cacheKey] = nil
      if policy == .cacheFirst, let cached {
        return staleResponse(from: cached)
      }
      throw error
    }
  }

  public func json<T: Decodable & Sendable>(
    _ type: T.Type,
    for request: URLRequest,
    cacheKey: String,
    timeToLive: TimeInterval,
    policy: LoadPolicy
  ) async throws -> T {
    let response = try await data(
      for: request,
      cacheKey: cacheKey,
      timeToLive: timeToLive,
      policy: policy
    )
    do {
      return try JSONDecoder().decode(T.self, from: response.data)
    } catch {
      throw DataClientError.decoding(String(describing: error))
    }
  }

  private func staleResponse(from cached: CachedHTTPResponse) -> APIDataResponse {
    APIDataResponse(
      data: cached.data,
      statusCode: cached.statusCode,
      fetchedAt: cached.fetchedAt,
      isStale: true
    )
  }
}
