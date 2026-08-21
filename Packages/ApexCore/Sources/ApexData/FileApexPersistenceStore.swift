import ApexDomain
import Foundation

public actor FileApexPersistenceStore: ApexPersistenceStore {
  public static let schemaVersion = 1

  private let directory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL, fileManager: FileManager = .default) {
    self.directory = directory
    self.fileManager = fileManager
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
  }

  public func schedule(season: Int) throws -> [GrandPrix]? {
    try value([GrandPrix].self, for: .schedule(season))
  }

  public func saveSchedule(_ schedule: [GrandPrix], season: Int) throws {
    try save(schedule, for: .schedule(season))
  }

  public func sessions(grandPrixID: String) throws -> [RaceSession]? {
    try value([RaceSession].self, for: .sessions(grandPrixID))
  }

  public func saveSessions(_ sessions: [RaceSession], grandPrixID: String) throws {
    try save(sessions, for: .sessions(grandPrixID))
  }

  public func result(sessionID: String) throws -> SessionResult? {
    try value(SessionResult.self, for: .result(sessionID))
  }

  public func saveResult(_ result: SessionResult) throws {
    try save(result, for: .result(result.sessionID))
  }

  public func driverStandings(season: Int) throws -> [DriverStanding]? {
    try value([DriverStanding].self, for: .driverStandings(season))
  }

  public func saveDriverStandings(_ standings: [DriverStanding], season: Int) throws {
    try save(standings, for: .driverStandings(season))
  }

  public func teamStandings(season: Int) throws -> [TeamStanding]? {
    try value([TeamStanding].self, for: .teamStandings(season))
  }

  public func saveTeamStandings(_ standings: [TeamStanding], season: Int) throws {
    try save(standings, for: .teamStandings(season))
  }

  public func clearAll() throws {
    guard fileManager.fileExists(atPath: directory.path) else { return }
    do {
      let files = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      ).filter { $0.lastPathComponent.hasPrefix("apex-domain-") && $0.pathExtension == "json" }
      for file in files {
        try fileManager.removeItem(at: file)
      }
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  private func value<Value: Decodable>(_ type: Value.Type, for key: PersistenceKey) throws
    -> Value?
  {
    let url = fileURL(for: key)
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    do {
      let envelope = try decoder.decode(
        PersistentDomainEnvelope.self,
        from: Data(contentsOf: url)
      )
      guard envelope.schemaVersion == Self.schemaVersion, envelope.key == key.rawValue else {
        return nil
      }
      return try decoder.decode(type, from: envelope.payload)
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  private func save<Value: Encodable>(_ value: Value, for key: PersistenceKey) throws {
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      let envelope = PersistentDomainEnvelope(
        schemaVersion: Self.schemaVersion,
        key: key.rawValue,
        season: key.season,
        updatedAt: Date(),
        payload: try encoder.encode(value)
      )
      try encoder.encode(envelope).write(to: fileURL(for: key), options: .atomic)
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  private func fileURL(for key: PersistenceKey) -> URL {
    let safeKey = key.rawValue.replacingOccurrences(of: ":", with: "-")
    return directory.appendingPathComponent("apex-domain-\(safeKey).json")
  }
}

private struct PersistentDomainEnvelope: Codable {
  let schemaVersion: Int
  let key: String
  let season: Int?
  let updatedAt: Date
  let payload: Data
}
