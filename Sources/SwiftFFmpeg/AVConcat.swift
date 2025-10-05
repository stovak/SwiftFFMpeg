//
//  AVConcat.swift
//  SwiftFFmpeg
//
//  Concatenation utilities for audio and video files.
//

import Foundation
import CFFmpeg

/// Utilities for concatenating multiple audio or video files.
public struct AVConcat {

  /// Concatenates multiple media files into a single output file using FFmpeg's concat demuxer.
  ///
  /// This method creates a temporary concat list file and uses FFmpeg's concat demuxer protocol
  /// to efficiently combine multiple files without re-encoding (when all inputs have identical
  /// codec parameters and formats).
  ///
  /// - Parameters:
  ///   - inputFiles: Array of input file paths to concatenate.
  ///   - outputFile: Path to the output file.
  ///   - options: Optional dictionary of AVFormatContext options.
  /// - Throws: AVError if concatenation fails.
  ///
  /// - Note: All input files should have the same streams (same codecs, timebases, etc.)
  ///         for best results. If streams differ, consider using the filter-based approach.
  public static func concat(
    inputFiles: [String],
    outputFile: String,
    options: [String: String]? = nil
  ) throws {
    guard inputFiles.count > 0 else {
      throw AVError.invalidArgument
    }

    // Create a temporary concat list file
    let tempDir = FileManager.default.temporaryDirectory
    let listFile = tempDir.appendingPathComponent("ffmpeg_concat_\(UUID().uuidString).txt")

    defer {
      try? FileManager.default.removeItem(at: listFile)
    }

    // Write the concat list
    var listContent = ""
    for inputFile in inputFiles {
      // Escape single quotes in filenames and use absolute paths
      let absolutePath = URL(fileURLWithPath: inputFile).path
      let escapedPath = absolutePath.replacingOccurrences(of: "'", with: "'\\''")
      listContent += "file '\(escapedPath)'\n"
    }

    try listContent.write(to: listFile, atomically: true, encoding: .utf8)

    // Open input using concat demuxer
    var inputOptions = options ?? [:]
    inputOptions["safe"] = "0"  // Allow absolute paths

    let ifmtCtx = try AVFormatContext(
      url: "concat:\(listFile.path)",
      format: AVInputFormat(name: "concat"),
      options: inputOptions
    )

    try ifmtCtx.findStreamInfo()

    // Create output context
    let ofmtCtx = try AVFormatContext(format: nil, filename: outputFile)

    // Copy stream information
    for i in 0..<ifmtCtx.streamCount {
      let istream = ifmtCtx.streams[i]
      guard let ostream = ofmtCtx.addStream() else {
        throw AVError.unknown
      }
      ostream.codecParameters.copy(from: istream.codecParameters)
      ostream.codecParameters.codecTag = 0
    }

    // Open output file
    if !ofmtCtx.outputFormat!.flags.contains(.noFile) {
      try ofmtCtx.openOutput(url: outputFile, flags: .write)
    }

    try ofmtCtx.writeHeader(options: options)

    // Copy packets
    let pkt = AVPacket()
    while let _ = try? ifmtCtx.readFrame(into: pkt) {
      defer { pkt.unref() }

      let istream = ifmtCtx.streams[pkt.streamIndex]
      let ostream = ofmtCtx.streams[pkt.streamIndex]

      // Rescale timestamps
      pkt.pts = AVMath.rescale(
        pkt.pts, istream.timebase, ostream.timebase, rounding: .nearInf, passMinMax: true)
      pkt.dts = AVMath.rescale(
        pkt.dts, istream.timebase, ostream.timebase, rounding: .nearInf, passMinMax: true)
      pkt.duration = AVMath.rescale(pkt.duration, istream.timebase, ostream.timebase)
      pkt.position = -1

      try ofmtCtx.interleavedWriteFrame(pkt)
    }

    try ofmtCtx.writeTrailer()
  }

  /// Concatenates multiple media files using the concat protocol (simpler, less control).
  ///
  /// This is a simpler approach using FFmpeg's concat protocol directly.
  ///
  /// - Parameters:
  ///   - inputFiles: Array of input file paths to concatenate (must be MPEG-compatible formats).
  ///   - outputFile: Path to the output file.
  /// - Throws: AVError if concatenation fails.
  ///
  /// - Note: This method works best with MPEG transport streams. For other formats,
  ///         use the `concat(inputFiles:outputFile:options:)` method.
  public static func concatProtocol(
    inputFiles: [String],
    outputFile: String
  ) throws {
    guard inputFiles.count > 0 else {
      throw AVError.invalidArgument
    }

    // Build concat protocol URL
    let concatUrl = "concat:" + inputFiles.joined(separator: "|")

    // Open input
    let ifmtCtx = try AVFormatContext(url: concatUrl)
    try ifmtCtx.findStreamInfo()

    // Create output context
    let ofmtCtx = try AVFormatContext(format: nil, filename: outputFile)

    // Copy stream information
    for i in 0..<ifmtCtx.streamCount {
      let istream = ifmtCtx.streams[i]
      guard let ostream = ofmtCtx.addStream() else {
        throw AVError.unknown
      }
      ostream.codecParameters.copy(from: istream.codecParameters)
      ostream.codecParameters.codecTag = 0
    }

    // Open output file
    if !ofmtCtx.outputFormat!.flags.contains(.noFile) {
      try ofmtCtx.openOutput(url: outputFile, flags: .write)
    }

    try ofmtCtx.writeHeader()

    // Copy packets
    let pkt = AVPacket()
    while let _ = try? ifmtCtx.readFrame(into: pkt) {
      defer { pkt.unref() }

      let istream = ifmtCtx.streams[pkt.streamIndex]
      let ostream = ofmtCtx.streams[pkt.streamIndex]

      // Rescale timestamps
      pkt.pts = AVMath.rescale(
        pkt.pts, istream.timebase, ostream.timebase, rounding: .nearInf, passMinMax: true)
      pkt.dts = AVMath.rescale(
        pkt.dts, istream.timebase, ostream.timebase, rounding: .nearInf, passMinMax: true)
      pkt.duration = AVMath.rescale(pkt.duration, istream.timebase, ostream.timebase)
      pkt.position = -1

      try ofmtCtx.interleavedWriteFrame(pkt)
    }

    try ofmtCtx.writeTrailer()
  }
}
