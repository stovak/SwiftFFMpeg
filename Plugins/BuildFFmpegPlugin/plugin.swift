import PackagePlugin
@preconcurrency import Foundation

@main
struct BuildFFmpegPlugin: CommandPlugin {
    @MainActor
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let packageDir = context.package.directory
        let xcframeworkDir = packageDir.appending("xcframework")
        let scriptsDir = packageDir.appending("Scripts")

        let frameworkNames = [
            "libavcodec",
            "libavdevice",
            "libavfilter",
            "libavformat",
            "libavutil",
            "libpostproc",
            "libswresample",
            "libswscale"
        ]

        var requestedArchs: [String] = []
        var forceRebuild = false
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--force":
                forceRebuild = true
            case "--arch":
                guard let value = iterator.next() else { throw PluginError.missingArchitectureValue }
                requestedArchs.append(value)
            default:
                throw PluginError.unknownArgument(argument)
            }
        }

        if requestedArchs.isEmpty {
            requestedArchs.append(try Self.detectHostArchitecture())
        }

        // Check if .xcframework directories already exist
        var allExist = true
        for framework in frameworkNames {
            let frameworkPath = xcframeworkDir.appending("\(framework).xcframework")
            if !FileManager.default.fileExists(atPath: frameworkPath.string) {
                allExist = false
                break
            }
        }

        if allExist && !forceRebuild {
            print("All frameworks already exist. Use --force to rebuild.")
            return
        }

        let scriptPath = context.pluginWorkDirectory.appending("build_frameworks.sh")

        let archList = requestedArchs.joined(separator: " ")

        let scriptContent = """
        #!/bin/bash
        set -euo pipefail

        XCFRAMEWORK_DIR="\(xcframeworkDir.string)"
        SCRIPTS_DIR="\(scriptsDir.string)"
        PACKAGE_DIR="\(packageDir.string)"

        echo "Building FFmpeg frameworks from the official source archive..."
        echo "Architectures: \(archList.isEmpty ? "default" : archList)"
        echo ""

        if [ ! -f "$SCRIPTS_DIR/build.sh" ]; then
            echo "Error: Build script not found at $SCRIPTS_DIR/build.sh"
            exit 1
        fi

        ARCHS="\(archList)"

        cd "$PACKAGE_DIR"
        if [ -n "$ARCHS" ]; then
            ARCHS="$ARCHS" bash "$SCRIPTS_DIR/build.sh"
        else
            bash "$SCRIPTS_DIR/build.sh"
        fi

        mkdir -p "$XCFRAMEWORK_DIR"

        PREFIX="${FFMPEG_OUTPUT_DIR:-$PACKAGE_DIR/output}"

        if [ -d "$PREFIX/xcframework" ]; then
            echo "Copying frameworks to $XCFRAMEWORK_DIR..."
            rsync -a "$PREFIX/xcframework/" "$XCFRAMEWORK_DIR/"
            echo "Done!"
        else
            echo "Error: No frameworks found in $PREFIX/xcframework"
            exit 1
        fi

        echo "All frameworks are ready in $XCFRAMEWORK_DIR"
        """

        try scriptContent.write(toFile: scriptPath.string, atomically: true, encoding: .utf8)

        // Make script executable
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: scriptPath.string)
        var permissions = attributes[.posixPermissions] as! NSNumber
        permissions = NSNumber(value: permissions.uint16Value | 0o111) // Add execute permission
        try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: scriptPath.string)

        // Execute the script
        print("Setting up XCFrameworks...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.string]

        var environment = ProcessInfo.processInfo.environment
        environment["FFMPEG_CACHE_DIR"] = context.pluginWorkDirectory.appending("cache").string
        environment["FFMPEG_OUTPUT_DIR"] = context.pluginWorkDirectory.appending("output").string
        environment["FFMPEG_BUILD_ROOT_BASE"] = context.pluginWorkDirectory.appending("build").string
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print(output)
        }

        if process.terminationStatus != 0 {
            throw PluginError.buildFailed
        }

        print("XCFrameworks setup complete!")
    }
    @MainActor
    private static func detectHostArchitecture() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/uname")
        process.arguments = ["-m"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PluginError.buildFailed
        }

        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            throw PluginError.buildFailed
        }

        return output
    }
}

enum PluginError: Error {
    case buildFailed
    case unknownArgument(String)
    case missingArchitectureValue
}

extension PluginError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .buildFailed:
            return "FFmpeg build failed. Check the script output for details."
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        case .missingArchitectureValue:
            return "Missing value for --arch option"
        }
    }
}
