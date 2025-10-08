import PackagePlugin
import Foundation

@main
struct FetchFFmpegXCFrameworks: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let packageDir = context.package.directory
        let scriptsDir = packageDir.appending("Scripts")
        let scriptPath = scriptsDir.appending("download_latest_xcframeworks.py")
        let xcframeworkDir = packageDir.appending("xcframework")
        let forceDownload = arguments.contains("--force")

        guard FileManager.default.fileExists(atPath: scriptPath.string) else {
            throw PluginError.missingDownloadScript(path: scriptPath.string)
        }

        if !forceDownload && frameworksExist(at: xcframeworkDir) {
            print("Existing FFmpeg XCFrameworks found at \(xcframeworkDir.string). Use --force to re-download.")
            return
        }

        let environment = ProcessInfo.processInfo.environment
        if environment["FFMPEG_FRAMEWORK_TOKEN"] == nil && environment["GITHUB_TOKEN"] == nil {
            throw PluginError.missingToken
        }

        print("Downloading prebuilt FFmpeg XCFramework bundle…")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            scriptPath.string,
            xcframeworkDir.string
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: packageDir.string)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw PluginError.processLaunchFailed(underlying: error)
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        guard process.terminationStatus == 0 else {
            throw PluginError.downloadFailed(status: process.terminationStatus)
        }

        print("FFmpeg XCFrameworks downloaded to \(xcframeworkDir.string)")
    }
}

enum PluginError: Error, CustomStringConvertible {
    case missingDownloadScript(path: String)
    case missingToken
    case processLaunchFailed(underlying: Error)
    case downloadFailed(status: Int32)

    var description: String {
        switch self {
        case .missingDownloadScript(let path):
            return "Expected download helper script not found at \(path)."
        case .missingToken:
            return "Set FFMPEG_FRAMEWORK_TOKEN or GITHUB_TOKEN with actions:read scope before running the plugin."
        case .processLaunchFailed(let underlying):
            return "Failed to launch Python helper: \(underlying.localizedDescription)"
        case .downloadFailed(let status):
            return "Download helper exited with status \(status)."
        }
    }
}

private let expectedFrameworks = [
    "libavcodec.xcframework",
    "libavdevice.xcframework",
    "libavfilter.xcframework",
    "libavformat.xcframework",
    "libavutil.xcframework",
    "libpostproc.xcframework",
    "libswresample.xcframework",
    "libswscale.xcframework",
]

private func frameworksExist(at path: Path) -> Bool {
    let fm = FileManager.default
    for framework in expectedFrameworks {
        let frameworkPath = path.appending(framework)
        if !fm.fileExists(atPath: frameworkPath.string) {
            return false
        }
    }
    return true
}
