import Common

public struct ServerEvent: Codable, Sendable {
    private let _event: ServerEventType

    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var windowId: UInt32?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var tags: [String]?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var prevTags: [String]?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var monitorId: Int? // 1-based
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var appBundleId: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var appName: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var mode: String?
    // periphery:ignore - false positive unused warning. The var properties are serialized to JSON
    private var binding: String?

    public var eventType: ServerEventType { _event }

    public static func focusChanged(windowId: UInt32?, tags: [String]) -> ServerEvent {
        ServerEvent(_event: .focusChanged, windowId: windowId, tags: tags)
    }

    public static func focusedMonitorChanged(tags: [String], monitorId_oneBased: Int) -> ServerEvent {
        ServerEvent(_event: .focusedMonitorChanged, tags: tags, monitorId: monitorId_oneBased)
    }

    public static func tagsChanged(tags: [String], prevTags: [String]) -> ServerEvent {
        ServerEvent(_event: .tagsChanged, tags: tags, prevTags: prevTags)
    }

    public static func modeChanged(mode: String?) -> ServerEvent {
        ServerEvent(_event: .modeChanged, mode: mode)
    }

    public static func windowDetected(windowId: UInt32, tags: [String], appBundleId: String?, appName: String?) -> ServerEvent {
        ServerEvent(_event: .windowDetected, windowId: windowId, tags: tags, appBundleId: appBundleId, appName: appName)
    }

    public static func bindingTriggered(mode: String, binding: String) -> ServerEvent {
        ServerEvent(_event: .bindingTriggered, mode: mode, binding: binding)
    }
}
