import PackagePlugin
import Foundation

@main
struct UnzipXCFrameworkPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let xcframeworkDir = context.package.directory.appending("xcframework")

        // Check if .xcframework directories already exist
        // If they do, skip unzipping to avoid permission errors
        let frameworkNames = [
            "libavcodec.xcframework",
            "libavdevice.xcframework",
            "libavfilter.xcframework",
            "libavformat.xcframework",
            "libavutil.xcframework",
            "libpostproc.xcframework",
            "libswresample.xcframework",
            "libswscale.xcframework"
        ]

        var allExist = true
        for framework in frameworkNames {
            let frameworkPath = xcframeworkDir.appending(framework)
            if !FileManager.default.fileExists(atPath: frameworkPath.string) {
                allExist = false
                break
            }
        }

        // If all frameworks exist, return empty command list
        if allExist {
            return []
        }

        // Otherwise, we need to unzip - create a script to do it
        let scriptPath = context.pluginWorkDirectory.appending("unzip_frameworks.sh")

        let scriptContent = """
        #!/bin/bash
        set -e

        cd "\(xcframeworkDir.string)"

        for zip in *.zip; do
            framework="${zip%.zip}.xcframework"
            if [ ! -d "$framework" ]; then
                echo "Unzipping $zip..."
                unzip -q -o "$zip"
            fi
        done
        """

        try scriptContent.write(toFile: scriptPath.string, atomically: true, encoding: .utf8)

        // Make script executable
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: scriptPath.string)
        var permissions = attributes[.posixPermissions] as! NSNumber
        permissions = NSNumber(value: permissions.uint16Value | 0o111) // Add execute permission
        try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: scriptPath.string)

        return [
            .prebuildCommand(
                displayName: "Unzipping XCFrameworks",
                executable: Path("/bin/bash"),
                arguments: [scriptPath.string],
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}
