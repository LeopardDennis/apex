import ApexData
import ApexDomain
import ApexResources
import Combine
import Foundation

public enum StandingsCategory: String, CaseIterable, Equatable, Sendable {
  case drivers
  case teams
}

public struct DriverStandingRow: Equatable, Identifiable, Sendable {
  public let standing: DriverStanding
  public let driver: Driver?
  public let team: Team?

  public var id: String { standing.id }
  public var localizedDriverName: String { driver?.localizedName ?? standing.driverID }
  public var driverCode: String { driver?.code ?? standing.driverID.uppercased() }
  public var localizedTeamName: String { team?.localizedName ?? standing.teamID }
  public var teamColor: String { team?.primaryColor ?? "#6B7280" }

  public init(standing: DriverStanding, driver: Driver?, team: Team?) {
    self.standing = standing
    self.driver = driver
    self.team = team
  }
}

public struct TeamStandingRow: Equatable, Identifiable, Sendable {
  public let standing: TeamStanding
  public let team: Team?

  public var id: String { standing.id }
  public var localizedTeamName: String { team?.localizedName ?? standing.teamID }
  public var englishTeamName: String { team?.name ?? standing.teamID }
  public var teamColor: String { team?.primaryColor ?? "#6B7280" }

  public init(standing: TeamStanding, team: Team?) {
    self.standing = standing
    self.team = team
  }
}

@MainActor
public final class StandingsViewModel: ObservableObject {
  @Published public private(set) var driverState: FeatureState<[DriverStandingRow]>
  @Published public private(set) var teamState: FeatureState<[TeamStandingRow]>
  @Published public var selectedCategory: StandingsCategory
  @Published public private(set) var selectedDriverID: String?
  @Published public private(set) var selectedTeamID: String?

  private let season: Int
  private let repository: any StandingsRepository
  private let driversByID: [String: Driver]
  private let teamsByID: [String: Team]
  private let clock: any FeatureClock
  private var driverRequestVersion = 0
  private var teamRequestVersion = 0

  public init(
    catalog: SeasonResourceCatalog,
    repository: any StandingsRepository,
    selectedCategory: StandingsCategory = .drivers,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.season = catalog.season
    self.repository = repository
    self.driversByID = Dictionary(uniqueKeysWithValues: catalog.drivers.map { ($0.id, $0) })
    self.teamsByID = Dictionary(uniqueKeysWithValues: catalog.teams.map { ($0.id, $0) })
    self.selectedCategory = selectedCategory
    self.clock = clock
    self.driverState = FeatureState()
    self.teamState = FeatureState()
  }

  public func load() async {
    async let drivers: Void = requestDrivers(policy: .cacheFirst)
    async let teams: Void = requestTeams(policy: .cacheFirst)
    _ = await (drivers, teams)
  }

  public func refresh() async {
    async let drivers: Void = requestDrivers(policy: .reloadIgnoringCache)
    async let teams: Void = requestTeams(policy: .reloadIgnoringCache)
    _ = await (drivers, teams)
  }

  public func select(driverID: String?) {
    guard let driverID else {
      selectedDriverID = nil
      return
    }
    guard driverState.content?.contains(where: { $0.id == driverID }) == true else { return }
    selectedDriverID = driverID
  }

  public func select(teamID: String?) {
    guard let teamID else {
      selectedTeamID = nil
      return
    }
    guard teamState.content?.contains(where: { $0.id == teamID }) == true else { return }
    selectedTeamID = teamID
  }

  private func requestDrivers(policy: LoadPolicy) async {
    driverRequestVersion += 1
    let version = driverRequestVersion
    driverState.beginRequest()

    do {
      let standings = try await repository.driverStandings(season: season, policy: policy)
      guard version == driverRequestVersion else { return }
      let rows =
        standings
        .sorted { $0.position < $1.position }
        .map { standing in
          DriverStandingRow(
            standing: standing,
            driver: driversByID[standing.driverID],
            team: teamsByID[standing.teamID]
          )
        }
      driverState.finish(with: rows, at: clock.now())
      if selectedDriverID == nil || !rows.contains(where: { $0.id == selectedDriverID }) {
        selectedDriverID = rows.first?.id
      }
    } catch {
      guard version == driverRequestVersion else { return }
      driverState.fail(with: FeatureFailure(error: error))
    }
  }

  private func requestTeams(policy: LoadPolicy) async {
    teamRequestVersion += 1
    let version = teamRequestVersion
    teamState.beginRequest()

    do {
      let standings = try await repository.teamStandings(season: season, policy: policy)
      guard version == teamRequestVersion else { return }
      let rows =
        standings
        .sorted { $0.position < $1.position }
        .map { standing in
          TeamStandingRow(standing: standing, team: teamsByID[standing.teamID])
        }
      teamState.finish(with: rows, at: clock.now())
      if selectedTeamID == nil || !rows.contains(where: { $0.id == selectedTeamID }) {
        selectedTeamID = rows.first?.id
      }
    } catch {
      guard version == teamRequestVersion else { return }
      teamState.fail(with: FeatureFailure(error: error))
    }
  }
}
