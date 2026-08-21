import ApexDomain
import Foundation

public enum WidgetSnapshotStoreError: Error, Equatable, LocalizedError, Sendable {
  case appGroupUnavailable(String)
  case unsupportedSchema(Int)
  case fileIO(String)

  public var errorDescription: String? {
    switch self {
    case .appGroupUnavailable(let identifier):
      "The App Group container is unavailable: \(identifier)."
    case .unsupportedSchema(let version):
      "Unsupported Widget snapshot schema version: \(version)."
    case .fileIO(let detail):
      "The Widget snapshot could not be accessed: \(detail)"
    }
  }
}

public protocol WidgetSnapshotStore: Sendable {
  func snapshot() async throws -> ApexWidgetSnapshot?
  func saveSnapshot(_ snapshot: ApexWidgetSnapshot) async throws
  func removeSnapshot() async throws
}

public actor MemoryWidgetSnapshotStore: WidgetSnapshotStore {
  private var storedSnapshot: ApexWidgetSnapshot?

  public init(snapshot: ApexWidgetSnapshot? = nil) {
    self.storedSnapshot = snapshot
  }

  public func snapshot() -> ApexWidgetSnapshot? {
    storedSnapshot
  }

  public func saveSnapshot(_ snapshot: ApexWidgetSnapshot) {
    storedSnapshot = snapshot
  }

  public func removeSnapshot() {
    storedSnapshot = nil
  }
}

public actor FileWidgetSnapshotStore: WidgetSnapshotStore {
  public static let fileName = "apex-widget-snapshot-v1.json"
  public static let supportedSchemaVersion = 1

  private let directory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL, fileManager: FileManager = .default) {
    self.directory = directory
    self.fileManager = fileManager
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys]
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  public init(appGroupIdentifier: String, fileManager: FileManager = .default) throws {
    guard
      let directory = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    else {
      throw WidgetSnapshotStoreError.appGroupUnavailable(appGroupIdentifier)
    }
    self.init(directory: directory, fileManager: fileManager)
  }

  public func snapshot() throws -> ApexWidgetSnapshot? {
    let url = directory.appendingPathComponent(Self.fileName)
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    do {
      let snapshot = try decoder.decode(ApexWidgetSnapshot.self, from: Data(contentsOf: url))
      guard snapshot.schemaVersion == Self.supportedSchemaVersion else {
        throw WidgetSnapshotStoreError.unsupportedSchema(snapshot.schemaVersion)
      }
      return snapshot
    } catch let error as WidgetSnapshotStoreError {
      throw error
    } catch {
      throw WidgetSnapshotStoreError.fileIO(String(describing: error))
    }
  }

  public func saveSnapshot(_ snapshot: ApexWidgetSnapshot) throws {
    guard snapshot.schemaVersion == Self.supportedSchemaVersion else {
      throw WidgetSnapshotStoreError.unsupportedSchema(snapshot.schemaVersion)
    }
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      try encoder.encode(snapshot).write(
        to: directory.appendingPathComponent(Self.fileName),
        options: .atomic
      )
    } catch {
      throw WidgetSnapshotStoreError.fileIO(String(describing: error))
    }
  }

  public func removeSnapshot() throws {
    let url = directory.appendingPathComponent(Self.fileName)
    guard fileManager.fileExists(atPath: url.path) else { return }
    do {
      try fileManager.removeItem(at: url)
    } catch {
      throw WidgetSnapshotStoreError.fileIO(String(describing: error))
    }
  }
}
