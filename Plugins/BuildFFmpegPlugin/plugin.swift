import PackagePlugin
import Foundation

@main
struct BuildFFmpegPlugin: CommandPlugin {
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

        // If all frameworks exist and --force is not specified
        let forceRebuild = arguments.contains("--force")
        if frameworksExist(in: xcframeworkDir, names: frameworkNames) && !forceRebuild {
            print("All frameworks already exist. Use --force to rebuild.")
            return
        }

        // Try downloading the latest prebuilt XCFrameworks bundle first
        if try downloadPrebuiltFrameworks(
            scriptsDir: scriptsDir,
            xcframeworkDir: xcframeworkDir,
            frameworkNames: frameworkNames
        ) {
            return
        }

        try buildFrameworksFromSource(
            context: context,
            packageDir: packageDir,
            scriptsDir: scriptsDir,
            xcframeworkDir: xcframeworkDir
        )

        print("XCFrameworks setup complete!")
    }

    private func frameworksExist(in directory: Path, names: [String]) -> Bool {
        let fileManager = FileManager.default
        for framework in names {
            let frameworkPath = directory.appending("\(framework).xcframework")
            if !fileManager.fileExists(atPath: frameworkPath.string) {
                return false
            }
        }
        return true
    }

    private func downloadPrebuiltFrameworks(
        scriptsDir: Path,
        xcframeworkDir: Path,
        frameworkNames: [String]
    ) throws -> Bool {
        let downloadScript = scriptsDir.appending("download_latest_xcframeworks.py")
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: downloadScript.string) else {
            return false
        }

        let environment = ProcessInfo.processInfo.environment
        let hasToken = environment["FFMPEG_FRAMEWORK_TOKEN"] != nil || environment["GITHUB_TOKEN"] != nil
        if !hasToken {
            print("No GitHub token provided (FFMPEG_FRAMEWORK_TOKEN or GITHUB_TOKEN). Skipping prebuilt download.")
            return false
        }

        print("Attempting to download prebuilt FFmpeg XCFrameworks…")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            downloadScript.string,
            xcframeworkDir.string
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            print("Failed to launch download script: \(error). Falling back to source build.")
            return false
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print(output)
        }

        if process.terminationStatus == 0 && frameworksExist(in: xcframeworkDir, names: frameworkNames) {
            print("Prebuilt FFmpeg XCFrameworks downloaded successfully.")
            return true
        }

        print("Prebuilt download failed or incomplete. Falling back to building from source.")
        return false
    }

    private func buildFrameworksFromSource(
        context: PluginContext,
        packageDir: Path,
        scriptsDir: Path,
        xcframeworkDir: Path
    ) throws {
        print("Setting up XCFrameworks from source build…")

        // Create a script to build frameworks from FFmpeg source
        let scriptPath = context.pluginWorkDirectory.appending("build_frameworks.sh")

        let scriptContent = """
        #!/bin/bash
        set -e

        XCFRAMEWORK_DIR="\(xcframeworkDir.string)"
        SCRIPTS_DIR="\(scriptsDir.string)"
        PACKAGE_DIR="\(packageDir.string)"

        echo "Building FFmpeg frameworks from source..."
        echo "This will clone FFmpeg 7.1 and compile for your architecture."
        echo ""

        # Check if build script exists
        if [ ! -f "$SCRIPTS_DIR/build.sh" ]; then
            echo "Error: Build script not found at $SCRIPTS_DIR/build.sh"
            exit 1
        fi

        # Run the build script
        cd "$PACKAGE_DIR"
        bash "$SCRIPTS_DIR/build.sh"

        # Create xcframework directory if it doesn't exist
        mkdir -p "$XCFRAMEWORK_DIR"

        # Copy built frameworks to xcframework directory
        PREFIX="$PACKAGE_DIR/output"

        if [ -d "$PREFIX/xcframework" ]; then
            echo ""
            echo "Copying frameworks to $XCFRAMEWORK_DIR..."
            cp -R "$PREFIX/xcframework/"* "$XCFRAMEWORK_DIR/" || true
            echo "Done!"
        else
            echo "Error: No frameworks found in $PREFIX/xcframework"
            exit 1
        fi

        echo ""
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.string]

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
    }
}

enum PluginError: Error {
    case buildFailed
}
