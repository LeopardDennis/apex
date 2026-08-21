import ApexDomain
import ApexResources
import Foundation

struct EntityResolver: Sendable {
  let catalog: SeasonResourceCatalog
  private let driversByID: [String: Driver]
  private let driversByCode: [String: Driver]
  private let driversByNumber: [Int: Driver]
  private let driversByName: [String: Driver]
  private let teamsByID: [String: Team]
  private let teamsByName: [String: Team]

  init(catalog: SeasonResourceCatalog) {
    self.catalog = catalog
    self.driversByID = Dictionary(uniqueKeysWithValues: catalog.drivers.map { ($0.id, $0) })
    self.driversByCode = Dictionary(
      uniqueKeysWithValues: catalog.drivers.map { ($0.code.uppercased(), $0) })
    self.driversByNumber = Dictionary(
      uniqueKeysWithValues: catalog.drivers.map { ($0.number, $0) })
    self.driversByName = Dictionary(
      uniqueKeysWithValues: catalog.drivers.map { (normalized($0.name), $0) })
    self.teamsByID = Dictionary(uniqueKeysWithValues: catalog.teams.map { ($0.id, $0) })
    self.teamsByName = Dictionary(
      uniqueKeysWithValues: catalog.teams.map { (normalizedTeamName($0.name), $0) })
  }

  func driver(
    id: String? = nil,
    code: String? = nil,
    number: Int? = nil,
    name: String? = nil
  ) -> Driver? {
    if let id, let driver = driversByID[id] { return driver }
    if let code, let driver = driversByCode[code.uppercased()] { return driver }
    if let name, let driver = driversByName[normalized(name)] { return driver }
    if let number, let driver = driversByNumber[number] { return driver }
    return nil
  }

  func team(id: String? = nil, name: String? = nil) -> Team? {
    if let id, let team = teamsByID[id] { return team }
    if let name {
      let key = normalizedTeamName(name)
      if let team = teamsByName[key] { return team }
      return catalog.teams.first { team in
        let localKey = normalizedTeamName(team.name)
        return localKey.contains(key) || key.contains(localKey)
      }
    }
    return nil
  }
}

private func normalized(_ value: String) -> String {
  value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    .filter(\.isLetter)
    .lowercased()
}

private func normalizedTeamName(_ value: String) -> String {
  var result = normalized(value)
  for suffix in ["formulaone", "racingteam", "f1team", "team"] {
    result = result.replacingOccurrences(of: suffix, with: "")
  }
  return result
}
