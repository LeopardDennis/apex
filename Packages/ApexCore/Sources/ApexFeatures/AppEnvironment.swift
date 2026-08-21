import ApexData
import ApexDomain
import ApexResources
import Foundation

@MainActor
public final class AppEnvironment {
  public let catalog: SeasonResourceCatalog
  public let repository: any ApexDataRepository
  public let widgetSnapshotStore: any WidgetSnapshotStore
  public let clock: any FeatureClock

  public private(set) lazy var homeViewModel = HomeViewModel(
    catalog: catalog,
    repository: repository,
    widgetSnapshotStore: widgetSnapshotStore,
    clock: clock
  )

  public private(set) lazy var calendarViewModel = CalendarViewModel(
    season: catalog.season,
    repository: repository,
    clock: clock
  )

  public private(set) lazy var standingsViewModel = StandingsViewModel(
    catalog: catalog,
    repository: repository,
    clock: clock
  )

  public init(
    catalog: SeasonResourceCatalog,
    repository: any ApexDataRepository,
    widgetSnapshotStore: any WidgetSnapshotStore,
    clock: any FeatureClock = SystemFeatureClock()
  ) {
    self.catalog = catalog
    self.repository = repository
    self.widgetSnapshotStore = widgetSnapshotStore
    self.clock = clock
  }

  public static func fileBacked(
    catalog: SeasonResourceCatalog,
    applicationSupportDirectory: URL,
    widgetDirectory: URL,
    configuration: DataSourceConfiguration = DataSourceConfiguration(),
    transport: any HTTPTransport = URLSessionHTTPTransport(),
    clock: any FeatureClock = SystemFeatureClock()
  ) -> AppEnvironment {
    let responseCache = FileHTTPResponseCache(
      directory: applicationSupportDirectory.appendingPathComponent("HTTPResponses")
    )
    let client = APIClient(transport: transport, cache: responseCache)
    let remoteRepository = ApexRepository(
      client: client,
      catalog: catalog,
      configuration: configuration
    )
    let persistenceStore = FileApexPersistenceStore(
      directory: applicationSupportDirectory.appendingPathComponent("DomainSnapshots")
    )
    let repository = OfflineFirstApexRepository(
      remote: remoteRepository,
      persistence: persistenceStore
    )
    let widgetStore = FileWidgetSnapshotStore(directory: widgetDirectory)
    return AppEnvironment(
      catalog: catalog,
      repository: repository,
      widgetSnapshotStore: widgetStore,
      clock: clock
    )
  }

  public func makeGrandPrixDetailViewModel(
    grandPrix: GrandPrix,
    trackAsset: TrackAsset? = nil
  ) -> GrandPrixDetailViewModel {
    GrandPrixDetailViewModel(
      grandPrix: grandPrix,
      trackAsset: trackAsset,
      repository: repository,
      clock: clock
    )
  }

  public func makeSessionResultViewModel(session: RaceSession) -> SessionResultViewModel {
    SessionResultViewModel(
      session: session,
      catalog: catalog,
      repository: repository,
      clock: clock
    )
  }

  public func makeDriverProfileViewModel(driverID: String) -> DriverProfileViewModel {
    DriverProfileViewModel(
      driverID: driverID,
      catalog: catalog,
      repository: repository,
      clock: clock
    )
  }

  public func makeTeamProfileViewModel(teamID: String) -> TeamProfileViewModel {
    TeamProfileViewModel(
      teamID: teamID,
      catalog: catalog,
      repository: repository,
      clock: clock
    )
  }
}
