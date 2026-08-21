import ApexData
import ApexDomain
import ApexFeatures
import ApexResources
import Foundation
import Testing

@MainActor
@Test
func calendarBuildsSectionsAndChoosesCurrentGrandPrix() async throws {
  let now = Date(timeIntervalSince1970: 150)
  let completed = grandPrix(round: 1, startsAt: 10, endsAt: 50)
  let current = grandPrix(round: 2, startsAt: 100, endsAt: 200)
  let future = grandPrix(round: 3, startsAt: 300, endsAt: 400)
  let repository = FeatureRepository(schedule: [future, completed, current])
  let viewModel = CalendarViewModel(
    season: 2026,
    repository: repository,
    clock: FixedFeatureClock(now)
  )

  await viewModel.load()

  let content = try #require(viewModel.state.content)
  #expect(content.completed.map(\.id) == [completed.id])
  #expect(content.upcoming.map(\.id) == [current.id, future.id])
  #expect(content.upcoming.first?.state == .inProgress)
  #expect(viewModel.selectedGrandPrixID == current.id)
  #expect(viewModel.state.lastUpdatedAt == now)

  viewModel.select(grandPrixID: future.id)
  await viewModel.refresh()
  #expect(viewModel.selectedGrandPrixID == future.id)
}

@MainActor
@Test
func grandPrixDetailSortsSessionsAndMarksTheNextOne() async throws {
  let now = Date(timeIntervalSince1970: 150)
  let grandPrix = grandPrix(round: 2, startsAt: 100, endsAt: 500)
  let completedPractice = session(
    grandPrixID: grandPrix.id,
    kind: .practice1,
    startsAt: 100,
    endsAt: 120
  )
  let race = session(
    grandPrixID: grandPrix.id,
    kind: .race,
    startsAt: 400,
    endsAt: 500
  )
  let qualifying = session(
    grandPrixID: grandPrix.id,
    kind: .qualifying,
    startsAt: 210,
    endsAt: 250
  )
  let repository = FeatureRepository(
    schedule: [grandPrix],
    sessions: [race, qualifying, completedPractice]
  )
  let viewModel = GrandPrixDetailViewModel(
    grandPrix: grandPrix,
    repository: repository,
    clock: FixedFeatureClock(now)
  )

  await viewModel.load()

  let content = try #require(viewModel.state.content)
  #expect(content.sessions.map(\.session.kind) == [.practice1, .qualifying, .race])
  #expect(content.nextSession?.kind == .qualifying)
  #expect(content.countdown == Countdown(days: 0, hours: 0, minutes: 1))
}

@MainActor
@Test
func standingsResolveChineseNamesAndOfficialTeamColors() async throws {
  let team = Team(
    id: "mercedes",
    name: "Mercedes",
    localizedName: "梅赛德斯",
    nationality: "German",
    primaryColor: "#00A19B",
    onPrimaryColor: "#00100F"
  )
  let driver = Driver(
    id: "antonelli",
    number: 12,
    code: "ANT",
    name: "Andrea Kimi Antonelli",
    localizedName: "安德烈亚·基米·安东内利",
    teamID: team.id,
    nationality: "Italian"
  )
  let catalog = SeasonResourceCatalog(
    season: 2026,
    grandPrix: [],
    drivers: [driver],
    teams: [team]
  )
  let repository = FeatureRepository(
    driverStandings: [
      DriverStanding(
        position: 1,
        driverID: driver.id,
        teamID: team.id,
        points: 219,
        wins: 6
      )
    ],
    teamStandings: [
      TeamStanding(position: 1, teamID: team.id, points: 379, wins: 8)
    ]
  )
  let viewModel = StandingsViewModel(
    catalog: catalog,
    repository: repository,
    clock: FixedFeatureClock(Date(timeIntervalSince1970: 500))
  )

  await viewModel.load()

  let driverRow = try #require(viewModel.driverState.content?.first)
  #expect(driverRow.localizedDriverName == "安德烈亚·基米·安东内利")
  #expect(driverRow.localizedTeamName == "梅赛德斯")
  #expect(driverRow.teamColor == "#00A19B")
  #expect(viewModel.selectedDriverID == driver.id)

  let teamRow = try #require(viewModel.teamState.content?.first)
  #expect(teamRow.localizedTeamName == "梅赛德斯")
  #expect(teamRow.englishTeamName == "Mercedes")
  #expect(teamRow.teamColor == "#00A19B")
  #expect(viewModel.selectedTeamID == team.id)
}

@MainActor
@Test
func featureFailureProducesStableChineseOfflineCopy() async {
  let repository = FeatureRepository(error: DataClientError.offline)
  let viewModel = CalendarViewModel(season: 2026, repository: repository)

  await viewModel.load()

  #expect(viewModel.state.content == nil)
  #expect(viewModel.state.failure?.code == .offline)
  #expect(viewModel.state.failure?.title == "当前处于离线状态")
  #expect(viewModel.state.canRetry)
}

private actor FeatureRepository: ApexDataRepository {
  let scheduleValue: [GrandPrix]
  let sessionsValue: [RaceSession]
  let driverStandingsValue: [DriverStanding]
  let teamStandingsValue: [TeamStanding]
  let error: DataClientError?

  init(
    schedule: [GrandPrix] = [],
    sessions: [RaceSession] = [],
    driverStandings: [DriverStanding] = [],
    teamStandings: [TeamStanding] = [],
    error: DataClientError? = nil
  ) {
    self.scheduleValue = schedule
    self.sessionsValue = sessions
    self.driverStandingsValue = driverStandings
    self.teamStandingsValue = teamStandings
    self.error = error
  }

  func schedule(season: Int, policy: LoadPolicy) throws -> [GrandPrix] {
    if let error { throw error }
    return scheduleValue
  }

  func sessions(grandPrixID: String, policy: LoadPolicy) throws -> [RaceSession] {
    if let error { throw error }
    return sessionsValue
  }

  func result(sessionID: String, policy: LoadPolicy) throws -> SessionResult? {
    if let error { throw error }
    return nil
  }

  func driverStandings(season: Int, policy: LoadPolicy) throws -> [DriverStanding] {
    if let error { throw error }
    return driverStandingsValue
  }

  func teamStandings(season: Int, policy: LoadPolicy) throws -> [TeamStanding] {
    if let error { throw error }
    return teamStandingsValue
  }
}

private func grandPrix(round: Int, startsAt: TimeInterval, endsAt: TimeInterval) -> GrandPrix {
  GrandPrix(
    season: 2026,
    round: round,
    meetingKey: 1_000 + round,
    meetingName: "Grand Prix \(round)",
    localizedGrandPrixName: "第\(round)站大奖赛",
    circuitKey: round,
    circuitName: "Circuit \(round)",
    localizedCircuitName: "第\(round)赛道",
    countryCode: "TST",
    location: "Test",
    dateStart: Date(timeIntervalSince1970: startsAt),
    dateEnd: Date(timeIntervalSince1970: endsAt),
    trackAssetID: "circuit-\(round)",
    geometryStatus: .available
  )
}

private func session(
  grandPrixID: String,
  kind: SessionKind,
  startsAt: TimeInterval,
  endsAt: TimeInterval
) -> RaceSession {
  RaceSession(
    grandPrixID: grandPrixID,
    kind: kind,
    dateStart: Date(timeIntervalSince1970: startsAt),
    dateEnd: Date(timeIntervalSince1970: endsAt),
    state: .scheduled
  )
}
