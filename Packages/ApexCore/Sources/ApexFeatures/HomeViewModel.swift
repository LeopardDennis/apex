import ApexData
import ApexDomain
import ApexResources
import Combine
import Foundation

public enum HomeDataSection: String, Equatable, Sendable {
  case sessions
  case driverStandings
  case teamStandings
  case widgetSnapshot
}

public struct HomeDataIssue: Equatable, Identifiable, Sendable {
  public let section: HomeDataSection
  public let failure: FeatureFailure

  public var id: String { section.rawValue }

  public init(section: HomeDataSection, failure: FeatureFailure) {
    self.section = section
    self.failure = failure
  }
}

public struct HomeContent: Equatable, Sendable {
  public let season: Int
  public let featuredGrandPrix: GrandPrix?
  public let featuredGrandPrixState: GrandPrixState?
  public let followingGrandPrix: [GrandPrix]
  public let sessions: [RaceSession]
  public let featuredSession: RaceSession?
  public let isFeaturedSessionInProgress: Bool
  public let countdown: Countdown?
  public let driverLeader: DriverStandingRow?
  public let teamLeader: TeamStandingRow?
  public let issues: [HomeDataIssue]
  public let widgetSnapshot: ApexWidgetSnapshot

  public init(
    season: Int,
    schedule: [GrandPrix],
    sessions: [RaceSession],
    driverStandings: [DriverStanding],
    teamStandings: [TeamStanding],
    catalog: SeasonResourceCatalog,
    issues: [HomeDataIssue],
    widgetSnapshot: ApexWidgetSnapshot,
    now: Date
  ) {
    let sortedSchedule = schedule.sorted { $0.round < $1.round }
    let featuredGrandPrix = ScheduleClock.currentOrNextGrandPrix(in: sortedSchedule, at: now)
    let relevantSessions =
      sessions
      .filter { $0.grandPrixID == featuredGrandPrix?.id }
      .sorted { $0.dateStart < $1.dateStart }
    let featuredSession = ScheduleClock.nextSession(in: relevantSessions, at: now)
    let countdownTarget = Self.countdownTarget(
      grandPrix: featuredGrandPrix,
      session: featuredSession,
      now: now
    )
    let driversByID = Dictionary(uniqueKeysWithValues: catalog.drivers.map { ($0.id, $0) })
    let teamsByID = Dictionary(uniqueKeysWithValues: catalog.teams.map { ($0.id, $0) })
    let leadingDriver = driverStandings.min { $0.position < $1.position }
    let leadingTeam = teamStandings.min { $0.position < $1.position }

    self.season = season
    self.featuredGrandPrix = featuredGrandPrix
    self.featuredGrandPrixState = featuredGrandPrix.map { ScheduleClock.state(of: $0, at: now) }
    self.followingGrandPrix = sortedSchedule.filter {
      guard let featuredGrandPrix else { return false }
      return $0.round > featuredGrandPrix.round
    }
    self.sessions = relevantSessions
    self.featuredSession = featuredSession
    self.isFeaturedSessionInProgress =
      featuredSession.map {
        $0.dateStart <= now && now <= $0.dateEnd
      } ?? false
    self.countdown = countdownTarget.map { ScheduleClock.countdown(to: $0, from: now) }
    self.driverLeader = leadingDriver.map {
      DriverStandingRow(
        standing: $0,
        driver: driversByID[$0.driverID],
        team: teamsByID[$0.teamID]
      )
    }
    self.teamLeader = leadingTeam.map {
      TeamStandingRow(standing: $0, team: teamsByID[$0.teamID])
    }
    self.issues = issues
    self.widgetSnapshot = widgetSnapshot
  }

  private static func countdownTarget(
    grandPrix: GrandPrix?,
    session: RaceSession?,
    now: Date
  ) -> Date? {
    if let session, session.dateStart > now { return session.dateStart }
    if let grandPrix, grandPrix.dateStart > now { return grandPrix.dateStart }
    return nil
  }
}

@MainActor
public final class HomeViewModel: ObservableObject {
  @Published public private(set) var state: FeatureState<HomeContent>

  private let catalog: SeasonResourceCatalog
  private let repository: any ApexDataRepository
  private let widgetSnapshotStore: any WidgetSnapshotStore
  private let widgetSnapshotBuilder: WidgetSnapshotBuilder
  private let clock: any FeatureClock
  private var requestVersion = 0

