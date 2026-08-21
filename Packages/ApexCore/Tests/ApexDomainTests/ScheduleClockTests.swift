import ApexDomain
import Foundation
import Testing

@Test
func currentOrNextGrandPrixKeepsAnActiveWeekendSelected() throws {
  let first = try grandPrix(
    round: 1,
    starts: "2026-03-06T01:30:00Z",
    ends: "2026-03-08T06:00:00Z"
  )
  let second = try grandPrix(
    round: 2,
    starts: "2026-03-13T03:30:00Z",
    ends: "2026-03-15T09:00:00Z"
  )

  let selected = ScheduleClock.currentOrNextGrandPrix(
    in: [second, first],
    at: try date("2026-03-07T12:00:00Z")
  )

  #expect(selected?.round == 1)
  #expect(
    ScheduleClock.state(of: first, at: try date("2026-03-07T12:00:00Z"))
      == .inProgress
  )
}

@Test
func currentOrNextGrandPrixMovesPastACompletedWeekend() throws {
  let first = try grandPrix(
    round: 1,
    starts: "2026-03-06T01:30:00Z",
    ends: "2026-03-08T06:00:00Z"
  )
  let second = try grandPrix(
    round: 2,
    starts: "2026-03-13T03:30:00Z",
    ends: "2026-03-15T09:00:00Z"
  )

  let selected = ScheduleClock.currentOrNextGrandPrix(
    in: [first, second],
    at: try date("2026-03-09T00:00:00Z")
  )

  #expect(selected?.round == 2)
}

@Test
func nextSessionIgnoresCancelledAndCompletedSessions() throws {
  let grandPrixID = "2026-01"
  let completed = try session(
    grandPrixID: grandPrixID,
    kind: .practice1,
    starts: "2026-03-06T01:30:00Z",
    ends: "2026-03-06T02:30:00Z"
  )
  let cancelled = RaceSession(
    grandPrixID: grandPrixID,
    kind: .practice2,
    dateStart: try date("2026-03-06T05:00:00Z"),
    dateEnd: try date("2026-03-06T06:00:00Z"),
    state: .cancelled
  )
  let qualifying = try session(
    grandPrixID: grandPrixID,
    kind: .qualifying,
    starts: "2026-03-07T05:00:00Z",
    ends: "2026-03-07T06:00:00Z"
  )

  let selected = ScheduleClock.nextSession(
    in: [qualifying, cancelled, completed],
    at: try date("2026-03-06T03:00:00Z")
  )

  #expect(selected?.kind == .qualifying)
}

@Test
func countdownUsesWholeMinutesAndClampsPastDates() throws {
  let now = try date("2026-03-01T00:00:30Z")
  let target = try date("2026-03-03T03:04:59Z")

  #expect(
    ScheduleClock.countdown(to: target, from: now)
      == Countdown(days: 2, hours: 3, minutes: 4)
  )
  #expect(
    ScheduleClock.countdown(to: now, from: target)
      == Countdown(days: 0, hours: 0, minutes: 0)
  )
}

private func grandPrix(round: Int, starts: String, ends: String) throws -> GrandPrix {
  GrandPrix(
    season: 2026,
    round: round,
    meetingKey: 1_000 + round,
    meetingName: "Grand Prix \(round)",
    localizedGrandPrixName: "第\(round)站",
    circuitKey: round,
    circuitName: "Circuit \(round)",
    localizedCircuitName: "赛道 \(round)",
    countryCode: "TST",
    location: "Test",
    dateStart: try date(starts),
    dateEnd: try date(ends),
    trackAssetID: "circuit-\(round)",
    geometryStatus: .available
  )
}

private func session(
  grandPrixID: String,
  kind: SessionKind,
  starts: String,
  ends: String
) throws -> RaceSession {
  RaceSession(
    grandPrixID: grandPrixID,
    kind: kind,
    dateStart: try date(starts),
    dateEnd: try date(ends),
    state: .scheduled
  )
}

private func date(_ value: String) throws -> Date {
  try #require(ISO8601DateFormatter().date(from: value))
}
