import PackagePlugin
import Foundation

@main
struct UnzipXCFrameworkPlugin: CommandPlugin {
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

        // Create a script to handle building/unzipping frameworks
        let scriptPath = context.pluginWorkDirectory.appending("setup_frameworks.sh")

        let scriptContent = """
        #!/bin/bash
        set -e

        XCFRAMEWORK_DIR="\(xcframeworkDir.string)"
        SCRIPTS_DIR="\(scriptsDir.string)"
        PACKAGE_DIR="\(packageDir.string)"

        # Detect architecture
        ARCH=$(uname -m)
        if [ "$ARCH" = "arm64" ]; then
            PLATFORM_ID="macos-arm64"
            ARCH_NAME="arm64"
        elif [ "$ARCH" = "x86_64" ]; then
            PLATFORM_ID="macos-x86_64"
            ARCH_NAME="x86_64"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi

        cd "$XCFRAMEWORK_DIR"

        # First, try to unzip existing zips
        for zip in *.zip; do
            if [ -f "$zip" ]; then
                framework="${zip%.zip}.xcframework"
                if [ ! -d "$framework" ]; then
                    echo "Unzipping $zip..."
                    unzip -q -o "$zip"
                fi
            fi
        done

        # Check if all frameworks now exist
        FRAMEWORKS="libavcodec libavdevice libavfilter libavformat libavutil libpostproc libswresample libswscale"
        MISSING_FRAMEWORKS=""

        for lib in $FRAMEWORKS; do
            if [ ! -d "$lib.xcframework" ]; then
                MISSING_FRAMEWORKS="$MISSING_FRAMEWORKS $lib"
            fi
        done

        # If frameworks are still missing, we need to build them
        if [ -n "$MISSING_FRAMEWORKS" ]; then
            echo "Missing frameworks:$MISSING_FRAMEWORKS"
            echo "Building frameworks from source..."

            # Check if build script exists
            if [ ! -f "$SCRIPTS_DIR/build.sh" ] || [ ! -f "$SCRIPTS_DIR/build_framework.sh" ]; then
                echo "Error: Build scripts not found in $SCRIPTS_DIR"
                exit 1
            fi

            # Run the build script
            cd "$PACKAGE_DIR"
            bash "$SCRIPTS_DIR/build.sh"

            # Copy built frameworks to xcframework directory
            PREFIX="$PACKAGE_DIR/output"

            for lib in $MISSING_FRAMEWORKS; do
                if [ -d "$PREFIX/xcframework/$lib.xcframework" ]; then
                    echo "Copying $lib.xcframework to $XCFRAMEWORK_DIR"
                    cp -R "$PREFIX/xcframework/$lib.xcframework" "$XCFRAMEWORK_DIR/"
                fi
            done
        fi

        echo "All frameworks are ready."
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
