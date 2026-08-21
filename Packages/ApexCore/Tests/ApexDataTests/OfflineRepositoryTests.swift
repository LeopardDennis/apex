import ApexData
import ApexDomain
import Foundation
import Testing

@Test
func offlineRepositoryReturnsLocalDataBeforeContactingRemote() async throws {
  let persistence = MemoryApexPersistenceStore()
  let remote = OfflineRemoteRepository()
  let repository = OfflineFirstApexRepository(remote: remote, persistence: persistence)
  let schedule = [sampleGrandPrix]
  try await persistence.saveSchedule(schedule, season: 2026)

  let cached = try await repository.schedule(season: 2026, policy: .cacheFirst)
  #expect(cached == schedule)
  let initialRequests = await remote.scheduleRequests
  #expect(initialRequests == 0)

  let fallback = try await repository.schedule(season: 2026, policy: .reloadIgnoringCache)
  #expect(fallback == schedule)
  let refreshRequests = await remote.scheduleRequests
  #expect(refreshRequests == 1)
}

private actor OfflineRemoteRepository: ApexDataRepository {
  private(set) var scheduleRequests = 0

  func schedule(season: Int, policy: LoadPolicy) throws -> [GrandPrix] {
    scheduleRequests += 1
    throw DataClientError.offline
  }

  func sessions(grandPrixID: String, policy: LoadPolicy) throws -> [RaceSession] {
    throw DataClientError.offline
  }

  func result(sessionID: String, policy: LoadPolicy) throws -> SessionResult? {
    throw DataClientError.offline
  }

  func driverStandings(season: Int, policy: LoadPolicy) throws -> [DriverStanding] {
    throw DataClientError.offline
  }

  func teamStandings(season: Int, policy: LoadPolicy) throws -> [TeamStanding] {
    throw DataClientError.offline
  }

  func seasonHistory(
    season: Int,
    subject: SeasonHistorySubject,
    policy: LoadPolicy
  ) throws -> SeasonHistory {
    throw DataClientError.offline
  }
}

private let sampleGrandPrix = GrandPrix(
  season: 2026,
  round: 1,
  meetingKey: 1,
  meetingName: "Australian Grand Prix",
  localizedGrandPrixName: "澳大利亚大奖赛",
  circuitKey: 10,
  circuitName: "Albert Park Grand Prix Circuit",
  localizedCircuitName: "阿尔伯特公园赛道",
  countryCode: "AUS",
  location: "Melbourne",
  dateStart: Date(timeIntervalSince1970: 100),
  dateEnd: Date(timeIntervalSince1970: 200),
  trackAssetID: "circuit-10",
  geometryStatus: .available
)
