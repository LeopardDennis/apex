import ApexDomain
import ApexResources
import Foundation

public struct OpenF1MappedSession: Equatable, Sendable {
  public let sessionKey: Int
  public let session: RaceSession

  public init(sessionKey: Int, session: RaceSession) {
    self.sessionKey = sessionKey
    self.session = session
  }
}

public struct OpenF1Decoder: Sendable {
  public init() {}

  public func schedule(from data: Data, catalog: SeasonResourceCatalog) throws -> [GrandPrix] {
    let meetings: [OpenF1MeetingDTO] = try decode(data)
    return catalog.grandPrix.map { local in
      guard
        let meeting = meetings.first(where: { meeting in
          meeting.meetingKey == local.meetingKey
            || (meeting.circuitKey == local.circuitKey
              && abs(dateDistance(meeting.dateStart, local.dateStart)) < 10 * 24 * 60 * 60)
        }),
        let dateStart = iso8601Date(meeting.dateStart),
        let dateEnd = iso8601Date(meeting.dateEnd),
        dateStart < dateEnd
      else { return local }
      return GrandPrix(
        season: local.season,
        round: local.round,
        meetingKey: meeting.meetingKey,
        meetingName: local.meetingName,
        localizedGrandPrixName: local.localizedGrandPrixName,
        circuitKey: meeting.circuitKey,
        circuitName: local.circuitName,
        localizedCircuitName: local.localizedCircuitName,
        countryCode: local.countryCode,
        sourceCountryCode: local.sourceCountryCode,
        location: local.location,
        dateStart: dateStart,
        dateEnd: dateEnd,
        trackAssetID: local.trackAssetID,
        geometryStatus: local.geometryStatus
      )
    }
  }

  public func sessions(
    from data: Data,
    grandPrix: GrandPrix,
    now: Date = Date()
  ) throws -> [OpenF1MappedSession] {
    let sessions: [OpenF1SessionDTO] = try decode(data)
    return sessions.compactMap { value in
      guard value.meetingKey == grandPrix.meetingKey,
        let kind = sessionKind(name: value.sessionName, type: value.sessionType),
        let dateStart = iso8601Date(value.dateStart),
        let dateEnd = iso8601Date(value.dateEnd),
        dateStart < dateEnd
      else { return nil }
      return OpenF1MappedSession(
        sessionKey: value.sessionKey,
        session: RaceSession(
          grandPrixID: grandPrix.id,
          kind: kind,
          dateStart: dateStart,
          dateEnd: dateEnd,
          state: dateEnd <= now ? .resultPending : .scheduled
        )
      )
    }.sorted { $0.session.dateStart < $1.session.dateStart }
  }

  public func result(
    from resultData: Data,
    driversData: Data,
    sessionID: String,
    catalog: SeasonResourceCatalog,
    updatedAt: Date = Date()
  ) throws -> SessionResult {
    let results: [OpenF1SessionResultDTO] = try decode(resultData)
    let remoteDrivers: [OpenF1DriverDTO] = try decode(driversData)
    let driversByNumber = remoteDrivers.reduce(into: [Int: OpenF1DriverDTO]()) { result, driver in
      result[driver.driverNumber] = driver
    }
    let resolver = EntityResolver(catalog: catalog)
    let entries = results.map { result in
      let remoteDriver = driversByNumber[result.driverNumber]
      let driver = resolver.driver(
        code: remoteDriver?.nameAcronym,
        number: result.driverNumber,
        name: remoteDriver?.fullName ?? remoteDriver?.broadcastName
      )
      let team = resolver.team(name: remoteDriver?.teamName)
      return SessionResultEntry(
        position: result.position,
        driverID: driver?.id ?? "driver-\(result.driverNumber)",
        teamID: team?.id ?? driver?.teamID ?? "unknown",
        laps: result.numberOfLaps,
        time: formattedDuration(result.duration?.value),
        gap: formattedGap(result.gapToLeader?.value),
        hasFastestLap: false,
        status: resultStatus(result)
      )
    }.sorted { left, right in
      (left.position ?? Int.max) < (right.position ?? Int.max)
    }
    return SessionResult(sessionID: sessionID, entries: entries, updatedAt: updatedAt)
  }

  private func sessionKind(name: String, type: String) -> SessionKind? {
    let value = (name + " " + type).lowercased()
    if value.contains("sprint qualifying") || value.contains("sprint shootout") {
      return .sprintQualifying
    }
    if value.contains("practice 1") { return .practice1 }
    if value.contains("practice 2") { return .practice2 }
    if value.contains("practice 3") { return .practice3 }
    if value.contains("qualifying") { return .qualifying }
    if value.contains("sprint") { return .sprint }
    if value.contains("race") { return .race }
    return nil
  }

  private func decode<T: Decodable>(_ data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw DataClientError.decoding(String(describing: error))
    }
  }
}

func iso8601Date(_ value: String) -> Date? {
  let fractional = ISO8601DateFormatter()
  fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = fractional.date(from: value) { return date }
  return ISO8601DateFormatter().date(from: value)
}

private func dateDistance(_ remoteValue: String, _ localDate: Date) -> TimeInterval {
  guard let remoteDate = iso8601Date(remoteValue) else { return .greatestFiniteMagnitude }
  return remoteDate.timeIntervalSince(localDate)
}

private func resultStatus(_ result: OpenF1SessionResultDTO) -> String? {
  if result.dsq == true { return "DSQ" }
  if result.dns == true { return "DNS" }
  if result.dnf == true { return "DNF" }
  return nil
}

private func formattedDuration(_ value: Double?) -> String? {
  guard let value else { return nil }
  let hours = Int(value) / 3_600
  let minutes = (Int(value) % 3_600) / 60
  let seconds = value.truncatingRemainder(dividingBy: 60)
  if hours > 0 {
    return String(format: "%d:%02d:%06.3f", hours, minutes, seconds)
  }
  return String(format: "%d:%06.3f", minutes, seconds)
}

private func formattedGap(_ value: Double?) -> String? {
  guard let value else { return nil }
  if value == 0 { return nil }
  return String(format: "+%.3f", value)
}
