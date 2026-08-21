import ApexData
import ApexDomain
import ApexResources
import Foundation
import Testing

@Test
func filePersistenceRoundTripsDomainSnapshots() async throws {
  let directory = temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = FileApexPersistenceStore(directory: directory)
  let catalog = try persistenceCatalog()
  let schedule = Array(catalog.grandPrix.prefix(2))
  let driverStandings = [
    DriverStanding(
      position: 1,
      driverID: "antonelli",
      teamID: "mercedes",
      points: 25,
      wins: 1
    )
  ]

  try await store.saveSchedule(schedule, season: 2026)
  try await store.saveDriverStandings(driverStandings, season: 2026)

  #expect(try await store.schedule(season: 2026) == schedule)
  #expect(try await store.driverStandings(season: 2026) == driverStandings)

  try await store.clearAll()
  #expect(try await store.schedule(season: 2026) == nil)
}

@Test
func widgetSnapshotContainsLocalizedLeaderAndTeamTheme() throws {
  let catalog = try persistenceCatalog()
  let grandPrix = try #require(catalog.grandPrix.first)
  let sessions = [
    RaceSession(
      grandPrixID: grandPrix.id,
      kind: .practice1,
      dateStart: grandPrix.dateStart,
      dateEnd: grandPrix.dateStart.addingTimeInterval(3_600),
      state: .scheduled
    )
  ]
  let snapshot = WidgetSnapshotBuilder().makeSnapshot(
    schedule: catalog.grandPrix,
    sessions: sessions,
    driverStandings: [
      DriverStanding(
        position: 1,
        driverID: "antonelli",
        teamID: "mercedes",
        points: 25,
        wins: 1
      )
    ],
    teamStandings: [
      TeamStanding(position: 1, teamID: "mercedes", points: 43, wins: 1)
    ],
    catalog: catalog,
    at: grandPrix.dateStart.addingTimeInterval(-60)
  )

  #expect(snapshot.nextGrandPrix?.localizedGrandPrixName == "澳大利亚大奖赛")
  #expect(snapshot.sessions.map(\.kind) == [.practice1])
  #expect(snapshot.driverLeader?.localizedName == "安德烈亚·基米·安东内利")
  #expect(snapshot.driverLeader?.localizedTeamName == "梅赛德斯车队")
  #expect(snapshot.driverLeader?.primaryColor == "#00D7B6")
  #expect(snapshot.teamLeader?.primaryColor == "#00D7B6")
}

@Test
func widgetSnapshotFileIsSharedAsVersionedJSON() async throws {
  let directory = temporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let store = FileWidgetSnapshotStore(directory: directory)
  let snapshot = ApexWidgetSnapshot(
    season: 2026,
    generatedAt: Date(timeIntervalSince1970: 123),
    nextGrandPrix: nil,
    sessions: [],
    driverLeader: nil,
    teamLeader: nil
  )

  try await store.saveSnapshot(snapshot)
  #expect(try await store.snapshot() == snapshot)

  try await store.removeSnapshot()
  #expect(try await store.snapshot() == nil)
}

private func persistenceCatalog() throws -> SeasonResourceCatalog {
  let resources = persistenceRepositoryRoot.appendingPathComponent("Resources/Seed/2026")
  return try ResourceDecoder().decodeCatalog(
    circuits: Data(contentsOf: resources.appendingPathComponent("circuits.json")),
    drivers: Data(contentsOf: resources.appendingPathComponent("drivers.json")),
    teams: Data(contentsOf: resources.appendingPathComponent("teams.json"))
  )
}

private var persistenceRepositoryRoot: URL {
  var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  for _ in 0..<4 {
    directory.deleteLastPathComponent()
  }
  return directory
}

private func temporaryDirectory() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}
