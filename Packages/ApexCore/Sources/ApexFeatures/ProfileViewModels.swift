import ApexData
import ApexDomain
import ApexResources
import Combine
import Foundation

public struct ProfileRoundPoints: Equatable, Identifiable, Sendable {
  public let grandPrixID: String
  public let round: Int
  public let localizedGrandPrixName: String
  public let points: Double

  public var id: String { grandPrixID }

  public init(
    grandPrixID: String,
    round: Int,
    localizedGrandPrixName: String,
    points: Double
  ) {
    self.grandPrixID = grandPrixID
    self.round = round
    self.localizedGrandPrixName = localizedGrandPrixName
    self.points = points
  }
}

public struct ProfileRecentResult: Equatable, Identifiable, Sendable {
  public let grandPrixID: String
  public let round: Int
  public let localizedGrandPrixName: String
  public let position: Int?
  public let points: Double

  public var id: String { grandPrixID }

  public init(
    grandPrixID: String,
    round: Int,
    localizedGrandPrixName: String,
    position: Int?,
    points: Double
  ) {
    self.grandPrixID = grandPrixID
    self.round = round
    self.localizedGrandPrixName = localizedGrandPrixName
    self.position = position
    self.points = points
  }
}

public struct DriverProfileOverview: Equatable, Sendable {
  public let driver: Driver
  public let team: Team?
  public let standing: DriverStanding?

  public init(driver: Driver, team: Team?, standing: DriverStanding?) {
    self.driver = driver
    self.team = team
    self.standing = standing
  }
}

public struct DriverHistorySummary: Equatable, Sendable {
  public let podiums: Int
  public let poles: Int
  public let pointsByRound: [ProfileRoundPoints]
  public let recentResults: [ProfileRecentResult]

  public init(
    podiums: Int,
    poles: Int,
    pointsByRound: [ProfileRoundPoints],
    recentResults: [ProfileRecentResult]
  ) {
    self.podiums = podiums
    self.poles = poles
    self.pointsByRound = pointsByRound
    self.recentResults = recentResults
  }
}

public struct TeamDriverSummary: Equatable, Identifiable, Sendable {
  public let driver: Driver
  public let points: Double

  public var id: String { driver.id }

  public init(driver: Driver, points: Double) {
    self.driver = driver
    self.points = points
  }
}

public struct TeamProfileOverview: Equatable, Sendable {
  public let team: Team
  public let standing: TeamStanding?
  public let drivers: [TeamDriverSummary]

  public init(team: Team, standing: TeamStanding?, drivers: [TeamDriverSummary]) {
    self.team = team
    self.standing = standing
    self.drivers = drivers
  }
}

public struct TeamHistorySummary: Equatable, Sendable {
  public let poles: Int
  public let pointsByRound: [ProfileRoundPoints]
  public let recentResults: [ProfileRecentResult]

  public init(
    poles: Int,
    pointsByRound: [ProfileRoundPoints],
    recentResults: [ProfileRecentResult]
  ) {
    self.poles = poles
    self.pointsByRound = pointsByRound
    self.recentResults = recentResults
  }
}

@MainActor
public final class DriverProfileViewModel: ObservableObject {
  @Published public private(set) var overviewState: FeatureState<DriverProfileOverview>
  @Published public private(set) var historyState: FeatureState<DriverHistorySummary>

  private let season: Int
  private let driver: Driver?
  private let team: Team?
  private let repository: any ApexDataRepository
  private let clock: any FeatureClock
  private var overviewRequestVersion = 0
  private var historyRequestVersion = 0

  public init(
    driverID: String,
    catalog: SeasonResourceCatalog,
    repository: any ApexDataRepository,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    let driver = catalog.drivers.first { $0.id == driverID }
    self.season = catalog.season
    self.driver = driver
    self.team = driver.flatMap { value in catalog.teams.first { $0.id == value.teamID } }
    self.repository = repository
    self.clock = clock
    self.overviewState = FeatureState()
    self.historyState = FeatureState()
  }

