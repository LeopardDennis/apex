import ApexDomain
import ApexResources
import Foundation

public struct JolpicaDecoder: Sendable {
  public init() {}

  public func schedule(from data: Data, catalog: SeasonResourceCatalog) throws -> [GrandPrix] {
    let response: JolpicaRaceResponse<JolpicaScheduleRaceDTO> = try decode(data)
    return catalog.grandPrix.map { local in
      guard let remote = matchingRace(for: local, in: response.mrData.raceTable.races),
        let remoteStart = weekendStart(remote),
        abs(remoteStart.timeIntervalSince(local.dateStart)) <= 10 * 24 * 60 * 60
      else {
        return local
      }
      let duration = local.dateEnd.timeIntervalSince(local.dateStart)
      return GrandPrix(
        season: local.season,
        round: local.round,
        meetingKey: local.meetingKey,
        meetingName: local.meetingName,
        localizedGrandPrixName: local.localizedGrandPrixName,
        circuitKey: local.circuitKey,
        circuitName: local.circuitName,
        localizedCircuitName: local.localizedCircuitName,
        countryCode: local.countryCode,
        sourceCountryCode: local.sourceCountryCode,
        location: local.location,
        dateStart: remoteStart,
        dateEnd: remoteStart.addingTimeInterval(duration),
        trackAssetID: local.trackAssetID,
        geometryStatus: local.geometryStatus
      )
    }
  }

  public func sessions(
    from data: Data,
    grandPrix: GrandPrix,
    now: Date = Date()
  ) throws -> [RaceSession] {
    let response: JolpicaRaceResponse<JolpicaScheduleRaceDTO> = try decode(data)
    guard let race = matchingRace(for: grandPrix, in: response.mrData.raceTable.races) else {
      return []
    }
    let values: [(SessionKind, JolpicaSessionTimeDTO?, TimeInterval)] = [
      (.practice1, race.firstPractice, 60 * 60),
      (.practice2, race.secondPractice, 60 * 60),
      (.practice3, race.thirdPractice, 60 * 60),
      (.sprintQualifying, race.sprintQualifying, 44 * 60),
      (.sprint, race.sprint, 60 * 60),
      (.qualifying, race.qualifying, 60 * 60),
      (.race, JolpicaSessionTimeDTO(date: race.date, time: race.time), 2 * 60 * 60),
    ]
    return values.compactMap { kind, value, duration in
      guard let value, let dateStart = jolpicaDate(date: value.date, time: value.time) else {
        return nil
      }
      let dateEnd = dateStart.addingTimeInterval(duration)
      return RaceSession(
        grandPrixID: grandPrix.id,
        kind: kind,
        dateStart: dateStart,
        dateEnd: dateEnd,
        state: dateEnd <= now ? .resultPending : .scheduled
      )
    }.sorted { $0.dateStart < $1.dateStart }
  }

  public func raceResult(
    from data: Data,
    sessionID: String,
    catalog: SeasonResourceCatalog,
    updatedAt: Date = Date()
  ) throws -> SessionResult? {
    let response: JolpicaRaceResponse<JolpicaRaceResultRaceDTO> = try decode(data)
    guard let race = response.mrData.raceTable.races.first else { return nil }
    return SessionResult(
      sessionID: sessionID,
      entries: mapRaceEntries(race.results, catalog: catalog),
      updatedAt: updatedAt
    )
  }

  public func sprintResult(
    from data: Data,
    sessionID: String,
    catalog: SeasonResourceCatalog,
    updatedAt: Date = Date()
  ) throws -> SessionResult? {
    let response: JolpicaRaceResponse<JolpicaSprintResultRaceDTO> = try decode(data)
    guard let race = response.mrData.raceTable.races.first else { return nil }
    return SessionResult(
      sessionID: sessionID,
      entries: mapRaceEntries(race.results, catalog: catalog),
      updatedAt: updatedAt
    )
  }

  public func qualifyingResult(
    from data: Data,
    sessionID: String,
    catalog: SeasonResourceCatalog,
    updatedAt: Date = Date()
  ) throws -> SessionResult? {
    let response: JolpicaRaceResponse<JolpicaQualifyingRaceDTO> = try decode(data)
    guard let race = response.mrData.raceTable.races.first else { return nil }
    let resolver = EntityResolver(catalog: catalog)
    let entries = race.results.map { entry in
      let driver = resolver.driver(
        id: entry.driver.driverID,
        code: entry.driver.code,
        number: entry.driver.permanentNumber.flatMap(Int.init),
        name: entry.driver.givenName + entry.driver.familyName
      )
      let team = resolver.team(id: entry.constructor.constructorID, name: entry.constructor.name)
      return SessionResultEntry(
        position: entry.position.flatMap(Int.init),
        driverID: driver?.id ?? entry.driver.driverID,
        teamID: team?.id ?? driver?.teamID ?? entry.constructor.constructorID,
        time: entry.q3 ?? entry.q2 ?? entry.q1
      )
    }
    return SessionResult(sessionID: sessionID, entries: entries, updatedAt: updatedAt)
  }

