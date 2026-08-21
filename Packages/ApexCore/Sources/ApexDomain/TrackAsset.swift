import Foundation

public struct TrackPoint: Codable, Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public var isNormalized: Bool {
    x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
  }
}

public struct TrackCorner: Codable, Equatable, Sendable {
  public let number: Int
  public let angleDegrees: Double
  public let x: Double
  public let y: Double

  public init(number: Int, angleDegrees: Double, x: Double, y: Double) {
    self.number = number
    self.angleDegrees = angleDegrees
    self.x = x
    self.y = y
  }

  public var point: TrackPoint { TrackPoint(x: x, y: y) }
}

public struct TrackRendering: Codable, Equatable, Sendable {
  public enum Stroke: String, Codable, Sendable {
    case singleColor
  }

  public let stroke: Stroke
  public let showsCornerNumbers: Bool
  public let showsSegmentColors: Bool

  public init(stroke: Stroke, showsCornerNumbers: Bool, showsSegmentColors: Bool) {
    self.stroke = stroke
    self.showsCornerNumbers = showsCornerNumbers
    self.showsSegmentColors = showsSegmentColors
  }
}

public struct TrackSource: Codable, Equatable, Sendable {
  public let provider: String
  public let url: URL
  public let sourceYear: Int?
  public let note: String?

  public init(provider: String, url: URL, sourceYear: Int? = nil, note: String? = nil) {
    self.provider = provider
    self.url = url
    self.sourceYear = sourceYear
    self.note = note
  }
}

public struct TrackViewBox: Codable, Equatable, Sendable {
  public let minX: Double
  public let minY: Double
  public let width: Double
  public let height: Double

  public init(minX: Double, minY: Double, width: Double, height: Double) {
    self.minX = minX
    self.minY = minY
    self.width = width
    self.height = height
  }
}

public struct TrackAsset: Codable, Equatable, Identifiable, Sendable {
  public let schemaVersion: Int
  public let trackAssetID: String
  public let circuitKey: Int
  public let circuitName: String
  public let geometryStatus: GeometryStatus
  public let rendering: TrackRendering
  public let source: TrackSource
  public let rotationDegrees: Double
  public let viewBox: TrackViewBox
  public let pathPoints: [TrackPoint]
  public let corners: [TrackCorner]
  public let startFinishMarker: TrackPoint?
  public let directionMarker: TrackPoint?
  public let pitLanePath: [TrackPoint]

  public var id: String { trackAssetID }

  public init(
    schemaVersion: Int,
    trackAssetID: String,
    circuitKey: Int,
    circuitName: String,
    geometryStatus: GeometryStatus,
    rendering: TrackRendering,
    source: TrackSource,
    rotationDegrees: Double,
    viewBox: TrackViewBox,
    pathPoints: [TrackPoint],
    corners: [TrackCorner],
    startFinishMarker: TrackPoint?,
    directionMarker: TrackPoint?,
    pitLanePath: [TrackPoint]
  ) {
    self.schemaVersion = schemaVersion
    self.trackAssetID = trackAssetID
    self.circuitKey = circuitKey
    self.circuitName = circuitName
    self.geometryStatus = geometryStatus
    self.rendering = rendering
    self.source = source
    self.rotationDegrees = rotationDegrees
    self.viewBox = viewBox
    self.pathPoints = pathPoints
    self.corners = corners
    self.startFinishMarker = startFinishMarker
    self.directionMarker = directionMarker
    self.pitLanePath = pitLanePath
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case trackAssetID = "trackAssetId"
    case circuitKey
    case circuitName
    case geometryStatus
    case rendering
    case source
    case rotationDegrees
    case viewBox
    case pathPoints
    case corners
    case startFinishMarker
    case directionMarker
    case pitLanePath
  }
}
