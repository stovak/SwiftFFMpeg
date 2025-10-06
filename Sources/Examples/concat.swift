//
//  concat.swift
//  Examples
//
//  Demonstrates concatenating multiple media files.
//

import Foundation
import SwiftFFmpeg

/// Concatenate multiple media files into a single output file.
func concat() throws {
  if CommandLine.argc < 4 {
    print("Usage: \(CommandLine.arguments[0]) \(CommandLine.arguments[1]) output_file input_file1 [input_file2 ...]")
    print("\nExample:")
    print("  \(CommandLine.arguments[0]) \(CommandLine.arguments[1]) output.mp4 video1.mp4 video2.mp4 video3.mp4")
    return
  }

  let outputFile = CommandLine.arguments[2]
  let inputFiles = Array(CommandLine.arguments[3...])

  print("Concatenating \(inputFiles.count) file(s):")
  for (index, file) in inputFiles.enumerated() {
    print("  \(index + 1). \(file)")
  }
  print("\nOutput: \(outputFile)")
  print("\nProcessing...")

  do {
    try AVConcat.concat(inputFiles: inputFiles, outputFile: outputFile)
    print("\n✓ Concatenation completed successfully!")
    print("Output saved to: \(outputFile)")
  } catch {
    print("\n✗ Error during concatenation: \(error)")
    throw error
  }
}
