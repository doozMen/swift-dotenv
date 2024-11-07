import Foundation
import Logging
import RegexBuilder

private let logger = Logger(label: "\(Dotenv.self)")

/// Structure used to load and save environment files and makes them available via task local
@dynamicMemberLookup
public struct Dotenv {
  @TaskLocal public static var current: Dotenv?

  private let values: [String: String]

  public init(values: [String: String]) {
    self.values = values
  }

  public init(path: String, delimiter: String = "=") throws {
    let content = try String(contentsOfFile: path)
    try self.init(content: content, delimiter: delimiter)
  }

  public init(content: String, delimiter: String = "=") throws {

    // Define the regex pattern using Swift's Regex
    let regex = Regex {
      Anchor.startOfLine
      ZeroOrMore(.whitespace)
      Capture {
        ChoiceOf {
          OneOrMore(.word)
          "_"
        }
      }

      "\(delimiter)"
        ChoiceOf {
            "\""
            ""
        }
      Capture {
        OneOrMore {
          NegativeLookahead { "\"" }
          CharacterClass.any
        }
      }
        ChoiceOf {
            "\""
            ""
        }
    }

    var values: [String: String] = [:]

    // Iterate over all matches and extract the tokens
    for match in content.matches(of: regex) {
      let (_, key, value) = match.output
      values["\(key)".camelCaseToSnakeCase()] = "\(value)"
    }
    self.init(values: values)
  }

  /// Read or write environment variables.
  public subscript(dynamicMember member: String) -> Value? {
    get {
      let key = member.camelCaseToSnakeCase()

      guard values.keys.contains(key) else {
        logger.error(
          """
          Environment has no key for 
          original: [\"\(member)\"] not found. 
          converted: [\"\(key)\"] not found.

          Available keys are [\(values.keys.sorted().joined(separator: ", "))]
          """)
        return nil
      }
      return Value(values[key])
    }
    set {
      var mutableValues = values
      let key = member.camelCaseToSnakeCase()
      if let newValue = newValue {
        mutableValues[key] = newValue.stringValue
      } else {
        mutableValues.removeValue(forKey: key)
      }
      self = Dotenv(values: mutableValues)
    }
  }

  // MARK: - Create process with environment set

  public func createProcessWithDotenv() -> Process {
    let process = Process()
    process.environment = values
    return process
  }
  public static func createProcessWithDotenv() async -> Process {
    let process = Process()
    guard let dotEnv = Dotenv.current else {
      logger.warning(
        "No Dotenv set on Dotenv.current, load it with Dotenv.$current.withValue(Dontenv(...) { ...}."
      )
      return process
    }
    process.environment = dotEnv.values
    return process
  }

  // MARK: - Types

  /// Type-safe representation of the value types in a `.env` file.
  public enum Value: Equatable {
    /// Reprensents a boolean value, `true`, or `false`.
    case boolean(Bool)
    /// Represents any double literal.
    case double(Double)
    /// Represents any integer literal.
    case integer(Int)
    /// Represents any string literal.
    case string(String)

    /// Convert a value to its string representation.
    public var stringValue: String {
      switch self {
      case let .boolean(value):
        return String(describing: value)
      case let .double(value):
        return String(describing: value)
      case let .integer(value):
        return String(describing: value)
      case let .string(value):
        return value
      }
    }

    /// Create a value from a string value.
    /// - Parameter stringValue: String value.
    init?(_ stringValue: String?) {
      guard let stringValue else {
        return nil
      }
      // order of operations is important, double should get checked before integer
      // because integer's downcasting is more permissive
      if let boolValue = Bool(stringValue) {
        self = .boolean(boolValue)
        // enforcing exclusion on the double conversion
      } else if let doubleValue = Double(stringValue), Int(stringValue) == nil {
        self = .double(doubleValue)
      } else if let integerValue = Int(stringValue) {
        self = .integer(integerValue)
      } else {
        // replace escape double quotes
        self = .string(
          stringValue.trimmingCharacters(in: .init(charactersIn: "\"")).replacingOccurrences(
            of: "\\\"", with: "\""))
      }
    }

    // MARK: - Equatable

    public static func == (lhs: Value, rhs: Value) -> Bool {
      switch (lhs, rhs) {
      case let (.boolean(a), .boolean(b)):
        return a == b
      case let (.double(a), .double(b)):
        return a == b
      case let (.integer(a), .integer(b)):
        return a == b
      case let (.string(a), .string(b)):
        return a == b
      default:
        return false
      }
    }
  }

  // MARK: Errors

  /// Failures that can occur during loading an environment.
  public enum LoadingFailure: Error {
    /// The environment file is not at the path given.
    case environmentFileIsMissing
    /// The environment ifle is in some way malformed.
    case unableToReadEnvironmentFile
  }

  /// Represents errors that can occur during encoding.
  public enum DecodingFailure: Error {
    // the key value pair is in some way malformed
    case malformedKeyValuePair(atLine: Int, lineContent: String)
    /// Either the key or value is empty.
    case emptyKeyValuePair(pair: (String, String))
  }

}
