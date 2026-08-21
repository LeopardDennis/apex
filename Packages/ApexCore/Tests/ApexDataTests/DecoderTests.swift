import ApexData
import ApexResources
import Foundation
import Testing

@Test
func jolpicaMapsRemoteIdentifiersOntoLocalizedCatalog() throws {
  let catalog = try loadCatalog()
  let decoder = JolpicaDecoder()
  let result = try #require(
    decoder.raceResult(
      from: fixture("jolpica-race-results"),
      sessionID: "2026-01-race",
      catalog: catalog
    )
  )

  #expect(result.entries.count == 2)
  #expect(result.entries[0].driverID == "antonelli")
  #expect(result.entries[0].teamID == "mercedes")
  #expect(result.entries[0].hasFastestLap)
  #expect(
    catalog.drivers.first { $0.id == result.entries[0].driverID }?.localizedName == "安德烈亚·基米·安东内利")

  let drivers = try decoder.driverStandings(
    from: fixture("jolpica-driver-standings"),
    catalog: catalog
  )
  let teams = try decoder.teamStandings(
    from: fixture("jolpica-team-standings"),
    catalog: catalog
  )
  #expect(
    drivers == [
      DriverStanding(position: 1, driverID: "antonelli", teamID: "mercedes", points: 25, wins: 1)
    ])
  #expect(teams == [TeamStanding(position: 1, teamID: "mercedes", points: 43, wins: 1)])
}

@Test
func openF1MapsMeetingsSessionsAndPracticeResults() throws {
  let catalog = try loadCatalog()
  let decoder = OpenF1Decoder()
  let schedule = try decoder.schedule(from: fixture("openf1-meetings"), catalog: catalog)
  let australianGrandPrix = try #require(schedule.first)

  #expect(australianGrandPrix.localizedGrandPrixName == "澳大利亚大奖赛")
  #expect(australianGrandPrix.trackAssetID == "circuit-10")

  let sessions = try decoder.sessions(
    from: fixture("openf1-sessions"),
    grandPrix: australianGrandPrix,
    now: Date(timeIntervalSince1970: 0)
  )
  #expect(sessions.map(\.session.kind) == [.practice1, .race])
  #expect(sessions.map(\.sessionKey) == [10_261, 10_265])

  let result = try decoder.result(
    from: fixture("openf1-session-result"),
    driversData: fixture("openf1-drivers"),
    sessionID: "2026-01-practice1",
    catalog: catalog
  )
  #expect(result.entries.map(\.driverID) == ["antonelli", "leclerc"])
  #expect(result.entries.map(\.teamID) == ["mercedes", "ferrari"])
  #expect(result.entries[1].gap == "+4.201")
}

private func fixture(_ name: String) throws -> Data {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  return try Data(contentsOf: url)
}

private func loadCatalog() throws -> SeasonResourceCatalog {
  let resources = repositoryRoot.appendingPathComponent("Resources/Seed/2026")
  return try ResourceDecoder().decodeCatalog(
    circuits: Data(contentsOf: resources.appendingPathComponent("circuits.json")),
    drivers: Data(contentsOf: resources.appendingPathComponent("drivers.json")),
    teams: Data(contentsOf: resources.appendingPathComponent("teams.json"))
  )
}

private var repositoryRoot: URL {
  var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  for _ in 0..<4 {
    directory.deleteLastPathComponent()
  }
  return directory
}
