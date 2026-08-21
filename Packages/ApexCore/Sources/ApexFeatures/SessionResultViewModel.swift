import ApexData
import ApexDomain
import ApexResources
import Combine
import Foundation

public enum SessionResultAvailability: String, Equatable, Sendable {
  case scheduled
  case cancelled
  case pending
  case available
}

public struct SessionResultRow: Equatable, Identifiable, Sendable {
  public let entry: SessionResultEntry
  public let driver: Driver?
  public let team: Team?

  public var id: String { entry.id }
  public var localizedDriverName: String { driver?.localizedName ?? entry.driverID }
  public var driverCode: String { driver?.code ?? entry.driverID.uppercased() }
  public var localizedTeamName: String { team?.localizedName ?? entry.teamID }
  public var teamColor: String { team?.primaryColor ?? "#6B7280" }
  public var timeOrGap: String? { entry.time ?? entry.gap ?? entry.status }

  public init(entry: SessionResultEntry, driver: Driver?, team: Team?) {
    self.entry = entry
    self.driver = driver
    self.team = team
  }
}

public struct SessionResultContent: Equatable, Sendable {
  public let session: RaceSession
  public let availability: SessionResultAvailability
  public let rows: [SessionResultRow]
  public let resultUpdatedAt: Date?

  public init(
    session: RaceSession,
    result: SessionResult?,
    catalog: SeasonResourceCatalog,
    now: Date
  ) {
    let driversByID = Dictionary(uniqueKeysWithValues: catalog.drivers.map { ($0.id, $0) })
    let teamsByID = Dictionary(uniqueKeysWithValues: catalog.teams.map { ($0.id, $0) })
    self.session = session
    self.availability = Self.availability(session: session, result: result, now: now)
    self.rows = (result?.entries ?? [])
      .enumerated()
      .sorted { left, right in
        let leftPosition = left.element.position ?? Int.max
        let rightPosition = right.element.position ?? Int.max
        if leftPosition == rightPosition { return left.offset < right.offset }
        return leftPosition < rightPosition
      }
      .map { _, entry in
        SessionResultRow(
          entry: entry,
          driver: driversByID[entry.driverID],
          team: teamsByID[entry.teamID]
        )
      }
    self.resultUpdatedAt = result?.updatedAt
  }

  private static func availability(
    session: RaceSession,
    result: SessionResult?,
    now: Date
  ) -> SessionResultAvailability {
    if result != nil { return .available }
    if session.state == .cancelled { return .cancelled }
    if session.dateEnd > now && session.state == .scheduled { return .scheduled }
    return .pending
  }
}

@MainActor
public final class SessionResultViewModel: ObservableObject {
  @Published public private(set) var state: FeatureState<SessionResultContent>

  private let session: RaceSession
  private let catalog: SeasonResourceCatalog
  private let repository: any ResultsRepository
  private let clock: any FeatureClock
  private var requestVersion = 0

  public init(
    session: RaceSession,
    catalog: SeasonResourceCatalog,
    repository: any ResultsRepository,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.session = session
    self.catalog = catalog
    self.repository = repository
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
    do {
      let result = try await repository.result(sessionID: session.id, policy: policy)
      guard version == requestVersion else { return }
      let now = clock.now()
      state.finish(
        with: SessionResultContent(
          session: session,
          result: result,
          catalog: catalog,
          now: now
        ),
        at: result?.updatedAt ?? now
      )
    } catch {
      guard version == requestVersion else { return }
      state.fail(with: FeatureFailure(error: error))
    }
  }
}