  public init(
    catalog: SeasonResourceCatalog,
    repository: any ApexDataRepository,
    widgetSnapshotStore: any WidgetSnapshotStore,
    widgetSnapshotBuilder: WidgetSnapshotBuilder = WidgetSnapshotBuilder(),
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.catalog = catalog
    self.repository = repository
    self.widgetSnapshotStore = widgetSnapshotStore
    self.widgetSnapshotBuilder = widgetSnapshotBuilder
    self.clock = clock
    self.state = FeatureState()
  }

  public func load() async {
    await request(policy: .cacheFirst)
  }

  public func refresh() async {
    await request(policy: .reloadIgnoringCache)
  }

  private func request(policy: LoadPolicy) async {
    requestVersion += 1
    let version = requestVersion
    state.beginRequest()

    async let driverLoad = loadDriverStandings(policy: policy)
    async let teamLoad = loadTeamStandings(policy: policy)

    do {
      let schedule = try await repository.schedule(season: catalog.season, policy: policy)
      let now = clock.now()
      guard version == requestVersion else { return }

      let featuredGrandPrix = ScheduleClock.currentOrNextGrandPrix(in: schedule, at: now)
      async let sessionLoad = loadSessions(
        grandPrixID: featuredGrandPrix?.id,
        policy: policy
      )
      let (sessionsResult, driverResult, teamResult) = await (
        sessionLoad,
        driverLoad,
        teamLoad
      )
      guard version == requestVersion else { return }

      let snapshot = widgetSnapshotBuilder.makeSnapshot(
        schedule: schedule,
        sessions: sessionsResult.value,
        driverStandings: driverResult.value,
        teamStandings: teamResult.value,
        catalog: catalog,
        at: now
      )
      var issues = [sessionsResult.issue, driverResult.issue, teamResult.issue].compactMap { $0 }
      do {
        try await widgetSnapshotStore.saveSnapshot(snapshot)
      } catch {
        issues.append(
          HomeDataIssue(
            section: .widgetSnapshot,
            failure: FeatureFailure(
              code: .cacheUnavailable,
              title: "小组件数据暂未更新",
              message: "首页仍可使用，稍后会再次同步小组件。"
            )
          )
        )
      }
      guard version == requestVersion else { return }

      state.finish(
        with: HomeContent(
          season: catalog.season,
          schedule: schedule,
          sessions: sessionsResult.value,
          driverStandings: driverResult.value,
          teamStandings: teamResult.value,
          catalog: catalog,
          issues: issues,
          widgetSnapshot: snapshot,
          now: now
        ),
        at: now
      )
    } catch {
      guard version == requestVersion else { return }
      state.fail(with: FeatureFailure(error: error))
    }
  }

  private func loadSessions(
    grandPrixID: String?,
    policy: LoadPolicy
  ) async -> HomeSupplementalLoad<[RaceSession]> {
    guard let grandPrixID else { return HomeSupplementalLoad(value: []) }
    do {
      return HomeSupplementalLoad(
        value: try await repository.sessions(grandPrixID: grandPrixID, policy: policy)
      )
    } catch {
      return HomeSupplementalLoad(
        value: [],
        issue: HomeDataIssue(section: .sessions, failure: FeatureFailure(error: error))
      )
    }
  }

  private func loadDriverStandings(
    policy: LoadPolicy
  ) async -> HomeSupplementalLoad<[DriverStanding]> {
    do {
      return HomeSupplementalLoad(
        value: try await repository.driverStandings(season: catalog.season, policy: policy)
      )
    } catch {
      return HomeSupplementalLoad(
        value: [],
        issue: HomeDataIssue(section: .driverStandings, failure: FeatureFailure(error: error))
      )
    }
  }

  private func loadTeamStandings(
    policy: LoadPolicy
  ) async -> HomeSupplementalLoad<[TeamStanding]> {
    do {
      return HomeSupplementalLoad(
        value: try await repository.teamStandings(season: catalog.season, policy: policy)
      )
    } catch {
      return HomeSupplementalLoad(
        value: [],
        issue: HomeDataIssue(section: .teamStandings, failure: FeatureFailure(error: error))
      )
    }
  }
}

private struct HomeSupplementalLoad<Value: Sendable>: Sendable {
  let value: Value
  let issue: HomeDataIssue?

  init(value: Value, issue: HomeDataIssue? = nil) {
    self.value = value
    self.issue = issue
  }
}
