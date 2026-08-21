import Foundation

public enum GeometryStatus: String, Codable, Sendable {
  case available
  case pendingManual
}

public struct Team: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let localizedName: String
  public let nationality: String
  public let primaryColor: String
  public let onPrimaryColor: String

  public init(
    id: String,
    name: String,
    localizedName: String,
    nationality: String,
    primaryColor: String,
    onPrimaryColor: String
  ) {
    self.id = id
    self.name = name
    self.localizedName = localizedName
    self.nationality = nationality
    self.primaryColor = primaryColor
    self.onPrimaryColor = onPrimaryColor
  }
}

public struct Driver: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let number: Int
  public let code: String
  public let name: String
  public let localizedName: String
  public let teamID: String
  public let nationality: String

  public init(
    id: String,
    number: Int,
    code: String,
    name: String,
    localizedName: String,
    teamID: String,
    nationality: String
  ) {
    self.id = id
    self.number = number
    self.code = code
    self.name = name
    self.localizedName = localizedName
    self.teamID = teamID
    self.nationality = nationality
  }
}

public struct GrandPrix: Codable, Equatable, Identifiable, Sendable {
  public let season: Int
  public let round: Int
  public let meetingKey: Int
  public let meetingName: String
  public let localizedGrandPrixName: String
  public let circuitKey: Int
  public let circuitName: String
  public let localizedCircuitName: String
  public let countryCode: String
  public let sourceCountryCode: String?
  public let location: String
  public let dateStart: Date
  public let dateEnd: Date
  public let trackAssetID: String
  public let geometryStatus: GeometryStatus

  public var id: String {
    let roundComponent = round < 10 ? "0\(round)" : "\(round)"
    return "\(season)-\(roundComponent)"
  }

  public init(
    season: Int,
    round: Int,
    meetingKey: Int,
    meetingName: String,
    localizedGrandPrixName: String,
    circuitKey: Int,
    circuitName: String,
    localizedCircuitName: String,
    countryCode: String,
    sourceCountryCode: String? = nil,
    location: String,
    dateStart: Date,
    dateEnd: Date,
    trackAssetID: String,
    geometryStatus: GeometryStatus
  ) {
    self.season = season
    self.round = round
    self.meetingKey = meetingKey
    self.meetingName = meetingName
    self.localizedGrandPrixName = localizedGrandPrixName
    self.circuitKey = circuitKey
    self.circuitName = circuitName
    self.localizedCircuitName = localizedCircuitName
    self.countryCode = countryCode
    self.sourceCountryCode = sourceCountryCode
    self.location = location
    self.dateStart = dateStart
    self.dateEnd = dateEnd
    self.trackAssetID = trackAssetID
    self.geometryStatus = geometryStatus
  }
}

public enum SessionKind: String, Codable, CaseIterable, Sendable {
  case practice1
  case practice2
  case practice3
  case sprintQualifying
  case sprint
  case qualifying
  case race
}

public enum SessionState: String, Codable, Sendable {
  case scheduled
  case completed
  case cancelled
  case resultPending
  case resultAvailable
}

public struct RaceSession: Codable, Equatable, Identifiable, Sendable {
  public let grandPrixID: String
  public let kind: SessionKind
  public let dateStart: Date
  public let dateEnd: Date
  public let state: SessionState

  public var id: String { "\(grandPrixID)-\(kind.rawValue)" }

  public init(
    grandPrixID: String,
    kind: SessionKind,
    dateStart: Date,
    dateEnd: Date,
    state: SessionState
  ) {
    self.grandPrixID = grandPrixID
    self.kind = kind
    self.dateStart = dateStart
    self.dateEnd = dateEnd
    self.state = state
  }
}

public struct SessionResultEntry: Codable, Equatable, Identifiable, Sendable {
  public let position: Int?
  public let driverID: String
  public let teamID: String
  public let laps: Int?
  public let time: String?
  public let gap: String?
  public let points: Double?
  public let hasFastestLap: Bool
  public let status: String?

  public var id: String { driverID }

  public init(
    position: Int?,
    driverID: String,
    teamID: String,
    laps: Int? = nil,
    time: String? = nil,
    gap: String? = nil,
    points: Double? = nil,
    hasFastestLap: Bool = false,
    status: String? = nil
  ) {
    self.position = position
    self.driverID = driverID
    self.teamID = teamID
    self.laps = laps
    self.time = time
    self.gap = gap
    self.points = points
    self.hasFastestLap = hasFastestLap
    self.status = status
  }
}

public struct SessionResult: Codable, Equatable, Sendable {
  public let sessionID: String
  public let entries: [SessionResultEntry]
  public let updatedAt: Date

  public init(sessionID: String, entries: [SessionResultEntry], updatedAt: Date) {
    self.sessionID = sessionID
    self.entries = entries
    self.updatedAt = updatedAt
  }
}

public struct DriverStanding: Codable, Equatable, Identifiable, Sendable {
  public let position: Int
  public let driverID: String
  public let teamID: String
  public let points: Double
  public let wins: Int

  public var id: String { driverID }

  public init(position: Int, driverID: String, teamID: String, points: Double, wins: Int) {
    self.position = position
    self.driverID = driverID
    self.teamID = teamID
    self.points = points
    self.wins = wins
  }
}

public struct TeamStanding: Codable, Equatable, Identifiable, Sendable {
  public let position: Int
  public let teamID: String
  public let points: Double
  public let wins: Int

  public var id: String { teamID }

  public init(position: Int, teamID: String, points: Double, wins: Int) {
    self.position = position
    self.teamID = teamID
    self.points = points
    self.wins = wins
  }
}
