import ApexData
import ApexDomain
import Foundation
import SwiftData

@Model
final class ApexSnapshotRecord {
  @Attribute(.unique) var key: String
  var schemaVersion: Int
  var season: Int?
  var updatedAt: Date
  var payload: Data

  init(
    key: String,
    schemaVersion: Int = 1,
    season: Int?,
    updatedAt: Date,
    payload: Data
  ) {
    self.key = key
    self.schemaVersion = schemaVersion
    self.season = season
    self.updatedAt = updatedAt
    self.payload = payload
  }
}

/// Add this file to the Apex App target after creating the Xcode project.
/// The type conforms to the same protocol as the file-backed implementation,
/// so feature code and repositories do not change when SwiftData is enabled.
actor SwiftDataApexPersistenceStore: ApexPersistenceStore {
  static let schemaVersion = 1

  private let context: ModelContext
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(container: ModelContainer) {
    self.context = ModelContext(container)
  }

  static func make(isStoredInMemoryOnly: Bool = false) throws -> SwiftDataApexPersistenceStore {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
    let container = try ModelContainer(
      for: ApexSnapshotRecord.self,
      configurations: configuration
    )
    return SwiftDataApexPersistenceStore(container: container)
  }

  func schedule(season: Int) throws -> [GrandPrix]? {
    try value([GrandPrix].self, for: "schedule:\(season)")
  }

  func saveSchedule(_ schedule: [GrandPrix], season: Int) throws {
    try save(schedule, key: "schedule:\(season)", season: season)
  }

  func sessions(grandPrixID: String) throws -> [RaceSession]? {
    try value([RaceSession].self, for: "sessions:\(grandPrixID)")
  }

  func saveSessions(_ sessions: [RaceSession], grandPrixID: String) throws {
    try save(sessions, key: "sessions:\(grandPrixID)", season: Int(grandPrixID.prefix(4)))
  }

  func result(sessionID: String) throws -> SessionResult? {
    try value(SessionResult.self, for: "result:\(sessionID)")
  }

  func saveResult(_ result: SessionResult) throws {
    try save(
      result,
      key: "result:\(result.sessionID)",
      season: Int(result.sessionID.prefix(4))
    )
  }

  func driverStandings(season: Int) throws -> [DriverStanding]? {
    try value([DriverStanding].self, for: "driver-standings:\(season)")
  }

  func saveDriverStandings(_ standings: [DriverStanding], season: Int) throws {
    try save(standings, key: "driver-standings:\(season)", season: season)
  }

  func teamStandings(season: Int) throws -> [TeamStanding]? {
    try value([TeamStanding].self, for: "team-standings:\(season)")
  }

  func saveTeamStandings(_ standings: [TeamStanding], season: Int) throws {
    try save(standings, key: "team-standings:\(season)", season: season)
  }

  func clearAll() throws {
    for record in try records() {
      context.delete(record)
    }
    try context.save()
  }

  private func value<Value: Decodable>(_ type: Value.Type, for key: String) throws -> Value? {
    guard let record = try records().first(where: { $0.key == key }),
      record.schemaVersion == Self.schemaVersion
    else { return nil }
    return try decoder.decode(type, from: record.payload)
  }

  private func save<Value: Encodable>(_ value: Value, key: String, season: Int?) throws {
    let payload = try encoder.encode(value)
    if let existing = try records().first(where: { $0.key == key }) {
      existing.schemaVersion = Self.schemaVersion
      existing.season = season
      existing.updatedAt = Date()
      existing.payload = payload
    } else {
      context.insert(
        ApexSnapshotRecord(
          key: key,
          schemaVersion: Self.schemaVersion,
          season: season,
          updatedAt: Date(),
          payload: payload
        ))
    }
    try context.save()
  }

  private func records() throws -> [ApexSnapshotRecord] {
    try context.fetch(FetchDescriptor<ApexSnapshotRecord>())
  }
}
