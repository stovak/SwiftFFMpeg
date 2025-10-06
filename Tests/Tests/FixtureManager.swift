//
//  FixtureManager.swift
//  Tests
//
//  Provides access to test fixtures for SwiftFFmpeg tests.
//

import Foundation
import XCTest

/// Manages access to test fixtures located in the Fixtures directory.
public struct FixtureManager {

  /// The root directory containing all fixtures.
  public static var fixturesDirectory: URL {
    let currentFile = URL(fileURLWithPath: #file)
    let testsDirectory = currentFile.deletingLastPathComponent().deletingLastPathComponent()
    let projectRoot = testsDirectory.deletingLastPathComponent()
    return projectRoot.appendingPathComponent("Fixtures")
  }

  /// Category of fixture files based on naming convention.
  public enum FixtureCategory: String, CaseIterable {
    case action = "action"
    case narrator = "NARRATOR"

    /// Returns all fixtures matching this category.
    public var fixtures: [Fixture] {
      FixtureManager.allFixtures.filter { $0.category == self }
    }
  }

  /// Represents a single fixture file.
  public struct Fixture {
    /// The index number from the filename (e.g., "000", "001").
    public let index: Int

    /// The category (action or narrator).
    public let category: FixtureCategory

    /// The descriptive name from the filename.
    public let name: String

    /// The file extension.
    public let fileExtension: String

    /// The full URL to the fixture file.
    public let url: URL

    /// The filename without extension.
    public var filename: String {
      url.deletingPathExtension().lastPathComponent
    }

    /// Convenience accessor for the file path.
    public var path: String {
      url.path
    }

    /// Check if the fixture file exists.
    public var exists: Bool {
      FileManager.default.fileExists(atPath: path)
    }

    /// Get file size in bytes.
    public var fileSize: UInt64? {
      guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let size = attributes[.size] as? UInt64 else {
        return nil
      }
      return size
    }
  }

  /// Get all available fixtures.
  public static var allFixtures: [Fixture] {
    guard let fileURLs = try? FileManager.default.contentsOfDirectory(
      at: fixturesDirectory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: .skipsHiddenFiles
    ) else {
      return []
    }

    return fileURLs.compactMap { url -> Fixture? in
      let filename = url.deletingPathExtension().lastPathComponent
      let components = filename.components(separatedBy: "_")

      guard components.count >= 2,
            let index = Int(components[0]),
            let category = FixtureCategory(rawValue: components[1]) else {
        return nil
      }

      let name = components.dropFirst(2).joined(separator: "_")
      let fileExtension = url.pathExtension

      return Fixture(
        index: index,
        category: category,
        name: name,
        fileExtension: fileExtension,
        url: url
      )
    }.sorted { $0.index < $1.index }
  }

  /// Get fixtures matching a specific category.
  ///
  /// - Parameter category: The category to filter by.
  /// - Returns: Array of fixtures in that category.
  public static func fixtures(in category: FixtureCategory) -> [Fixture] {
    allFixtures.filter { $0.category == category }
  }

  /// Get a fixture by its index.
  ///
  /// - Parameter index: The fixture index (e.g., 0 for "000_...").
  /// - Returns: The fixture if found, nil otherwise.
  public static func fixture(at index: Int) -> Fixture? {
    allFixtures.first { $0.index == index }
  }

  /// Get fixtures matching a name pattern.
  ///
  /// - Parameter pattern: The pattern to match against fixture names (case-insensitive).
  /// - Returns: Array of matching fixtures.
  public static func fixtures(matching pattern: String) -> [Fixture] {
    allFixtures.filter { $0.name.localizedCaseInsensitiveContains(pattern) }
  }

  /// Get fixtures with a specific file extension.
  ///
  /// - Parameter extension: The file extension (without the dot).
  /// - Returns: Array of matching fixtures.
  public static func fixtures(withExtension ext: String) -> [Fixture] {
    allFixtures.filter { $0.fileExtension.lowercased() == ext.lowercased() }
  }

  /// Get the first available fixture (useful for simple tests).
  public static var firstFixture: Fixture? {
    allFixtures.first
  }

  /// Get a random fixture (useful for randomized testing).
  public static var randomFixture: Fixture? {
    allFixtures.randomElement()
  }

  /// Verify that the fixtures directory exists and contains files.
  ///
  /// - Throws: XCTFail if fixtures are not available.
  public static func verifyFixturesExist() throws {
    let fixturesExist = FileManager.default.fileExists(atPath: fixturesDirectory.path)
    guard fixturesExist else {
      XCTFail("Fixtures directory not found at: \(fixturesDirectory.path)")
      return
    }

    guard !allFixtures.isEmpty else {
      XCTFail("No fixtures found in directory: \(fixturesDirectory.path)")
      return
    }
  }

  /// Copy a fixture to a temporary location for testing.
  ///
  /// - Parameter fixture: The fixture to copy.
  /// - Returns: URL of the temporary copy.
  /// - Throws: Error if copy fails.
  public static func temporaryCopy(of fixture: Fixture) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent(fixture.url.lastPathComponent)

    // Remove existing file if present
    try? FileManager.default.removeItem(at: tempFile)

    try FileManager.default.copyItem(at: fixture.url, to: tempFile)
    return tempFile
  }

  /// Create a temporary directory with multiple fixture copies.
  ///
  /// - Parameter fixtures: The fixtures to copy.
  /// - Returns: URL of the temporary directory containing copies.
  /// - Throws: Error if copy fails.
  public static func temporaryDirectory(withFixtures fixtures: [Fixture]) throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftFFmpegTest_\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    for fixture in fixtures {
      let destination = tempDir.appendingPathComponent(fixture.url.lastPathComponent)
      try FileManager.default.copyItem(at: fixture.url, to: destination)
    }

    return tempDir
  }
}

// MARK: - XCTestCase Extension

extension XCTestCase {

  /// Convenience property to access fixtures from any test case.
  public var fixtures: FixtureManager.Type {
    FixtureManager.self
  }

  /// Skip test if fixtures are not available.
  public func skipIfFixturesUnavailable() throws {
    try FixtureManager.verifyFixturesExist()
  }
}

// MARK: - CustomStringConvertible

extension FixtureManager.Fixture: CustomStringConvertible {
  public var description: String {
    "\(String(format: "%03d", index))_\(category.rawValue)_\(name).\(fileExtension)"
  }
}

extension FixtureManager.Fixture: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    Fixture(
      index: \(index),
      category: \(category.rawValue),
      name: "\(name)",
      extension: \(fileExtension),
      path: \(path),
      exists: \(exists),
      size: \(fileSize.map { "\($0) bytes" } ?? "unknown")
    )
    """
  }
}