  public func driverStandings(
    from data: Data,
    catalog: SeasonResourceCatalog
  ) throws -> [DriverStanding] {
    let response: JolpicaStandingsResponse = try decode(data)
    let resolver = EntityResolver(catalog: catalog)
    return response.mrData.standingsTable.standingsLists.first?.driverStandings?.compactMap {
      entry in
      guard let position = Int(entry.position), let points = Double(entry.points),
        let wins = Int(entry.wins)
      else { return nil }
      let driver = resolver.driver(
        id: entry.driver.driverID,
        code: entry.driver.code,
        number: entry.driver.permanentNumber.flatMap(Int.init),
        name: entry.driver.givenName + entry.driver.familyName
      )
      let constructor = entry.constructors.first
      let team = resolver.team(id: constructor?.constructorID, name: constructor?.name)
      return DriverStanding(
        position: position,
        driverID: driver?.id ?? entry.driver.driverID,
        teamID: team?.id ?? driver?.teamID ?? constructor?.constructorID ?? "unknown",
        points: points,
        wins: wins
      )
    } ?? []
  }

  public func teamStandings(
    from data: Data,
    catalog: SeasonResourceCatalog
  ) throws -> [TeamStanding] {
    let response: JolpicaStandingsResponse = try decode(data)
    let resolver = EntityResolver(catalog: catalog)
    return response.mrData.standingsTable.standingsLists.first?.constructorStandings?.compactMap {
      entry in
      guard let position = Int(entry.position), let points = Double(entry.points),
        let wins = Int(entry.wins)
      else { return nil }
      let team = resolver.team(
        id: entry.constructor.constructorID,
        name: entry.constructor.name
      )
      return TeamStanding(
        position: position,
        teamID: team?.id ?? entry.constructor.constructorID,
        points: points,
        wins: wins
      )
    } ?? []
  }

  private func mapRaceEntries(
    _ entries: [JolpicaRaceResultEntryDTO],
    catalog: SeasonResourceCatalog
  ) -> [SessionResultEntry] {
    let resolver = EntityResolver(catalog: catalog)
    return entries.map { entry in
      let driver = resolver.driver(
        id: entry.driver.driverID,
        code: entry.driver.code,
        number: entry.driver.permanentNumber.flatMap(Int.init),
        name: entry.driver.givenName + entry.driver.familyName
      )
      let team = resolver.team(id: entry.constructor.constructorID, name: entry.constructor.name)
      return SessionResultEntry(
        position: entry.position.flatMap(Int.init),
        driverID: driver?.id ?? entry.driver.driverID,
        teamID: team?.id ?? driver?.teamID ?? entry.constructor.constructorID,
        laps: entry.laps.flatMap(Int.init),
        time: entry.time?.time,
        points: entry.points.flatMap(Double.init),
        hasFastestLap: entry.fastestLap?.rank == "1",
        status: entry.status
      )
    }
  }

  private func matchingRace(
    for grandPrix: GrandPrix,
    in races: [JolpicaScheduleRaceDTO]
  ) -> JolpicaScheduleRaceDTO? {
    let grandPrixName = normalizedName(grandPrix.meetingName)
    let circuitName = normalizedName(grandPrix.circuitName)
    return races.min { left, right in
      raceScore(
        left, grandPrixName: grandPrixName, circuitName: circuitName, date: grandPrix.dateStart)
        < raceScore(
          right,
          grandPrixName: grandPrixName,
          circuitName: circuitName,
          date: grandPrix.dateStart
        )
    }.flatMap { race in
      let score = raceScore(
        race,
        grandPrixName: grandPrixName,
        circuitName: circuitName,
        date: grandPrix.dateStart
      )
      return score < 100 ? race : nil
    }
  }

  private func raceScore(
    _ race: JolpicaScheduleRaceDTO,
    grandPrixName: String,
    circuitName: String,
    date: Date
  ) -> Double {
    let remoteGrandPrixName = normalizedName(race.raceName)
    let remoteCircuitName = normalizedName(race.circuit.circuitName)
    let nameMatches = remoteGrandPrixName == grandPrixName || remoteCircuitName == circuitName
    guard nameMatches else { return 1_000 }
    guard let remoteDate = jolpicaDate(date: race.date, time: race.time) else { return 50 }
    return abs(remoteDate.timeIntervalSince(date)) / (24 * 60 * 60)
  }

  private func weekendStart(_ race: JolpicaScheduleRaceDTO) -> Date? {
    [
      race.firstPractice,
      race.secondPractice,
      race.thirdPractice,
      race.sprintQualifying,
      race.sprint,
      race.qualifying,
      JolpicaSessionTimeDTO(date: race.date, time: race.time),
    ].compactMap { value in
      value.flatMap { jolpicaDate(date: $0.date, time: $0.time) }
    }.min()
  }

  private func decode<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw DataClientError.decoding(String(describing: error))
    }
  }
}

private func jolpicaDate(date: String, time: String?) -> Date? {
  guard let time else { return nil }
  return iso8601Date(date + "T" + time)
}

private func normalizedName(_ value: String) -> String {
  value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    .filter(\.isLetter)
    .lowercased()
}
