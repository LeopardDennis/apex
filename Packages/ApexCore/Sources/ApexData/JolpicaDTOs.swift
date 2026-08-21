import Foundation

struct JolpicaRaceResponse<Race: Decodable & Sendable>: Decodable, Sendable {
  let mrData: JolpicaRaceMRData<Race>

  private enum CodingKeys: String, CodingKey {
    case mrData = "MRData"
  }
}

struct JolpicaRaceMRData<Race: Decodable & Sendable>: Decodable, Sendable {
  let raceTable: JolpicaRaceTable<Race>

  private enum CodingKeys: String, CodingKey {
    case raceTable = "RaceTable"
  }
}

struct JolpicaRaceTable<Race: Decodable & Sendable>: Decodable, Sendable {
  let season: String?
  let races: [Race]

  private enum CodingKeys: String, CodingKey {
    case season
    case races = "Races"
  }
}

struct JolpicaScheduleRaceDTO: Decodable, Sendable {
  let season: String
  let round: String
  let raceName: String
  let circuit: JolpicaCircuitDTO
  let date: String
  let time: String?
  let firstPractice: JolpicaSessionTimeDTO?
  let secondPractice: JolpicaSessionTimeDTO?
  let thirdPractice: JolpicaSessionTimeDTO?
  let sprintQualifying: JolpicaSessionTimeDTO?
  let sprint: JolpicaSessionTimeDTO?
  let qualifying: JolpicaSessionTimeDTO?

  private enum CodingKeys: String, CodingKey {
    case season
    case round
    case raceName
    case circuit = "Circuit"
    case date
    case time
    case firstPractice = "FirstPractice"
    case secondPractice = "SecondPractice"
    case thirdPractice = "ThirdPractice"
    case sprintQualifying = "SprintQualifying"
    case sprint = "Sprint"
    case qualifying = "Qualifying"
  }
}

struct JolpicaSessionTimeDTO: Decodable, Sendable {
  let date: String
  let time: String?
}

struct JolpicaCircuitDTO: Decodable, Sendable {
  let circuitID: String
  let circuitName: String
  let location: JolpicaLocationDTO

  private enum CodingKeys: String, CodingKey {
    case circuitID = "circuitId"
    case circuitName
    case location = "Location"
  }
}

struct JolpicaLocationDTO: Decodable, Sendable {
  let locality: String
  let country: String
}

struct JolpicaRaceResultRaceDTO: Decodable, Sendable {
  let season: String
  let round: String
  let results: [JolpicaRaceResultEntryDTO]

  private enum CodingKeys: String, CodingKey {
    case season
    case round
    case results = "Results"
  }
}

struct JolpicaSprintResultRaceDTO: Decodable, Sendable {
  let season: String
  let round: String
  let results: [JolpicaRaceResultEntryDTO]

  private enum CodingKeys: String, CodingKey {
    case season
    case round
    case results = "SprintResults"
  }
}

struct JolpicaQualifyingRaceDTO: Decodable, Sendable {
  let season: String
  let round: String
  let results: [JolpicaQualifyingResultEntryDTO]

  private enum CodingKeys: String, CodingKey {
    case season
    case round
    case results = "QualifyingResults"
  }
}

struct JolpicaRaceResultEntryDTO: Decodable, Sendable {
  let position: String?
  let positionText: String?
  let points: String?
  let driver: JolpicaDriverDTO
  let constructor: JolpicaConstructorDTO
  let grid: String?
  let laps: String?
  let status: String?
  let time: JolpicaTimeDTO?
  let fastestLap: JolpicaFastestLapDTO?

  private enum CodingKeys: String, CodingKey {
    case position
    case positionText
    case points
    case driver = "Driver"
    case constructor = "Constructor"
    case grid
    case laps
    case status
    case time = "Time"
    case fastestLap = "FastestLap"
  }
}

struct JolpicaQualifyingResultEntryDTO: Decodable, Sendable {
  let position: String?
  let driver: JolpicaDriverDTO
  let constructor: JolpicaConstructorDTO
  let q1: String?
  let q2: String?
  let q3: String?

  private enum CodingKeys: String, CodingKey {
    case position
    case driver = "Driver"
    case constructor = "Constructor"
    case q1 = "Q1"
    case q2 = "Q2"
    case q3 = "Q3"
  }
}

struct JolpicaDriverDTO: Decodable, Sendable {
  let driverID: String
  let permanentNumber: String?
  let code: String?
  let givenName: String
  let familyName: String
  let nationality: String?

  private enum CodingKeys: String, CodingKey {
    case driverID = "driverId"
    case permanentNumber
    case code
    case givenName
    case familyName
    case nationality
  }
}

struct JolpicaConstructorDTO: Decodable, Sendable {
  let constructorID: String
  let name: String
  let nationality: String?

  private enum CodingKeys: String, CodingKey {
    case constructorID = "constructorId"
    case name
    case nationality
  }
}

struct JolpicaTimeDTO: Decodable, Sendable {
  let time: String
}

struct JolpicaFastestLapDTO: Decodable, Sendable {
  let rank: String?
  let lap: String?
  let time: JolpicaTimeDTO?

  private enum CodingKeys: String, CodingKey {
    case rank
    case lap
    case time = "Time"
  }
}

struct JolpicaStandingsResponse: Decodable, Sendable {
  let mrData: JolpicaStandingsMRData

  private enum CodingKeys: String, CodingKey {
    case mrData = "MRData"
  }
}

struct JolpicaStandingsMRData: Decodable, Sendable {
  let standingsTable: JolpicaStandingsTable

  private enum CodingKeys: String, CodingKey {
    case standingsTable = "StandingsTable"
  }
}

struct JolpicaStandingsTable: Decodable, Sendable {
  let season: String?
  let standingsLists: [JolpicaStandingsListDTO]

  private enum CodingKeys: String, CodingKey {
    case season
    case standingsLists = "StandingsLists"
  }
}

struct JolpicaStandingsListDTO: Decodable, Sendable {
  let season: String?
  let round: String?
  let driverStandings: [JolpicaDriverStandingDTO]?
  let constructorStandings: [JolpicaConstructorStandingDTO]?

  private enum CodingKeys: String, CodingKey {
    case season
    case round
    case driverStandings = "DriverStandings"
    case constructorStandings = "ConstructorStandings"
  }
}

struct JolpicaDriverStandingDTO: Decodable, Sendable {
  let position: String
  let points: String
  let wins: String
  let driver: JolpicaDriverDTO
  let constructors: [JolpicaConstructorDTO]

  private enum CodingKeys: String, CodingKey {
    case position
    case points
    case wins
    case driver = "Driver"
    case constructors = "Constructors"
  }
}

struct JolpicaConstructorStandingDTO: Decodable, Sendable {
  let position: String
  let points: String
  let wins: String
  let constructor: JolpicaConstructorDTO

  private enum CodingKeys: String, CodingKey {
    case position
    case points
    case wins
    case constructor = "Constructor"
  }
}
