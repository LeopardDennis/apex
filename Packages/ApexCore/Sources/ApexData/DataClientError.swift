import Foundation

public enum DataClientError: Error, Equatable, LocalizedError, Sendable {
  case invalidResponse
  case offline
  case timeout
  case network(String)
  case httpStatus(Int)
  case rateLimited(retryAfter: TimeInterval?)
  case emptyPayload
  case decoding(String)
  case mapping(String)
  case cacheIO(String)

  public var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "The server did not return a valid HTTP response."
    case .offline:
      "The device is offline."
    case .timeout:
      "The request timed out."
    case .network(let detail):
      "The network request failed: \(detail)"
    case .httpStatus(let statusCode):
      "The server returned HTTP status \(statusCode)."
    case .rateLimited(let retryAfter):
      if let retryAfter {
        "The data source rate limit was reached. Retry after \(retryAfter) seconds."
      } else {
        "The data source rate limit was reached."
      }
    case .emptyPayload:
      "The server returned an empty response."
    case .decoding(let detail):
      "The response could not be decoded: \(detail)"
    case .mapping(let detail):
      "The response could not be mapped to Apex data: \(detail)"
    case .cacheIO(let detail):
      "The response cache could not be accessed: \(detail)"
    }
  }
}
