import ApexDomain
import ApexResources
import Foundation

public struct WidgetSnapshotBuilder: Sendable {
  public init() {}

  public func makeSnapshot(
    schedule: [GrandPrix],
    sessions: [RaceSession],
    driverStandings: [DriverStanding],
    teamStandings: [TeamStanding],
    catalog: SeasonResourceCatalog,
    at date: Date = Date()
  ) -> ApexWidgetSnapshot {
    let grandPrix = ScheduleClock.currentOrNextGrandPrix(in: schedule, at: date)
    let sessionSnapshots =
      sessions
      .filter { $0.grandPrixID == grandPrix?.id }
      .sorted { $0.dateStart < $1.dateStart }
      .map {
        WidgetSessionSnapshot(
          id: $0.id,
          kind: $0.kind,
          dateStart: $0.dateStart,
          dateEnd: $0.dateEnd,
          state: $0.state
        )
      }

    return ApexWidgetSnapshot(
      season: catalog.season,
      generatedAt: date,
      nextGrandPrix: grandPrix.map(WidgetGrandPrixSnapshot.init),
      sessions: sessionSnapshots,
      driverLeader: driverLeader(from: driverStandings, catalog: catalog),
      teamLeader: teamLeader(from: teamStandings, catalog: catalog)
    )
  }

  private func driverLeader(
    from standings: [DriverStanding],
    catalog: SeasonResourceCatalog
  ) -> WidgetDriverLeaderSnapshot? {
    guard let standing = standings.min(by: { $0.position < $1.position }),
      let driver = catalog.drivers.first(where: { $0.id == standing.driverID }),
      let team = catalog.teams.first(where: { $0.id == standing.teamID })
    else { return nil }
    return WidgetDriverLeaderSnapshot(
      driverID: driver.id,
      code: driver.code,
      localizedName: driver.localizedName,
      number: driver.number,
      position: standing.position,
      points: standing.points,
      wins: standing.wins,
      teamID: team.id,
      localizedTeamName: team.localizedName,
      primaryColor: team.primaryColor,
      onPrimaryColor: team.onPrimaryColor
    )
  }

  private func teamLeader(
    from standings: [TeamStanding],
    catalog: SeasonResourceCatalog
  ) -> WidgetTeamLeaderSnapshot? {
    guard let standing = standings.min(by: { $0.position < $1.position }),
      let team = catalog.teams.first(where: { $0.id == standing.teamID })
    else { return nil }
    return WidgetTeamLeaderSnapshot(
      teamID: team.id,
      localizedName: team.localizedName,
      position: standing.position,
      points: standing.points,
      wins: standing.wins,
      primaryColor: team.primaryColor,
      onPrimaryColor: team.onPrimaryColor
    )
  }
}

extension WidgetGrandPrixSnapshot {
  fileprivate init(_ grandPrix: GrandPrix) {
    self.init(
      id: grandPrix.id,
      round: grandPrix.round,
      localizedGrandPrixName: grandPrix.localizedGrandPrixName,
      localizedCircuitName: grandPrix.localizedCircuitName,
      location: grandPrix.location,
      countryCode: grandPrix.countryCode,
      dateStart: grandPrix.dateStart,
      dateEnd: grandPrix.dateEnd,
      trackAssetID: grandPrix.trackAssetID
    )
  }
}