  public func load() async {
    async let overview: Void = requestOverview(policy: .cacheFirst)
    async let history: Void = requestHistory(policy: .cacheFirst)
    _ = await (overview, history)
  }

  public func refresh() async {
    async let overview: Void = requestOverview(policy: .reloadIgnoringCache)
    async let history: Void = requestHistory(policy: .reloadIgnoringCache)
    _ = await (overview, history)
  }

  private func requestOverview(policy: LoadPolicy) async {
    overviewRequestVersion += 1
    let version = overviewRequestVersion
    overviewState.beginRequest()
    guard let driver else {
      overviewState.fail(
        with: FeatureFailure(error: DataClientError.mapping("Unknown driver identifier.")))
      return
    }
    do {
      let standings = try await repository.driverStandings(season: season, policy: policy)
      guard version == overviewRequestVersion else { return }
      overviewState.finish(
        with: DriverProfileOverview(
          driver: driver,
          team: team,
          standing: standings.first { $0.driverID == driver.id }
        ),
        at: clock.now()
      )
    } catch {
      guard version == overviewRequestVersion else { return }
      overviewState.fail(with: FeatureFailure(error: error))
    }
  }

  private func requestHistory(policy: LoadPolicy) async {
    historyRequestVersion += 1
    let version = historyRequestVersion
    historyState.beginRequest()
    guard let driver else {
      historyState.fail(
        with: FeatureFailure(error: DataClientError.mapping("Unknown driver identifier.")))
      return
    }
    do {
      let history = try await repository.seasonHistory(
        season: season,
        subject: .driver(driver.id),
        policy: policy
      )
      guard version == historyRequestVersion else { return }
      historyState.finish(
        with: ProfileHistoryBuilder.driverSummary(history: history, driverID: driver.id),
        at: history.updatedAt
      )
    } catch {
      guard version == historyRequestVersion else { return }
      historyState.fail(with: FeatureFailure(error: error))
    }
  }
}

@MainActor
public final class TeamProfileViewModel: ObservableObject {
  @Published public private(set) var overviewState: FeatureState<TeamProfileOverview>
  @Published public private(set) var historyState: FeatureState<TeamHistorySummary>

  private let season: Int
  private let team: Team?
  private let roster: [Driver]
  private let repository: any ApexDataRepository
  private let clock: any FeatureClock
  private var overviewRequestVersion = 0
  private var historyRequestVersion = 0

  public init(
    teamID: String,
    catalog: SeasonResourceCatalog,
    repository: any ApexDataRepository,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.season = catalog.season
    self.team = catalog.teams.first { $0.id == teamID }
    self.roster = catalog.drivers.filter { $0.teamID == teamID }.sorted { $0.number < $1.number }
    self.repository = repository
    self.clock = clock
    self.overviewState = FeatureState()
    self.historyState = FeatureState()
  }

  public func load() async {
    async let overview: Void = requestOverview(policy: .cacheFirst)
    async let history: Void = requestHistory(policy: .cacheFirst)
    _ = await (overview, history)
  }

  public func refresh() async {
    async let overview: Void = requestOverview(policy: .reloadIgnoringCache)
    async let history: Void = requestHistory(policy: .reloadIgnoringCache)
    _ = await (overview, history)
  }

  private func requestOverview(policy: LoadPolicy) async {
    overviewRequestVersion += 1
    let version = overviewRequestVersion
    overviewState.beginRequest()
    guard let team else {
      overviewState.fail(
        with: FeatureFailure(error: DataClientError.mapping("Unknown team identifier.")))
      return
    }
    do {
      async let teamStandings = repository.teamStandings(season: season, policy: policy)
      async let driverStandings = repository.driverStandings(season: season, policy: policy)
      let (teams, drivers) = try await (teamStandings, driverStandings)
      guard version == overviewRequestVersion else { return }
      let pointsByDriver = Dictionary(
        uniqueKeysWithValues: drivers.map { ($0.driverID, $0.points) })
      overviewState.finish(
        with: TeamProfileOverview(
          team: team,
          standing: teams.first { $0.teamID == team.id },
          drivers: roster.map {
            TeamDriverSummary(driver: $0, points: pointsByDriver[$0.id] ?? 0)
          }
        ),
        at: clock.now()
      )
    } catch {
      guard version == overviewRequestVersion else { return }
      overviewState.fail(with: FeatureFailure(error: error))
    }
  }

