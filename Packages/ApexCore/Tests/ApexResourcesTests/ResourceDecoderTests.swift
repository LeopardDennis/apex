import ApexResources
import Foundation
import Testing

@Test
func decodesTheCheckedIn2026Catalog() throws {
  let resources = repositoryRoot.appendingPathComponent("Resources")
  let catalog = try ResourceDecoder().decodeCatalog(
    circuits: Data(
      contentsOf: resources.appendingPathComponent("Seed/2026/circuits.json")
    ),
    drivers: Data(
      contentsOf: resources.appendingPathComponent("Seed/2026/drivers.json")
    ),
    teams: Data(
      contentsOf: resources.appendingPathComponent("Seed/2026/teams.json")
    )
  )

  #expect(catalog.season == 2026)
  #expect(catalog.grandPrix.count == 23)
  #expect(catalog.drivers.count == 22)
  #expect(catalog.teams.count == 11)
  #expect(catalog.grandPrix.map(\.round) == Array(1...23))
  #expect(catalog.grandPrix.allSatisfy { $0.geometryStatus == .available })
  #expect(catalog.drivers.allSatisfy { !$0.localizedName.isEmpty })
  #expect(catalog.teams.allSatisfy { !$0.localizedName.isEmpty })

  let replacement = try #require(catalog.grandPrix.first { $0.circuitKey == 12 })
  #expect(replacement.countryCode == "MYS")
  #expect(replacement.sourceCountryCode == "BRN")
  #expect(replacement.localizedCircuitName == "雪邦国际赛道")
}

@Test
func decodesAndValidatesEveryCheckedInTrack() throws {
  let directory = repositoryRoot.appendingPathComponent("Resources/Tracks/2026")
  let files = try FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil
  ).filter { $0.pathExtension == "json" }

  let assets = try files.map {
    try ResourceDecoder().decodeTrackAsset(from: Data(contentsOf: $0))
  }

  #expect(assets.count == 23)
  #expect(Set(assets.map(\.trackAssetID)).count == 23)
  #expect(assets.allSatisfy { !$0.pathPoints.isEmpty && !$0.corners.isEmpty })

  let madring = try #require(assets.first { $0.trackAssetID == "circuit-153" })
  let sepang = try #require(assets.first { $0.trackAssetID == "circuit-12" })
  #expect(madring.corners.count == 22)
  #expect(sepang.corners.count == 15)
  #expect(!sepang.pitLanePath.isEmpty)
}

private var repositoryRoot: URL {
  var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  for _ in 0..<4 {
    directory.deleteLastPathComponent()
  }
  return directory
}
