import ApexDomain
import Foundation

public struct SeasonResourceCatalog: Equatable, Sendable {
  public let season: Int
  public let grandPrix: [GrandPrix]
  public let drivers: [Driver]
  public let teams: [Team]

  public init(season: Int, grandPrix: [GrandPrix], drivers: [Driver], teams: [Team]) {
    self.season = season
    self.grandPrix = grandPrix
    self.drivers = drivers
    self.teams = teams
  }
}

public enum ResourceError: Error, Equatable, LocalizedError, Sendable {
  case unsupportedSchema(Int)
  case seasonMismatch
  case duplicateIdentifier(String)
  case invalidSchedule
  case unknownTeam(driverID: String, teamID: String)
  case invalidTrackAsset(String)

  public var errorDescription: String? {
    switch self {
    case .unsupportedSchema(let version):
      "Unsupported Apex resource schema version: \(version)."
    case .seasonMismatch:
      "The seed resources do not describe the same season."
    case .duplicateIdentifier(let identifier):
      "The resource contains a duplicate identifier: \(identifier)."
    case .invalidSchedule:
      "The schedule rounds or dates are invalid."
    case .unknownTeam(let driverID, let teamID):
      "Driver \(driverID) references unknown team \(teamID)."
    case .invalidTrackAsset(let identifier):
      "Track asset \(identifier) is incomplete or outside its normalized canvas."
    }
  }
}

public struct ResourceDecoder: Sendable {
  public init() {}

  public func decodeCatalog(circuits: Data, drivers: Data, teams: Data) throws
    -> SeasonResourceCatalog
  {
    let decoder = makeDecoder()
    let circuitFile = try decoder.decode(CircuitFile.self, from: circuits)
    let driverFile = try decoder.decode(DriverFile.self, from: drivers)
    let teamFile = try decoder.decode(TeamFile.self, from: teams)

    for version in [circuitFile.schemaVersion, driverFile.schemaVersion, teamFile.schemaVersion]
    where version != 1 {
      throw ResourceError.unsupportedSchema(version)
    }
    guard circuitFile.season == driverFile.season, circuitFile.season == teamFile.season else {
      throw ResourceError.seasonMismatch
    }

    let decodedTeams = teamFile.teams.map(Team.init)
    try requireUnique(decodedTeams.map(\.id))
    let teamIDs = Set(decodedTeams.map(\.id))

    let decodedDrivers = driverFile.drivers.map(Driver.init)
    try requireUnique(decodedDrivers.map(\.id))
    for driver in decodedDrivers where !teamIDs.contains(driver.teamID) {
      throw ResourceError.unknownTeam(driverID: driver.id, teamID: driver.teamID)
    }

    let decodedGrandPrix = circuitFile.circuits
      .map { GrandPrix(season: circuitFile.season, dto: $0) }
      .sorted { $0.round < $1.round }
    try requireUnique(decodedGrandPrix.map(\.id))
    let expectedRounds = Array(1...decodedGrandPrix.count)
    guard decodedGrandPrix.map(\.round) == expectedRounds,
      decodedGrandPrix.allSatisfy({ $0.dateStart < $0.dateEnd })
    else {
      throw ResourceError.invalidSchedule
    }

    return SeasonResourceCatalog(
      season: circuitFile.season,
      grandPrix: decodedGrandPrix,
      drivers: decodedDrivers,
      teams: decodedTeams
    )
  }

  public func decodeTrackAsset(from data: Data) throws -> TrackAsset {
    let asset = try makeDecoder().decode(TrackAsset.self, from: data)
    guard asset.schemaVersion == 1 else {
      throw ResourceError.unsupportedSchema(asset.schemaVersion)
    }
    let cornerNumbers = Set(asset.corners.map(\.number))
    let expectedCornerNumbers: Set<Int>
    if let finalCorner = cornerNumbers.max(), finalCorner > 0 {
      expectedCornerNumbers = Set(1...finalCorner)
    } else {
      expectedCornerNumbers = []
    }
    guard asset.geometryStatus == .available,
      asset.pathPoints.count > 10,
      !asset.corners.isEmpty,
      cornerNumbers == expectedCornerNumbers,
      asset.pathPoints.allSatisfy(\.isNormalized),
      asset.corners.map(\.point).allSatisfy(\.isNormalized),
      asset.pitLanePath.allSatisfy(\.isNormalized),
      [asset.startFinishMarker, asset.directionMarker].compactMap({ $0 }).allSatisfy(
        \.isNormalized),
      asset.viewBox.width > 0,
      asset.viewBox.height > 0,
      asset.rendering.stroke == .singleColor,
      asset.rendering.showsCornerNumbers,
      !asset.rendering.showsSegmentColors
    else {
      throw ResourceError.invalidTrackAsset(asset.trackAssetID)
    }
    return asset
  }

