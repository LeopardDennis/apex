import ApexDomain
import Foundation

public protocol ApexPersistenceStore: Sendable {
  func schedule(season: Int) async throws -> [GrandPrix]?
  func saveSchedule(_ schedule: [GrandPrix], season: Int) async throws

  func sessions(grandPrixID: String) async throws -> [RaceSession]?
  func saveSessions(_ sessions: [RaceSession], grandPrixID: String) async throws

  func result(sessionID: String) async throws -> SessionResult?
  func saveResult(_ result: SessionResult) async throws

  func driverStandings(season: Int) async throws -> [DriverStanding]?
  func saveDriverStandings(_ standings: [DriverStanding], season: Int) async throws

  func teamStandings(season: Int) async throws -> [TeamStanding]?
  func saveTeamStandings(_ standings: [TeamStanding], season: Int) async throws

  func clearAll() async throws
}

public actor MemoryApexPersistenceStore: ApexPersistenceStore {
  private var values: [String: Data] = [:]
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init() {}

  public func schedule(season: Int) throws -> [GrandPrix]? {
    try value([GrandPrix].self, for: PersistenceKey.schedule(season).rawValue)
  }

  public func saveSchedule(_ schedule: [GrandPrix], season: Int) throws {
    try save(schedule, for: PersistenceKey.schedule(season).rawValue)
  }

  public func sessions(grandPrixID: String) throws -> [RaceSession]? {
    try value([RaceSession].self, for: PersistenceKey.sessions(grandPrixID).rawValue)
  }

  public func saveSessions(_ sessions: [RaceSession], grandPrixID: String) throws {
    try save(sessions, for: PersistenceKey.sessions(grandPrixID).rawValue)
  }

  public func result(sessionID: String) throws -> SessionResult? {
    try value(SessionResult.self, for: PersistenceKey.result(sessionID).rawValue)
  }

  public func saveResult(_ result: SessionResult) throws {
    try save(result, for: PersistenceKey.result(result.sessionID).rawValue)
  }

  public func driverStandings(season: Int) throws -> [DriverStanding]? {
    try value([DriverStanding].self, for: PersistenceKey.driverStandings(season).rawValue)
  }

  public func saveDriverStandings(_ standings: [DriverStanding], season: Int) throws {
    try save(standings, for: PersistenceKey.driverStandings(season).rawValue)
  }

  public func teamStandings(season: Int) throws -> [TeamStanding]? {
    try value([TeamStanding].self, for: PersistenceKey.teamStandings(season).rawValue)
  }

  public func saveTeamStandings(_ standings: [TeamStanding], season: Int) throws {
    try save(standings, for: PersistenceKey.teamStandings(season).rawValue)
  }

  public func clearAll() {
    values.removeAll()
  }

  private func value<Value: Decodable>(_ type: Value.Type, for key: String) throws -> Value? {
    guard let data = values[key] else { return nil }
    do {
      return try decoder.decode(type, from: data)
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }

  private func save<Value: Encodable>(_ value: Value, for key: String) throws {
    do {
      values[key] = try encoder.encode(value)
    } catch {
      throw DataClientError.cacheIO(String(describing: error))
    }
  }
}

enum PersistenceKey: Equatable, Sendable {
  case schedule(Int)
  case sessions(String)
  case result(String)
  case driverStandings(Int)
  case teamStandings(Int)

  var rawValue: String {
    switch self {
    case .schedule(let season):
      "schedule:\(season)"
    case .sessions(let grandPrixID):
      "sessions:\(grandPrixID)"
    case .result(let sessionID):
      "result:\(sessionID)"
    case .driverStandings(let season):
      "driver-standings:\(season)"
    case .teamStandings(let season):
      "team-standings:\(season)"
    }
  }

  var season: Int? {
    switch self {
    case .schedule(let season), .driverStandings(let season), .teamStandings(let season):
      season
    case .sessions(let identifier), .result(let identifier):
      Int(identifier.prefix(4))
    }
  }
}
