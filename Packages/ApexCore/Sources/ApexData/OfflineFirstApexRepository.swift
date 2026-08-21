import ApexDomain
import Foundation

public actor OfflineFirstApexRepository: ApexDataRepository {
  private let remote: any ApexDataRepository
  private let persistence: any ApexPersistenceStore

  public init(
    remote: any ApexDataRepository,
    persistence: any ApexPersistenceStore
  ) {
    self.remote = remote
    self.persistence = persistence
  }

  public func schedule(season: Int, policy: LoadPolicy) async throws -> [GrandPrix] {
    let cached = try? await persistence.schedule(season: season)
    if policy == .cacheFirst, let cached { return cached }
    do {
      let value = try await remote.schedule(season: season, policy: policy)
      try? await persistence.saveSchedule(value, season: season)
      return value
    } catch {
      if let cached { return cached }
      throw error
    }
  }

  public func sessions(grandPrixID: String, policy: LoadPolicy) async throws -> [RaceSession] {
    let cached = try? await persistence.sessions(grandPrixID: grandPrixID)
    if policy == .cacheFirst, let cached { return cached }
    do {
      let value = try await remote.sessions(grandPrixID: grandPrixID, policy: policy)
      try? await persistence.saveSessions(value, grandPrixID: grandPrixID)
      return value
    } catch {
      if let cached { return cached }
      throw error
    }
  }

  public func result(sessionID: String, policy: LoadPolicy) async throws -> SessionResult? {
    let cached = try? await persistence.result(sessionID: sessionID)
    if policy == .cacheFirst, let cached { return cached }
    do {
      let value = try await remote.result(sessionID: sessionID, policy: policy)
      if let value {
        try? await persistence.saveResult(value)
        return value
      }
      return cached
    } catch {
      if let cached { return cached }
      throw error
    }
  }

  public func driverStandings(season: Int, policy: LoadPolicy) async throws -> [DriverStanding] {
    let cached = try? await persistence.driverStandings(season: season)
    if policy == .cacheFirst, let cached { return cached }
    do {
      let value = try await remote.driverStandings(season: season, policy: policy)
      try? await persistence.saveDriverStandings(value, season: season)
      return value
    } catch {
      if let cached { return cached }
      throw error
    }
  }

  public func teamStandings(season: Int, policy: LoadPolicy) async throws -> [TeamStanding] {
    let cached = try? await persistence.teamStandings(season: season)
    if policy == .cacheFirst, let cached { return cached }
    do {
      let value = try await remote.teamStandings(season: season, policy: policy)
      try? await persistence.saveTeamStandings(value, season: season)
      return value
    } catch {
      if let cached { return cached }
      throw error
    }
  }

  public func seasonHistory(
    season: Int,
    subject: SeasonHistorySubject,
    policy: LoadPolicy
  ) async throws -> SeasonHistory {
    let cached = try? await persistence.seasonHistory(season: season, subject: subject)
    if policy == .cacheFirst, let cached { return cached }
    do {
      let value = try await remote.seasonHistory(
        season: season,
        subject: subject,
        policy: policy
      )
      try? await persistence.saveSeasonHistory(value)
      return value
    } catch {
      if let cached { return cached }
      throw error
    }
  }
}
