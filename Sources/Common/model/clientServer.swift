import Foundation

public let SOCKET_PROTOCOL_VERSION: UInt32 = 1

public struct ServerAnswer: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public var stderr: String
    public let serverVersionAndHash: String

    public init(
        exitCode: Int32,
        stdout: String = "",
        stderr: String = "",
        serverVersionAndHash: String,
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.serverVersionAndHash = serverVersionAndHash
    }
}

public struct ClientRequest: Codable, Sendable, ConvenienceMutable, Equatable {
    // periphery:ignore - Unused. keep it for API compatibility with old servers for a couple of version
    public var command: String? = nil

    public let args: [String]
    public let stdin: String

    // Double Optional to encode explicit null into JSON
    public var windowId: UInt32?? // Please forward TOMWM_WINDOW_ID env variable here
    public var monitor: Int??     // Please forward TOMWM_MONITOR env variable here

    public init(
        args: [String],
        stdin: String,
        windowId: UInt32?,
        monitor: Int?,
    ) {
        self.args = args
        self.stdin = stdin
        self.windowId = .some(windowId)
        self.monitor = .some(monitor)
    }

    public static func decodeJson(_ data: Data) -> Result<ClientRequest, String> {
        Result { try JSONDecoder().decode(Self.self, from: data) }.mapError { $0.localizedDescription }
    }

    enum CodingKeys: String, CodingKey {
        case args
        case stdin
        case windowId
        case monitor
    }

    public init(from decoder: any Decoder) throws {
        let data = try ClientRequestData.init(from: decoder)
        var raw = ClientRequest(
            args: data.args,
            stdin: data.stdin,
            windowId: data.windowId.flattenOptional(),
            monitor: data.monitor.flattenOptional(),
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if !container.contains(.windowId) { raw.windowId = nil }
        if !container.contains(.monitor) { raw.monitor = nil }
        self = raw
    }
}

private struct ClientRequestData: Codable, Sendable {
    var args: [String]
    var stdin: String
    var windowId: UInt32??
    var monitor: Int??
}
