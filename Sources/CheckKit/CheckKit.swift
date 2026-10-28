import Foundation

/// Minimal test harness usable without Xcode. Mirrors swift-testing's shape so cases port 1:1 later:
///   `check("name") { expect(x == y, "x should equal y") }`
public final class CheckRunner {
    public struct Failure { public let suite: String; public let name: String; public let message: String; public let file: String; public let line: Int }

    public static let shared = CheckRunner()
    private var failures: [Failure] = []
    private var passed = 0
    private var currentSuite = ""
    private var currentName = ""
    private var currentFailed = false

    public func suite(_ name: String, _ body: () throws -> Void) {
        currentSuite = name
        print("▶ \(name)")
        do { try body() } catch { record("suite threw: \(error)", file: #file, line: #line) }
    }

    public func check(_ name: String, file: String = #file, line: Int = #line, _ body: () throws -> Void) {
        currentName = name
        currentFailed = false
        do { try body() } catch { record("threw \(error)", file: file, line: line) }
        if currentFailed { print("  ✘ \(name)") } else { passed += 1; print("  ✔ \(name)") }
    }

    public func expect(_ condition: Bool, _ message: @autoclosure () -> String = "", file: String = #file, line: Int = #line) {
        if !condition { record(message(), file: file, line: line) }
    }

    public func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String = "", file: String = #file, line: Int = #line) {
        if a != b { record("expected \(b), got \(a). \(message())", file: file, line: line) }
    }

    private func record(_ message: String, file: String, line: Int) {
        currentFailed = true
        failures.append(Failure(suite: currentSuite, name: currentName, message: message, file: file, line: line))
        print("    ✘ \(message)  (\((file as NSString).lastPathComponent):\(line))")
    }

    /// Prints a summary and exits non-zero on failure.
    public func finish() -> Never {
        print("\n\(passed) passed, \(failures.count) failed")
        exit(failures.isEmpty ? 0 : 1)
    }
}

public func suite(_ name: String, _ body: () throws -> Void) { CheckRunner.shared.suite(name, body) }
public func check(_ name: String, file: String = #file, line: Int = #line, _ body: () throws -> Void) { CheckRunner.shared.check(name, file: file, line: line, body) }
public func expect(_ condition: Bool, _ message: @autoclosure () -> String = "", file: String = #file, line: Int = #line) { CheckRunner.shared.expect(condition, message(), file: file, line: line) }
public func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String = "", file: String = #file, line: Int = #line) { CheckRunner.shared.expectEqual(a, b, message(), file: file, line: line) }
