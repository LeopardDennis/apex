import ApexData
import Foundation
import Testing

@Test
func apiClientCoalescesMatchingConcurrentRequests() async throws {
  let transport = CountingTransport(payload: Data("ok".utf8))
  let client = APIClient(
    transport: transport,
    cache: MemoryHTTPResponseCache(),
    limiter: ImmediateLimiter()
  )
  let request = URLRequest(url: URL(string: "https://example.com/data")!)

  async let first = client.data(
    for: request,
    cacheKey: "same",
    timeToLive: 60,
    policy: .reloadIgnoringCache
  )
  async let second = client.data(
    for: request,
    cacheKey: "same",
    timeToLive: 60,
    policy: .reloadIgnoringCache
  )
  let responses = try await [first, second]

  #expect(responses[0].data == Data("ok".utf8))
  let requestCount = await transport.requestCount
  #expect(requestCount == 1)
}

@Test
func apiClientFallsBackToExpiredCacheWhenRefreshFails() async throws {
  let now = Date()
  let cached = CachedHTTPResponse(
    data: Data("cached".utf8),
    statusCode: 200,
    headers: [:],
    fetchedAt: now.addingTimeInterval(-120),
    expiresAt: now.addingTimeInterval(-60)
  )
  let client = APIClient(
    transport: FailingTransport(),
    cache: MemoryHTTPResponseCache(responses: ["stale": cached]),
    limiter: ImmediateLimiter()
  )
  let request = URLRequest(url: URL(string: "https://example.com/data")!)

  let response = try await client.data(
    for: request,
    cacheKey: "stale",
    timeToLive: 60,
    policy: .cacheFirst
  )

  #expect(response.data == Data("cached".utf8))
  #expect(response.isStale)
}

private actor CountingTransport: HTTPTransport {
  private let payload: Data
  private(set) var requestCount = 0

  init(payload: Data) {
    self.payload = payload
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requestCount += 1
    try await Task.sleep(for: .milliseconds(20))
    return (
      payload,
      HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
    )
  }
}

private struct FailingTransport: HTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    throw URLError(.notConnectedToInternet)
  }
}

private struct ImmediateLimiter: RequestLimiter {
  func waitForPermission() async {}
}