  private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private func requireUnique(_ identifiers: [String]) throws {
    var seen = Set<String>()
    for identifier in identifiers where !seen.insert(identifier).inserted {
      throw ResourceError.duplicateIdentifier(identifier)
    }
  }
}

private struct CircuitFile: Decodable {
  let schemaVersion: Int
  let season: Int
  let circuits: [CircuitDTO]
}

private struct CircuitDTO: Decodable {
  let round: Int
  let meetingKey: Int
  let meetingName: String
  let localizedGrandPrixName: String
  let circuitKey: Int
  let circuitName: String
  let localizedCircuitName: String
  let countryCode: String
  let sourceCountryCode: String?
  let location: String
  let dateStart: Date
  let dateEnd: Date
  let trackAssetID: String
  let geometryStatus: GeometryStatus

  private enum CodingKeys: String, CodingKey {
    case round
    case meetingKey
    case meetingName
    case localizedGrandPrixName
    case circuitKey
    case circuitName
    case localizedCircuitName
    case countryCode
    case sourceCountryCode
    case location
    case dateStart
    case dateEnd
    case trackAssetID = "trackAssetId"
    case geometryStatus
  }
}

private struct DriverFile: Decodable {
  let schemaVersion: Int
  let season: Int
  let drivers: [DriverDTO]
}

private struct DriverDTO: Decodable {
  let id: String
  let number: Int
  let code: String
  let name: String
  let localizedName: String
  let teamID: String
  let nationality: String

  private enum CodingKeys: String, CodingKey {
    case id
    case number
    case code
    case name
    case localizedName
    case teamID = "teamId"
    case nationality
  }
}

private struct TeamFile: Decodable {
  let schemaVersion: Int
  let season: Int
  let teams: [TeamDTO]
}

private struct TeamDTO: Decodable {
  let teamID: String
  let name: String
  let localizedName: String
  let nationality: String
  let primaryColor: String
  let onPrimaryColor: String

  private enum CodingKeys: String, CodingKey {
    case teamID = "teamId"
    case name
    case localizedName
    case nationality
    case primaryColor
    case onPrimaryColor
  }
}

extension Team {
  fileprivate init(_ dto: TeamDTO) {
    self.init(
      id: dto.teamID,
      name: dto.name,
      localizedName: dto.localizedName,
      nationality: dto.nationality,
      primaryColor: dto.primaryColor,
      onPrimaryColor: dto.onPrimaryColor
    )
  }
}

extension Driver {
  fileprivate init(_ dto: DriverDTO) {
    self.init(
      id: dto.id,
      number: dto.number,
      code: dto.code,
      name: dto.name,
      localizedName: dto.localizedName,
      teamID: dto.teamID,
      nationality: dto.nationality
    )
  }
}

extension GrandPrix {
  fileprivate init(season: Int, dto: CircuitDTO) {
    self.init(
      season: season,
      round: dto.round,
      meetingKey: dto.meetingKey,
      meetingName: dto.meetingName,
      localizedGrandPrixName: dto.localizedGrandPrixName,
      circuitKey: dto.circuitKey,
      circuitName: dto.circuitName,
      localizedCircuitName: dto.localizedCircuitName,
      countryCode: dto.countryCode,
      sourceCountryCode: dto.sourceCountryCode,
      location: dto.location,
      dateStart: dto.dateStart,
      dateEnd: dto.dateEnd,
      trackAssetID: dto.trackAssetID,
      geometryStatus: dto.geometryStatus
    )
  }
}
