import Foundation

struct OpenF1MeetingDTO: Decodable, Sendable {
  let meetingKey: Int
  let meetingName: String
  let meetingOfficialName: String?
  let location: String
  let countryCode: String
  let countryName: String
  let circuitKey: Int
  let circuitShortName: String
  let dateStart: String
  let dateEnd: String
  let year: Int

  private enum CodingKeys: String, CodingKey {
    case meetingKey = "meeting_key"
    case meetingName = "meeting_name"
    case meetingOfficialName = "meeting_official_name"
    case location
    case countryCode = "country_code"
    case countryName = "country_name"
    case circuitKey = "circuit_key"
    case circuitShortName = "circuit_short_name"
    case dateStart = "date_start"
    case dateEnd = "date_end"
    case year
  }
}

struct OpenF1SessionDTO: Decodable, Sendable {
  let sessionKey: Int
  let meetingKey: Int
  let sessionName: String
  let sessionType: String
  let dateStart: String
  let dateEnd: String
  let year: Int

  private enum CodingKeys: String, CodingKey {
    case sessionKey = "session_key"
    case meetingKey = "meeting_key"
    case sessionName = "session_name"
    case sessionType = "session_type"
    case dateStart = "date_start"
    case dateEnd = "date_end"
    case year
  }
}

struct OpenF1DriverDTO: Decodable, Sendable {
  let driverNumber: Int
  let broadcastName: String?
  let fullName: String?
  let nameAcronym: String?
  let firstName: String?
  let lastName: String?
  let teamName: String?
  let teamColour: String?

  private enum CodingKeys: String, CodingKey {
    case driverNumber = "driver_number"
    case broadcastName = "broadcast_name"
    case fullName = "full_name"
    case nameAcronym = "name_acronym"
    case firstName = "first_name"
    case lastName = "last_name"
    case teamName = "team_name"
    case teamColour = "team_colour"
  }
}

struct OpenF1SessionResultDTO: Decodable, Sendable {
  let driverNumber: Int
  let position: Int?
  let numberOfLaps: Int?
  let duration: FlexibleDouble?
  let gapToLeader: FlexibleDouble?
  let dnf: Bool?
  let dns: Bool?
  let dsq: Bool?

  private enum CodingKeys: String, CodingKey {
    case driverNumber = "driver_number"
    case position
    case numberOfLaps = "number_of_laps"
    case duration
    case gapToLeader = "gap_to_leader"
    case dnf
    case dns
    case dsq
  }
}

struct FlexibleDouble: Decodable, Equatable, Sendable {
  let value: Double?

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = nil
    } else if let number = try? container.decode(Double.self) {
      value = number
    } else if let text = try? container.decode(String.self) {
      value = Double(text)
    } else {
      value = nil
    }
  }
}
