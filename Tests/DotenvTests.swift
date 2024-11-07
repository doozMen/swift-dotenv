import Foundation
import SwiftDotenv
import Testing

extension Issue: Swift.Error {}

@Suite struct DotenvTests {

  let dotenv: Dotenv

  private static var temporarySaveLocation: String {
    "\(NSTemporaryDirectory())swift-dotenv/"
  }

  init() throws {
    try FileManager.default.createDirectory(
      at: URL(fileURLWithPath: Self.temporarySaveLocation),
      withIntermediateDirectories: true, attributes: nil
    )
    guard let path = Bundle.module.path(forResource: "fixture", ofType: "env") else {
      throw Issue.record("unable to find env file")
    }

    dotenv = try Dotenv(path: path)
  }

  @Test func configuringEnvironment() throws {
    #expect(dotenv.apiKey == .string("some-value"))
    #expect(dotenv.buildNumber == .integer(5))
    #expect(dotenv.identifier == .string("com.app.example"))
    #expect(dotenv.mailTemplate == .string("The \"Quoted\" Title"))
    #expect(dotenv.dbPassphrase == .string("1qaz?#@\"' wsx$"))
    #expect(dotenv.nonExistentValue == nil)
  }

  @Test func subscriptingByStrings() throws {
    // implicitly testing string subscripting
    #expect(dotenv[dynamicMember: "API_KEY"] == .string("some-value"))
    #expect(dotenv[dynamicMember: "BUILD_NUMBER"] == .integer(5))
    #expect(dotenv[dynamicMember: "IDENTIFIER"] == .string("com.app.example"))
  }

  @Test func subscriptingNonexistantValue() {
    #expect(dotenv.randomVariable == nil)
  }

  @Test func settingValues() {
    var dotenv = self.dotenv
    dotenv.apiKey = .integer(1234)

    #expect(dotenv.apiKey == .integer(1234))
    let process = dotenv.createProcessWithDotenv()
    #expect(process.environment?["API_KEY"] == "1234")
  }

  @Test func overridingValues() {
    var dotenv = self.dotenv
    dotenv.apiKey = .integer(1234)

    #expect(dotenv.apiKey == .integer(1234))

    dotenv.secretKey = dotenv.apiKey

    #expect(dotenv.secretKey == dotenv.apiKey)
  }
}
