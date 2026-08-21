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

@MainActor
@Test
func sessionResultResolvesEntitiesAndPreservesPendingAsContent() async throws {
  let (catalog, driver, team) = profileCatalog()
  let session = session(
    grandPrixID: "2026-01",
    kind: .race,
    startsAt: 100,
    endsAt: 200
  )
  let result = SessionResult(
    sessionID: session.id,
    entries: [
      SessionResultEntry(
        position: 1,
        driverID: driver.id,
        teamID: team.id,
        laps: 58,
        time: "1:31:22.456",
        points: 25,
        hasFastestLap: true,
        status: "Finished"
      )
    ],
    updatedAt: Date(timeIntervalSince1970: 250)
  )
  let repository = FeatureRepository(results: [session.id: result])
  let viewModel = SessionResultViewModel(
    session: session,
    catalog: catalog,
    repository: repository,
    clock: FixedFeatureClock(Date(timeIntervalSince1970: 300))
  )

  await viewModel.load()

  let content = try #require(viewModel.state.content)
  #expect(content.availability == .available)
  #expect(content.rows.first?.localizedDriverName == driver.localizedName)
  #expect(content.rows.first?.localizedTeamName == team.localizedName)
  #expect(content.rows.first?.teamColor == team.primaryColor)
  #expect(content.rows.first?.timeOrGap == "1:31:22.456")

  let pendingRepository = FeatureRepository()
  let pendingViewModel = SessionResultViewModel(
    session: session,
    catalog: catalog,
    repository: pendingRepository,
    clock: FixedFeatureClock(Date(timeIntervalSince1970: 300))
  )
  await pendingViewModel.load()
  #expect(pendingViewModel.state.content?.availability == .pending)
  #expect(pendingViewModel.state.failure == nil)
}

@MainActor
@Test
func profileViewModelsDerivePodiumsPolesRoundPointsAndRoster() async throws {
  let (catalog, driver, team) = profileCatalog()
  let teammate = try #require(catalog.drivers.first { $0.id == "russell" })
  let historySessions = [
    historicalSession(
      round: 1,
      kind: .race,
      entries: [
        SessionResultEntry(
          position: 1,
          driverID: driver.id,
          teamID: team.id,
          points: 25
        ),
        SessionResultEntry(
          position: 3,
          driverID: teammate.id,
          teamID: team.id,
          points: 15
        ),
      ]
    ),
    historicalSession(
      round: 1,
      kind: .sprint,
      entries: [
        SessionResultEntry(
          position: 2,
          driverID: driver.id,
          teamID: team.id,
          points: 7
        )
      ]
    ),
    historicalSession(
      round: 1,
      kind: .qualifying,
      entries: [
        SessionResultEntry(position: 1, driverID: driver.id, teamID: team.id)
      ]
    ),
    historicalSession(
      round: 2,
      kind: .race,
      entries: [
        SessionResultEntry(
          position: 3,
          driverID: driver.id,
          teamID: team.id,
          points: 15
        )
      ]
    ),
  ]
  let updatedAt = Date(timeIntervalSince1970: 800)
  let driverHistory = SeasonHistory(
    season: 2026,
    subject: .driver(driver.id),
    sessions: historySessions,
    updatedAt: updatedAt
  )
  let teamHistory = SeasonHistory(
    season: 2026,
    subject: .team(team.id),
    sessions: historySessions,
    updatedAt: updatedAt
  )
  let repository = FeatureRepository(
    driverStandings: [
      DriverStanding(position: 1, driverID: driver.id, teamID: team.id, points: 47, wins: 1),
      DriverStanding(position: 4, driverID: teammate.id, teamID: team.id, points: 15, wins: 0),
    ],
    teamStandings: [
      TeamStanding(position: 1, teamID: team.id, points: 62, wins: 1)
    ],
    histories: [.driver(driver.id): driverHistory, .team(team.id): teamHistory]
  )

  let driverViewModel = DriverProfileViewModel(
    driverID: driver.id,
    catalog: catalog,
    repository: repository
  )
  await driverViewModel.load()
  #expect(driverViewModel.overviewState.content?.standing?.position == 1)
  #expect(driverViewModel.historyState.content?.podiums == 2)
  #expect(driverViewModel.historyState.content?.poles == 1)
  #expect(driverViewModel.historyState.content?.pointsByRound.map(\.points) == [32, 15])
  #expect(driverViewModel.historyState.content?.recentResults.first?.round == 2)

  let teamViewModel = TeamProfileViewModel(
    teamID: team.id,
    catalog: catalog,
    repository: repository
  )
  await teamViewModel.load()
  #expect(teamViewModel.overviewState.content?.drivers.count == 2)
  #expect(teamViewModel.overviewState.content?.drivers.first { $0.id == driver.id }?.points == 47)
  #expect(teamViewModel.historyState.content?.poles == 1)
  #expect(teamViewModel.historyState.content?.pointsByRound.first?.points == 47)
}

