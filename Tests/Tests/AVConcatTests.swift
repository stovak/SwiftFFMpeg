//
//  AVConcatTests.swift
//  Tests
//
//  Tests for AVConcat functionality using fixtures.
//

import XCTest
@testable import SwiftFFmpeg

final class AVConcatTests: XCTestCase {

  static var allTests = [
    ("testConcatMultipleFixtures", testConcatMultipleFixtures),
    ("testConcatWithNarratorFixtures", testConcatWithNarratorFixtures),
  ]

  func testConcatMultipleFixtures() throws {
    try skipIfFixturesUnavailable()

    let cafFixtures = FixtureManager.fixtures(withExtension: "caf")
    guard cafFixtures.count >= 3 else {
      throw XCTSkip("Not enough CAF fixtures for concatenation test")
    }

    // Take first 3 fixtures
    let inputFixtures = Array(cafFixtures.prefix(3))

    // Create temporary directory for test
    let tempDir = FileManager.default.temporaryDirectory
    let outputFile = tempDir.appendingPathComponent("concat_output_\(UUID().uuidString).caf")
    defer {
      try? FileManager.default.removeItem(at: outputFile)
    }

    // Test concatenation
    let inputPaths = inputFixtures.map { $0.path }
    XCTAssertNoThrow(
      try AVConcat.concat(inputFiles: inputPaths, outputFile: outputFile.path),
      "Concatenation should succeed"
    )

    // Verify output file was created
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path))

    // Verify output file has non-zero size
    let attributes = try FileManager.default.attributesOfItem(atPath: outputFile.path)
    let outputSize = attributes[.size] as? UInt64 ?? 0
    XCTAssertGreaterThan(outputSize, 0, "Output file should have content")

    print("Concatenated \(inputFixtures.count) fixtures into output file of size: \(outputSize) bytes")
  }

  func testConcatWithNarratorFixtures() throws {
    try skipIfFixturesUnavailable()

    // Get all narrator fixtures
    let narratorFixtures = FixtureManager.fixtures(in: .narrator)
    guard narratorFixtures.count >= 2 else {
      throw XCTSkip("Not enough narrator fixtures for test")
    }

    // Take first 2 narrator fixtures
    let inputFixtures = Array(narratorFixtures.prefix(2))

    let tempDir = FileManager.default.temporaryDirectory
    let outputFile = tempDir.appendingPathComponent("narrator_concat_\(UUID().uuidString).caf")
    defer {
      try? FileManager.default.removeItem(at: outputFile)
    }

    let inputPaths = inputFixtures.map { $0.path }

    XCTAssertNoThrow(
      try AVConcat.concat(inputFiles: inputPaths, outputFile: outputFile.path),
      "Narrator concatenation should succeed"
    )

    XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path))

    // Read and verify the output using AVFormatContext
    XCTAssertNoThrow(
      try {
        let formatContext = try AVFormatContext(url: outputFile.path)
        try formatContext.findStreamInfo()

        // Verify we have at least one stream
        XCTAssertGreaterThan(formatContext.streamCount, 0, "Output should have at least one stream")

        print("Output format: \(formatContext.inputFormat?.name ?? "unknown")")
        print("Streams: \(formatContext.streamCount)")
        print("Duration: \(formatContext.duration)")
      }()
    )
  }

  func testInvalidInputHandling() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let outputFile = tempDir.appendingPathComponent("invalid_output.caf")
    defer {
      try? FileManager.default.removeItem(at: outputFile)
    }

    // Test with empty input array
    XCTAssertThrowsError(
      try AVConcat.concat(inputFiles: [], outputFile: outputFile.path),
      "Empty input array should throw error"
    )

    // Test with non-existent files
    let nonExistentFiles = ["/path/to/nonexistent1.caf", "/path/to/nonexistent2.caf"]
    XCTAssertThrowsError(
      try AVConcat.concat(inputFiles: nonExistentFiles, outputFile: outputFile.path),
      "Non-existent files should throw error"
    )
  }
}
