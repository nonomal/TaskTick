import Foundation

/// Localization helper.
///
/// SPM `.process()` may lowercase directory names (e.g. `zh-Hans.lproj` -> `zh-hans.lproj`),
/// so we do a case-insensitive search for the correct `.lproj` bundle.
public enum L10n {
    /// Safe resource bundle lookup — searches multiple locations, never crashes.
    private static let _resourceBundle: Bundle = {
        let bundleName = "TaskTick_TaskTickCore.bundle"
        var candidates: [URL] = [
            // 1. App root (alongside Contents/) — standard SPM placement
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            // 2. Inside Contents/Resources/
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName)"),
        ]

        // 3+4: probe relative to BOTH the raw and the symlink-resolved
        // executable path. When the CLI is invoked via a PATH symlink
        // (e.g. /opt/homebrew/bin/tasktick → .app/Contents/cli/tasktick,
        // which is how the Homebrew cask installs it), Bundle.main points
        // at the symlink's directory, not the real binary inside the .app —
        // so the raw candidates miss the bundle that ships at the .app root.
        // resolvingSymlinksInPath() climbs back into the .app. (Same lesson
        // as BundleContext.bundleIDFromEnclosingApp.)
        let execURLs = [
            Bundle.main.executableURL,
            Bundle.main.executableURL?.resolvingSymlinksInPath(),
        ].compactMap { $0 }
        for exec in execURLs {
            let execDir = exec.deletingLastPathComponent()
            // Same directory as the executable
            candidates.append(execDir.appendingPathComponent(bundleName))
            // Two levels up (Contents/{MacOS,cli}/<bin> → .app root)
            candidates.append(execDir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(bundleName))
        }

        // 5. Nearest .app ancestor of the resolved executable — robust to the
        // CLI living at Contents/cli/ or Contents/MacOS/ at any depth.
        if let resolvedExec = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            var current = resolvedExec
            for _ in 0..<current.pathComponents.count {
                current.deleteLastPathComponent()
                if current.pathExtension == "app" {
                    candidates.append(current.appendingPathComponent(bundleName))
                    candidates.append(current.appendingPathComponent("Contents/Resources/\(bundleName)"))
                    break
                }
            }
        }

        for url in candidates {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }

        // Last resort: try SPM-generated Bundle.module (may fatalError, but we tried everything else)
        return Bundle.module
    }()

    nonisolated(unsafe) private static var _bundle: Bundle = {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        let lang = AppLanguage(rawValue: saved) ?? .system
        return findBundle(for: lang.resolvedCode) ?? _resourceBundle
    }()

    public static func reloadBundle(for language: AppLanguage) {
        let code = language.resolvedCode
        _bundle = findBundle(for: code) ?? _resourceBundle
    }

    /// Case-insensitive search for .lproj bundle inside the resource bundle
    private static func findBundle(for code: String) -> Bundle? {
        // Try exact match first
        if let path = _resourceBundle.path(forResource: code, ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }

        // Fallback: scan the bundle directory for case-insensitive match
        let target = "\(code).lproj".lowercased()
        let bundleURL = _resourceBundle.bundleURL
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: bundleURL, includingPropertiesForKeys: nil
        ) {
            for url in contents {
                if url.lastPathComponent.lowercased() == target {
                    return Bundle(url: url)
                }
            }
        }

        return nil
    }

    public static func tr(_ key: String) -> String {
        let s = NSLocalizedString(key, tableName: nil, bundle: _bundle, value: __missingMarker, comment: "")
        if s == __missingMarker {
            // Cross-language fallback: try the en bundle directly.
            if let enBundle = Self.findBundle(for: "en") {
                return NSLocalizedString(key, tableName: nil, bundle: enBundle, value: key, comment: "")
            }
            return key
        }
        return s
    }

    public static func tr(_ key: String, _ args: any CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, arguments: args)
    }

    private static let __missingMarker = "__TT_MISSING_TRANSLATION__"
}
