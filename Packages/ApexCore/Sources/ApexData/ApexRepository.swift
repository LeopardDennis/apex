import ApexDomain
import ApexResources
import Foundation

public struct DataSourceConfiguration: Equatable, Sendable {
  public let jolpicaBaseURL: URL
  public let openF1BaseURL: URL

  public init(
    jolpicaBaseURL: URL = URL(string: "https://api.jolpi.ca/ergast/f1")!,
    openF1BaseURL: URL = URL(string: "https://api.openf1.org/v1")!
  ) {
    self.jolpicaBaseURL = jolpicaBaseURL
    self.openF1BaseURL = openF1BaseURL
  }
}

public actor ApexRepository: ApexDataRepository {
  private enum CacheDuration {
    static let schedule: TimeInterval = 12 * 60 * 60
    static let standings: TimeInterval = 60 * 60
    static let sessions: TimeInterval = 60 * 60
    static let results: TimeInterval = 60 * 60
  }

  private let client: APIClient
  private let catalog: SeasonResourceCatalog
  private let configuration: DataSourceConfiguration
  private let requestFactory: APIRequestFactory
  private let jolpicaDecoder: JolpicaDecoder
  private let openF1Decoder: OpenF1Decoder

  public init(
    client: APIClient,
    catalog: SeasonResourceCatalog,
    configuration: DataSourceConfiguration = DataSourceConfiguration(),
    requestFactory: APIRequestFactory = APIRequestFactory()
  ) {
    self.client = client
    self.catalog = catalog
    self.configuration = configuration
    self.requestFactory = requestFactory
    self.jolpicaDecoder = JolpicaDecoder()
    self.openF1Decoder = OpenF1Decoder()
  }

  public func schedule(season: Int, policy: LoadPolicy) async throws -> [GrandPrix] {
    guard season == catalog.season else {
      throw DataClientError.mapping("No bundled Apex catalog exists for season \(season).")
    }

    do {
      let response = try await fetch(
        OpenF1Endpoint.meetings(year: season).url(baseURL: configuration.openF1BaseURL),
        cacheKey: "openf1:meetings:\(season)",
        timeToLive: CacheDuration.schedule,
        policy: policy
      )
      return try openF1Decoder.schedule(from: response.data, catalog: catalog)
    } catch {
      do {
        let response = try await jolpicaSchedule(season: season, policy: policy)
        return try jolpicaDecoder.schedule(from: response.data, catalog: catalog)
      } catch {
        if policy == .cacheFirst { return catalog.grandPrix }
        throw error
      }
    }
  }

  public func sessions(grandPrixID: String, policy: LoadPolicy) async throws -> [RaceSession] {
    guard let grandPrix = catalog.grandPrix.first(where: { $0.id == grandPrixID }) else {
      throw DataClientError.mapping("Unknown Grand Prix identifier \(grandPrixID).")
    }

    do {
      let response = try await openF1Sessions(for: grandPrix, policy: policy)
      let mapped = try openF1Decoder.sessions(from: response.data, grandPrix: grandPrix)
      if !mapped.isEmpty { return mapped.map(\.session) }
    } catch {
      if policy == .reloadIgnoringCache {
        return try await jolpicaSessions(for: grandPrix, policy: policy)
      }
    }

    do {
      return try await jolpicaSessions(for: grandPrix, policy: policy)
    } catch {
      if policy == .cacheFirst { return [] }
      throw error
    }
  }

  public func result(sessionID: String, policy: LoadPolicy) async throws -> SessionResult? {
    let (grandPrix, kind) = try sessionIdentity(from: sessionID)
    switch kind {
    case .race, .sprint, .qualifying:
      do {
        if let result = try await jolpicaResult(
          grandPrix: grandPrix,
          kind: kind,
          sessionID: sessionID,
          policy: policy
        ) {
          return result
        }
      } catch {
        do {
          return try await openF1Result(
            grandPrix: grandPrix,
            kind: kind,
            sessionID: sessionID,
            policy: policy
          )
        } catch {
          if policy == .cacheFirst { return nil }
          throw error
        }
      }
      return try await openF1Result(
        grandPrix: grandPrix,
        kind: kind,
        sessionID: sessionID,
        policy: policy
      )

    case .practice1, .practice2, .practice3, .sprintQualifying:
      do {
        return try await openF1Result(
          grandPrix: grandPrix,
          kind: kind,
          sessionID: sessionID,
          policy: policy
        )
      } catch {
        if policy == .cacheFirst { return nil }
        throw error
      }
    }
  }

  public func driverStandings(season: Int, policy: LoadPolicy) async throws -> [DriverStanding] {
    guard season == catalog.season else {
      throw DataClientError.mapping("No bundled Apex catalog exists for season \(season).")
    }
    let url = try JolpicaEndpoint.driverStandings(season: season).url(
      baseURL: configuration.jolpicaBaseURL)
    let response = try await fetch(
      url,
      cacheKey: "jolpica:driver-standings:\(season)",
      timeToLive: CacheDuration.standings,
      policy: policy
    )
    return try jolpicaDecoder.driverStandings(from: response.data, catalog: catalog)
  }

  public func teamStandings(season: Int, policy: LoadPolicy) async throws -> [TeamStanding] {
    guard season == catalog.season else {
      throw DataClientError.mapping("No bundled Apex catalog exists for season \(season).")
    }
    let url = try JolpicaEndpoint.teamStandings(season: season).url(
      baseURL: configuration.jolpicaBaseURL)
    let response = try await fetch(
      url,
      cacheKey: "jolpica:team-standings:\(season)",
      timeToLive: CacheDuration.standings,
      policy: policy
    )
    return try jolpicaDecoder.teamStandings(from: response.data, catalog: catalog)
  }

  private func jolpicaSchedule(season: Int, policy: LoadPolicy) async throws -> APIDataResponse {
    let url = try JolpicaEndpoint.schedule(season: season).url(
      baseURL: configuration.jolpicaBaseURL)
    return try await fetch(
      url,
      cacheKey: "jolpica:schedule:\(season)",
      timeToLive: CacheDuration.schedule,
      policy: policy
    )
  }

  private func jolpicaSessions(for grandPrix: GrandPrix, policy: LoadPolicy) async throws
    -> [RaceSession]
  {
    let response = try await jolpicaSchedule(season: grandPrix.season, policy: policy)
    return try jolpicaDecoder.sessions(
      from: response.data,
      grandPrix: grandPrix
    )
  }

  private func openF1Sessions(for grandPrix: GrandPrix, policy: LoadPolicy) async throws
    -> APIDataResponse
  {
    let url = try OpenF1Endpoint.sessions(meetingKey: grandPrix.meetingKey).url(
      baseURL: configuration.openF1BaseURL)
    return try await fetch(
      url,
      cacheKey: "openf1:sessions:\(grandPrix.meetingKey)",
      timeToLive: CacheDuration.sessions,
      policy: policy
    )
  }

  private func jolpicaResult(
    grandPrix: GrandPrix,
    kind: SessionKind,
    sessionID: String,
    policy: LoadPolicy
  ) async throws -> SessionResult? {
    let endpoint: JolpicaEndpoint
    switch kind {
    case .race:
      endpoint = .raceResults(season: grandPrix.season, round: grandPrix.round)
    case .sprint:
      endpoint = .sprintResults(season: grandPrix.season, round: grandPrix.round)
    case .qualifying:
      endpoint = .qualifyingResults(season: grandPrix.season, round: grandPrix.round)
    default:
      return nil
    }
    let url = try endpoint.url(baseURL: configuration.jolpicaBaseURL)
    let response = try await fetch(
      url,
      cacheKey: "jolpica:result:\(sessionID)",
      timeToLive: CacheDuration.results,
      policy: policy
    )
    switch kind {
    case .race:
      return try jolpicaDecoder.raceResult(
        from: response.data,
        sessionID: sessionID,
        catalog: catalog,
        updatedAt: response.fetchedAt
      )
    case .sprint:
      return try jolpicaDecoder.sprintResult(
        from: response.data,
        sessionID: sessionID,
        catalog: catalog,
        updatedAt: response.fetchedAt
      )
    case .qualifying:
      return try jolpicaDecoder.qualifyingResult(
        from: response.data,
        sessionID: sessionID,
        catalog: catalog,
        updatedAt: response.fetchedAt
      )
    default:
      return nil
    }
  }

  private func openF1Result(
    grandPrix: GrandPrix,
    kind: SessionKind,
    sessionID: String,
    policy: LoadPolicy
  ) async throws -> SessionResult? {
    let sessionsResponse = try await openF1Sessions(for: grandPrix, policy: policy)
    let mappedSessions = try openF1Decoder.sessions(
      from: sessionsResponse.data,
      grandPrix: grandPrix
    )
    guard let sessionKey = mappedSessions.first(where: { $0.session.kind == kind })?.sessionKey
    else {
      return nil
    }

    async let resultResponse = fetch(
      try OpenF1Endpoint.sessionResult(sessionKey: sessionKey).url(
        baseURL: configuration.openF1BaseURL),
      cacheKey: "openf1:result:\(sessionKey)",
      timeToLive: CacheDuration.results,
      policy: policy
    )
    async let driversResponse = fetch(
      try OpenF1Endpoint.drivers(sessionKey: sessionKey).url(
        baseURL: configuration.openF1BaseURL),
      cacheKey: "openf1:drivers:\(sessionKey)",
      timeToLive: CacheDuration.results,
      policy: policy
    )
    let (result, drivers) = try await (resultResponse, driversResponse)
    return try openF1Decoder.result(
      from: result.data,
      driversData: drivers.data,
      sessionID: sessionID,
      catalog: catalog,
      updatedAt: max(result.fetchedAt, drivers.fetchedAt)
    )
  }

  private func fetch(
    _ url: URL,
    cacheKey: String,
    timeToLive: TimeInterval,
    policy: LoadPolicy
  ) async throws -> APIDataResponse {
    try await client.data(
      for: requestFactory.request(for: url),
      cacheKey: cacheKey,
      timeToLive: timeToLive,
      policy: policy
    )
  }

  private func sessionIdentity(from sessionID: String) throws -> (GrandPrix, SessionKind) {
    guard let grandPrix = catalog.grandPrix.first(where: { sessionID.hasPrefix($0.id + "-") })
    else {
      throw DataClientError.mapping("Unknown session identifier \(sessionID).")
    }
    let rawKind = String(sessionID.dropFirst(grandPrix.id.count + 1))
    guard let kind = SessionKind(rawValue: rawKind) else {
      throw DataClientError.mapping("Unknown session kind in \(sessionID).")
    }
    return (grandPrix, kind)
  }
}
