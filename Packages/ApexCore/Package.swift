// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ApexCore",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "ApexDomain", targets: ["ApexDomain"]),
    .library(name: "ApexResources", targets: ["ApexResources"]),
    .library(name: "ApexData", targets: ["ApexData"]),
    .library(name: "ApexFeatures", targets: ["ApexFeatures"]),
  ],
  targets: [
    .target(name: "ApexDomain"),
    .target(name: "ApexResources", dependencies: ["ApexDomain"]),
    .target(name: "ApexData", dependencies: ["ApexDomain", "ApexResources"]),
    .target(
      name: "ApexFeatures",
      dependencies: ["ApexDomain", "ApexData", "ApexResources"]
    ),
    .testTarget(name: "ApexDomainTests", dependencies: ["ApexDomain"]),
    .testTarget(name: "ApexResourcesTests", dependencies: ["ApexResources"]),
    .testTarget(
      name: "ApexDataTests",
      dependencies: ["ApexData", "ApexResources"],
      resources: [.copy("Fixtures")]
    ),
    .testTarget(
      name: "ApexFeaturesTests",
      dependencies: ["ApexFeatures", "ApexData", "ApexDomain", "ApexResources"]
    ),
  ]
)
