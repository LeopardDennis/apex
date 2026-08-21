import ApexDomain
import Foundation

public enum LoadPolicy: Equatable, Sendable {
  case cacheFirst
  case reloadIgnoringCache
}

public protocol ScheduleRepository: Sendable {
  func schedule(season: Int, policy: LoadPolicy) async throws -> [GrandPrix]
  func sessions(grandPrixID: String, policy: LoadPolicy) async throws -> [RaceSession]
}

public protocol ResultsRepository: Sendable {
  func result(sessionID: String, policy: LoadPolicy) async throws -> SessionResult?
}

public protocol StandingsRepository: Sendable {
  func driverStandings(season: Int, policy: LoadPolicy) async throws -> [DriverStanding]
  func teamStandings(season: Int, policy: LoadPolicy) async throws -> [TeamStanding]
}

public protocol HTTPTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
