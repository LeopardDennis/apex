import ApexData
import Foundation
import Testing

@Test
func jolpicaBuildsStableSeasonAndResultURLs() throws {
  #expect(
    try JolpicaEndpoint.schedule(season: 2026).url().absoluteString
      == "https://api.jolpi.ca/ergast/f1/2026.json?limit=100"
  )
  #expect(
    try JolpicaEndpoint.raceResults(season: 2026, round: 14).url().absoluteString
      == "https://api.jolpi.ca/ergast/f1/2026/14/results.json?limit=100"
  )
}

@Test
func openF1BuildsSessionURLsUsingProviderKeys() throws {
  #expect(
    try OpenF1Endpoint.sessions(meetingKey: 1_292).url().absoluteString
      == "https://api.openf1.org/v1/sessions?meeting_key=1292"
  )
  #expect(
    try OpenF1Endpoint.sessionResult(sessionKey: 11_342).url().absoluteString
      == "https://api.openf1.org/v1/session_result?session_key=11342"
  )
}

@Test
func requestFactoryAddsApexHeaders() throws {
  let url = try JolpicaEndpoint.nextGrandPrix.url()
  let request = APIRequestFactory().request(for: url)

  #expect(request.value(forHTTPHeaderField: "User-Agent") == "Apex/1.0 iOS")
  #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
}