  private func requestHistory(policy: LoadPolicy) async {
    historyRequestVersion += 1
    let version = historyRequestVersion
    historyState.beginRequest()
    guard let team else {
      historyState.fail(
        with: FeatureFailure(error: DataClientError.mapping("Unknown team identifier.")))
      return
    }
    do {
      let history = try await repository.seasonHistory(
        season: season,
        subject: .team(team.id),
        policy: policy
      )
      guard version == historyRequestVersion else { return }
      historyState.finish(
        with: ProfileHistoryBuilder.teamSummary(history: history, teamID: team.id),
        at: history.updatedAt
      )
    } catch {
      guard version == historyRequestVersion else { return }
      historyState.fail(with: FeatureFailure(error: error))
    }
  }
}

private enum ProfileHistoryBuilder {
  static func driverSummary(history: SeasonHistory, driverID: String) -> DriverHistorySummary {
    let raceSessions = history.sessions.filter { $0.kind == .race }
    let podiums = raceSessions.reduce(into: 0) { count, session in
      guard
        let position = session.result.entries.first(where: { $0.driverID == driverID })?.position,
        (1...3).contains(position)
      else { return }
      count += 1
    }
    let poles = history.sessions.filter { $0.kind == .qualifying }.reduce(into: 0) {
      count, session in
      if session.result.entries.first(where: { $0.driverID == driverID })?.position == 1 {
        count += 1
      }
    }
    return DriverHistorySummary(
      podiums: podiums,
      poles: poles,
      pointsByRound: pointsByRound(history: history) { $0.driverID == driverID },
      recentResults: recentResults(history: history) { $0.driverID == driverID }
    )
  }

  static func teamSummary(history: SeasonHistory, teamID: String) -> TeamHistorySummary {
    let poles = history.sessions.filter { $0.kind == .qualifying }.reduce(into: 0) {
      count, session in
      if session.result.entries.contains(where: { $0.teamID == teamID && $0.position == 1 }) {
        count += 1
      }
    }
    return TeamHistorySummary(
      poles: poles,
      pointsByRound: pointsByRound(history: history) { $0.teamID == teamID },
      recentResults: recentResults(history: history) { $0.teamID == teamID }
    )
  }

  private static func pointsByRound(
    history: SeasonHistory,
    matches: (SessionResultEntry) -> Bool
  ) -> [ProfileRoundPoints] {
    let pointSessions = history.sessions.filter { $0.kind == .race || $0.kind == .sprint }
    let grouped = Dictionary(grouping: pointSessions, by: \.grandPrixID)
    return grouped.values.compactMap { sessions in
      guard let event = sessions.first else { return nil }
      let points =
        sessions
        .flatMap(\.result.entries)
        .filter(matches)
        .compactMap(\.points)
        .reduce(0, +)
      return ProfileRoundPoints(
        grandPrixID: event.grandPrixID,
        round: event.round,
        localizedGrandPrixName: event.localizedGrandPrixName,
        points: points
      )
    }.sorted { $0.round < $1.round }
  }

  private static func recentResults(
    history: SeasonHistory,
    matches: (SessionResultEntry) -> Bool
  ) -> [ProfileRecentResult] {
    history.sessions
      .filter { $0.kind == .race }
      .compactMap { session in
        let entries = session.result.entries.filter(matches)
        guard !entries.isEmpty else { return nil }
        return ProfileRecentResult(
          grandPrixID: session.grandPrixID,
          round: session.round,
          localizedGrandPrixName: session.localizedGrandPrixName,
          position: entries.compactMap(\.position).min(),
          points: entries.compactMap(\.points).reduce(0, +)
        )
      }
      .sorted { $0.round > $1.round }
      .prefix(5)
      .map { $0 }
  }
}
