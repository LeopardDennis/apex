import Foundation

public struct ApexWidgetSnapshot: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let season: Int
  public let generatedAt: Date
  public let nextGrandPrix: WidgetGrandPrixSnapshot?
  public let sessions: [WidgetSessionSnapshot]
  public let driverLeader: WidgetDriverLeaderSnapshot?
  public let teamLeader: WidgetTeamLeaderSnapshot?

  public init(
    schemaVersion: Int = 1,
    season: Int,
    generatedAt: Date,
    nextGrandPrix: WidgetGrandPrixSnapshot?,
    sessions: [WidgetSessionSnapshot],
    driverLeader: WidgetDriverLeaderSnapshot?,
    teamLeader: WidgetTeamLeaderSnapshot?
  ) {
    self.schemaVersion = schemaVersion
    self.season = season
    self.generatedAt = generatedAt
    self.nextGrandPrix = nextGrandPrix
    self.sessions = sessions
    self.driverLeader = driverLeader
    self.teamLeader = teamLeader
  }
}

public struct WidgetGrandPrixSnapshot: Codable, Equatable, Sendable {
  public let id: String
  public let round: Int
  public let localizedGrandPrixName: String
  public let localizedCircuitName: String
  public let location: String
  public let countryCode: String
  public let dateStart: Date
  public let dateEnd: Date
  public let trackAssetID: String

  public init(
    id: String,
    round: Int,
    localizedGrandPrixName: String,
    localizedCircuitName: String,
    location: String,
    countryCode: String,
    dateStart: Date,
    dateEnd: Date,
    trackAssetID: String
  ) {
    self.id = id
    self.round = round
    self.localizedGrandPrixName = localizedGrandPrixName
    self.localizedCircuitName = localizedCircuitName
    self.location = location
    self.countryCode = countryCode
    self.dateStart = dateStart
    self.dateEnd = dateEnd
    self.trackAssetID = trackAssetID
  }
}

public struct WidgetSessionSnapshot: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let kind: SessionKind
  public let dateStart: Date
  public let dateEnd: Date
  public let state: SessionState

  public init(
    id: String,
    kind: SessionKind,
    dateStart: Date,
    dateEnd: Date,
    state: SessionState
  ) {
    self.id = id
    self.kind = kind
    self.dateStart = dateStart
    self.dateEnd = dateEnd
    self.state = state
  }
}

public struct WidgetDriverLeaderSnapshot: Codable, Equatable, Sendable {
  public let driverID: String
  public let code: String
  public let localizedName: String
  public let number: Int
  public let position: Int
  public let points: Double
  public let wins: Int
  public let teamID: String
  public let localizedTeamName: String
  public let primaryColor: String
  public let onPrimaryColor: String

  public init(
    driverID: String,
    code: String,
    localizedName: String,
    number: Int,
    position: Int,
    points: Double,
    wins: Int,
    teamID: String,
    localizedTeamName: String,
    primaryColor: String,
    onPrimaryColor: String
  ) {
    self.driverID = driverID
    self.code = code
    self.localizedName = localizedName
    self.number = number
    self.position = position
    self.points = points
    self.wins = wins
    self.teamID = teamID
    self.localizedTeamName = localizedTeamName
    self.primaryColor = primaryColor
    self.onPrimaryColor = onPrimaryColor
  }
}

public struct WidgetTeamLeaderSnapshot: Codable, Equatable, Sendable {
  public let teamID: String
  public let localizedName: String
  public let position: Int
  public let points: Double
  public let wins: Int
  public let primaryColor: String
  public let onPrimaryColor: String

  public init(
    teamID: String,
    localizedName: String,
    position: Int,
    points: Double,
    wins: Int,
    primaryColor: String,
    onPrimaryColor: String
  ) {
    self.teamID = teamID
    self.localizedName = localizedName
    self.position = position
    self.points = points
    self.wins = wins
    self.primaryColor = primaryColor
    self.onPrimaryColor = onPrimaryColor
  }
}
