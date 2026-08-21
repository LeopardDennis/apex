import ApexData
import ApexDomain
import Combine
import Foundation

public struct CalendarListItem: Equatable, Identifiable, Sendable {
  public let grandPrix: GrandPrix
  public let state: GrandPrixState

  public var id: String { grandPrix.id }

  public init(grandPrix: GrandPrix, state: GrandPrixState) {
    self.grandPrix = grandPrix
    self.state = state
  }
}

public struct CalendarContent: Equatable, Sendable {
  public let season: Int
  public let upcoming: [CalendarListItem]
  public let completed: [CalendarListItem]
  public let currentOrNextGrandPrixID: String?

  public init(season: Int, schedule: [GrandPrix], now: Date) {
    let items =
      schedule
      .sorted { $0.round < $1.round }
      .map { CalendarListItem(grandPrix: $0, state: ScheduleClock.state(of: $0, at: now)) }
    self.season = season
    self.upcoming = items.filter { $0.state != .completed }
    self.completed = items.filter { $0.state == .completed }
    self.currentOrNextGrandPrixID =
      ScheduleClock.currentOrNextGrandPrix(
        in: schedule,
        at: now
      )?.id
  }

  public var all: [CalendarListItem] { completed + upcoming }
}

@MainActor
public final class CalendarViewModel: ObservableObject {
  @Published public private(set) var state: FeatureState<CalendarContent>
  @Published public private(set) var selectedGrandPrixID: String?

  private let season: Int
  private let repository: any ScheduleRepository
  private let clock: any FeatureClock
  private var requestVersion = 0

  public init(
    season: Int,
    repository: any ScheduleRepository,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.season = season
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

  public func select(grandPrixID: String?) {
    guard let grandPrixID else {
      selectedGrandPrixID = nil
      return
    }
    guard state.content?.all.contains(where: { $0.id == grandPrixID }) == true else { return }
    selectedGrandPrixID = grandPrixID
  }

  private func request(policy: LoadPolicy) async {
    requestVersion += 1
    let version = requestVersion
    state.beginRequest()

    do {
      let schedule = try await repository.schedule(season: season, policy: policy)
      guard version == requestVersion else { return }
      let now = clock.now()
      let content = CalendarContent(season: season, schedule: schedule, now: now)
      state.finish(with: content, at: now)
      preserveOrChooseSelection(in: content)
    } catch {
      guard version == requestVersion else { return }
      state.fail(with: FeatureFailure(error: error))
    }
  }

  private func preserveOrChooseSelection(in content: CalendarContent) {
    if let selectedGrandPrixID,
      content.all.contains(where: { $0.id == selectedGrandPrixID })
    {
      return
    }
    selectedGrandPrixID = content.currentOrNextGrandPrixID ?? content.completed.last?.id
  }
}
