import Foundation

public enum GrandPrixState: Equatable, Sendable {
  case upcoming
  case inProgress
  case completed
}

public struct Countdown: Equatable, Sendable {
  public let days: Int
  public let hours: Int
  public let minutes: Int

  public init(days: Int, hours: Int, minutes: Int) {
    self.days = days
    self.hours = hours
    self.minutes = minutes
  }
}

public enum ScheduleClock {
  public static func state(of grandPrix: GrandPrix, at date: Date) -> GrandPrixState {
    if date < grandPrix.dateStart {
      return .upcoming
    }
    if date <= grandPrix.dateEnd {
      return .inProgress
    }
    return .completed
  }

  public static func currentOrNextGrandPrix(in schedule: [GrandPrix], at date: Date) -> GrandPrix? {
    schedule
      .sorted { $0.dateStart < $1.dateStart }
      .first { state(of: $0, at: date) != .completed }
  }

  public static func nextSession(in sessions: [RaceSession], at date: Date) -> RaceSession? {
    sessions
      .filter { $0.state != .cancelled && $0.dateEnd >= date }
      .sorted { $0.dateStart < $1.dateStart }
      .first
  }

  public static func countdown(to target: Date, from date: Date) -> Countdown {
    let totalMinutes = max(0, Int(target.timeIntervalSince(date) / 60))
    return Countdown(
      days: totalMinutes / (24 * 60),
      hours: totalMinutes % (24 * 60) / 60,
      minutes: totalMinutes % 60
    )
  }
}
