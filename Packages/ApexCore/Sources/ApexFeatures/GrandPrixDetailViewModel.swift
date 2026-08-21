import ApexData
import ApexDomain
import Combine
import Foundation

public struct SessionListItem: Equatable, Identifiable, Sendable {
  public let session: RaceSession
  public let isNext: Bool

  public var id: String { session.id }

  public init(session: RaceSession, isNext: Bool) {
    self.session = session
    self.isNext = isNext
  }
}

public struct GrandPrixDetailContent: Equatable, Sendable {
  public let grandPrix: GrandPrix
  public let trackAsset: TrackAsset?
  public let sessions: [SessionListItem]
  public let countdown: Countdown?

  public init(
    grandPrix: GrandPrix,
    trackAsset: TrackAsset?,
    sessions: [RaceSession],
    now: Date
  ) {
    let sortedSessions = sessions.sorted { $0.dateStart < $1.dateStart }
    let nextSession = ScheduleClock.nextSession(in: sortedSessions, at: now)
    self.grandPrix = grandPrix
    self.trackAsset = trackAsset
    self.sessions = sortedSessions.map {
      SessionListItem(session: $0, isNext: $0.id == nextSession?.id)
    }
    self.countdown = nextSession.map { ScheduleClock.countdown(to: $0.dateStart, from: now) }
  }

  public var nextSession: RaceSession? { sessions.first(where: \.isNext)?.session }
}

@MainActor
public final class GrandPrixDetailViewModel: ObservableObject {
  @Published public private(set) var state: FeatureState<GrandPrixDetailContent>

  private let grandPrix: GrandPrix
  private let trackAsset: TrackAsset?
  private let repository: any ScheduleRepository
  private let clock: any FeatureClock
  private var requestVersion = 0

  public init(
    grandPrix: GrandPrix,
    trackAsset: TrackAsset? = nil,
    repository: any ScheduleRepository,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.grandPrix = grandPrix
    self.trackAsset = trackAsset
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
      let sessions = try await repository.sessions(grandPrixID: grandPrix.id, policy: policy)
      guard version == requestVersion else { return }
      let now = clock.now()
      state.finish(
        with: GrandPrixDetailContent(
          grandPrix: grandPrix,
          trackAsset: trackAsset,
          sessions: sessions,
          now: now
        ),
        at: now
      )
    } catch {
      guard version == requestVersion else { return }
      state.fail(with: FeatureFailure(error: error))
    }
  }
}
