import Foundation

public enum SeasonHistorySubject: Codable, Equatable, Hashable, Sendable {
  case driver(String)
  case team(String)

  public var identifier: String {
    switch self {
    case .driver(let identifier), .team(let identifier):
      identifier
    }
  }
}

public struct SeasonSessionResult: Codable, Equatable, Identifiable, Sendable {
  public let grandPrixID: String
  public let round: Int
  public let localizedGrandPrixName: String
  public let kind: SessionKind
  public let result: SessionResult

  public var id: String { result.sessionID }

  public init(
    grandPrixID: String,
    round: Int,
    localizedGrandPrixName: String,
    kind: SessionKind,
    result: SessionResult
  ) {
    self.grandPrixID = grandPrixID
    self.round = round
    self.localizedGrandPrixName = localizedGrandPrixName
    self.kind = kind
    self.result = result
  }
}

public struct SeasonHistory: Codable, Equatable, Sendable {
  public let season: Int
  public let subject: SeasonHistorySubject
  public let sessions: [SeasonSessionResult]
  public let updatedAt: Date

  public init(
    season: Int,
    subject: SeasonHistorySubject,
    sessions: [SeasonSessionResult],
    updatedAt: Date
  ) {
    self.season = season
    self.subject = subject
    self.sessions = sessions
    self.updatedAt = updatedAt
  }
}