private actor FeatureRepository: ApexDataRepository {
  let scheduleValue: [GrandPrix]
  let sessionsValue: [RaceSession]
  let driverStandingsValue: [DriverStanding]
  let teamStandingsValue: [TeamStanding]
  let error: DataClientError?
  let histories: [SeasonHistorySubject: SeasonHistory]
  let results: [String: SessionResult]

  init(
    schedule: [GrandPrix] = [],
    sessions: [RaceSession] = [],
    driverStandings: [DriverStanding] = [],
    teamStandings: [TeamStanding] = [],
    histories: [SeasonHistorySubject: SeasonHistory] = [:],
    results: [String: SessionResult] = [:],
    error: DataClientError? = nil
  ) {
    self.scheduleValue = schedule
    self.sessionsValue = sessions
    self.driverStandingsValue = driverStandings
    self.teamStandingsValue = teamStandings
    self.histories = histories
    self.results = results
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
    return results[sessionID]
  }

  func driverStandings(season: Int, policy: LoadPolicy) throws -> [DriverStanding] {
    if let error { throw error }
    return driverStandingsValue
  }

  func teamStandings(season: Int, policy: LoadPolicy) throws -> [TeamStanding] {
    if let error { throw error }
    return teamStandingsValue
  }

  func seasonHistory(
    season: Int,
    subject: SeasonHistorySubject,
    policy: LoadPolicy
  ) throws -> SeasonHistory {
    if let error { throw error }
    return histories[subject]
      ?? SeasonHistory(
        season: season,
        subject: subject,
        sessions: [],
        updatedAt: Date(timeIntervalSince1970: 0)
      )
  }
}

private func profileCatalog() -> (SeasonResourceCatalog, Driver, Team) {
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
  let teammate = Driver(
    id: "russell",
    number: 63,
    code: "RUS",
    name: "George Russell",
    localizedName: "乔治·拉塞尔",
    teamID: team.id,
    nationality: "British"
  )
  return (
    SeasonResourceCatalog(
      season: 2026,
      grandPrix: [
        grandPrix(round: 1, startsAt: 100, endsAt: 200),
        grandPrix(round: 2, startsAt: 300, endsAt: 400),
      ],
      drivers: [driver, teammate],
      teams: [team]
    ),
    driver,
    team
  )
}

private func historicalSession(
  round: Int,
  kind: SessionKind,
  entries: [SessionResultEntry]
) -> SeasonSessionResult {
  let grandPrixID = round < 10 ? "2026-0\(round)" : "2026-\(round)"
  let sessionID = "\(grandPrixID)-\(kind.rawValue)"
  return SeasonSessionResult(
    grandPrixID: grandPrixID,
    round: round,
    localizedGrandPrixName: "第\(round)站大奖赛",
    kind: kind,
    result: SessionResult(
      sessionID: sessionID,
      entries: entries,
      updatedAt: Date(timeIntervalSince1970: TimeInterval(round * 100))
    )
  )
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
