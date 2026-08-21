import Foundation

public enum EndpointError: Error, Equatable, Sendable {
  case invalidURL
}

public enum JolpicaEndpoint: Equatable, Sendable {
  case schedule(season: Int)
  case nextGrandPrix
  case raceResults(season: Int, round: Int)
  case qualifyingResults(season: Int, round: Int)
  case sprintResults(season: Int, round: Int)
  case driverStandings(season: Int)
  case teamStandings(season: Int)
  case drivers(season: Int)
  case teams(season: Int)

  public func url(baseURL: URL = URL(string: "https://api.jolpi.ca/ergast/f1")!) throws -> URL {
    let components: [String]
    switch self {
    case .schedule(let season):
      components = ["\(season).json"]
    case .nextGrandPrix:
      components = ["current", "next.json"]
    case .raceResults(let season, let round):
      components = ["\(season)", "\(round)", "results.json"]
    case .qualifyingResults(let season, let round):
      components = ["\(season)", "\(round)", "qualifying.json"]
    case .sprintResults(let season, let round):
      components = ["\(season)", "\(round)", "sprint.json"]
    case .driverStandings(let season):
      components = ["\(season)", "driverstandings.json"]
    case .teamStandings(let season):
      components = ["\(season)", "constructorstandings.json"]
    case .drivers(let season):
      components = ["\(season)", "drivers.json"]
    case .teams(let season):
      components = ["\(season)", "constructors.json"]
    }
    return try makeURL(
      baseURL: baseURL, pathComponents: components,
      queryItems: [URLQueryItem(name: "limit", value: "100")])
  }
}

public enum OpenF1Endpoint: Equatable, Sendable {
  case meetings(year: Int)
  case sessions(meetingKey: Int)
  case drivers(sessionKey: Int)
  case sessionResult(sessionKey: Int)

  public func url(baseURL: URL = URL(string: "https://api.openf1.org/v1")!) throws -> URL {
    let path: String
    let queryItem: URLQueryItem
    switch self {
    case .meetings(let year):
      path = "meetings"
      queryItem = URLQueryItem(name: "year", value: String(year))
    case .sessions(let meetingKey):
      path = "sessions"
      queryItem = URLQueryItem(name: "meeting_key", value: String(meetingKey))
    case .drivers(let sessionKey):
      path = "drivers"
      queryItem = URLQueryItem(name: "session_key", value: String(sessionKey))
    case .sessionResult(let sessionKey):
      path = "session_result"
      queryItem = URLQueryItem(name: "session_key", value: String(sessionKey))
    }
    return try makeURL(baseURL: baseURL, pathComponents: [path], queryItems: [queryItem])
  }
}

public struct APIRequestFactory: Sendable {
  public let userAgent: String

  public init(userAgent: String = "Apex/1.0 iOS") {
    self.userAgent = userAgent
  }

  public func request(for url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }
}

private func makeURL(baseURL: URL, pathComponents: [String], queryItems: [URLQueryItem]) throws
  -> URL
{
  var url = baseURL
  for component in pathComponents {
    url.appendPathComponent(component)
  }
  guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
    throw EndpointError.invalidURL
  }
  components.queryItems = queryItems
  guard let result = components.url else {
    throw EndpointError.invalidURL
  }
  return result
}
