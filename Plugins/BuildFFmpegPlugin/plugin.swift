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

        // Check if .xcframework directories already exist
        var allExist = true
        for framework in frameworkNames {
            let frameworkPath = xcframeworkDir.appending("\(framework).xcframework")
            if !FileManager.default.fileExists(atPath: frameworkPath.string) {
                allExist = false
                break
            }
        }

        // If all frameworks exist and --force is not specified
        let forceRebuild = arguments.contains("--force")
        if allExist && !forceRebuild {
            print("All frameworks already exist. Use --force to rebuild.")
            return
        }

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
        print("Setting up XCFrameworks...")
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

        print("XCFrameworks setup complete!")
    }
}

enum PluginError: Error {
    case buildFailed
}
