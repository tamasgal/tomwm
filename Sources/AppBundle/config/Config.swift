import AppKit
import Common
import HotKey
import OrderedCollections

func getDefaultConfigUrlFromProject() -> URL {
    var url = URL(filePath: #filePath)
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    let projectRoot: URL = url
    return projectRoot.appending(component: "docs/config-examples/default-config.toml")
}

var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
@MainActor let defaultConfig: Config = {
    let parsedConfig = parseConfig(Result { try String(contentsOf: defaultConfigUrl, encoding: .utf8) }.getOrDie())
    if !parsedConfig.errors.isEmpty {
        die("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()
@MainActor var config: Config = defaultConfig // todo move to Ctx?
@MainActor var configUrl: URL = defaultConfigUrl

struct Config: ConvenienceMutable {
    var _configVersion: Void = ()
    var _afterLoginCommand: [any Command] = []
    var afterStartupCommand: Shell<any Command> = .empty
    var _indentForNestedContainersWithTheSameOrientation: Void = ()
    var _enableNormalizationFlattenContainers: Void = ()
    var _enableNormalizationOppositeOrientationForNestedContainers: Void = ()
    var _nonEmptyWorkspacesRootContainersLayoutOnStartup: Void = ()
    var _defaultRootContainerLayout: Void = ()
    var _defaultRootContainerOrientation: Void = ()
    var _accordionPadding: Void = ()
    var _persistentWorkspaces: Void = ()
    var _execOnWorkspaceChange: Void = ()
    var _workspaceToMonitorForceAssignment: Void = ()
    /// The tags every monitor can show. Bit i of a ``TagMask`` is `tags[i]`.
    var tags: [String] = ["base", "web", "dev", "doc", "img", "vid", "mus", "eml", "foo"]
    var defaultLayout: TomLayout = .tile
    var nmaster: Int = 1
    var mfact: Double = 0.5
    var startAtLogin: Bool = false
    var autoReloadConfig: Bool = false
    var automaticallyUnhideMacosHiddenApps: Bool = false
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()
    var focusFollowsMouse: FocusFollowsMouse = FocusFollowsMouse()

    var onFocusChanged: Shell<any Command> = .empty
    // var onFocusedWorkspaceChanged: [any Command] = []
    var onFocusedMonitorChanged: Shell<any Command> = .empty

    var gaps: Gaps = .zero
    var modes: [String: Mode] = [:]
    var onWindowDetected: [WindowDetectedCallback] = []
    var onModeChanged: Shell<any Command> = .empty
}

struct FocusFollowsMouse: ConvenienceMutable {
    var enabled: Bool = false
}
