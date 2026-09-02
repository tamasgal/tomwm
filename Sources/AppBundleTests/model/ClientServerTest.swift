@testable import AppBundle
import Common
import XCTest

final class ClientServerTest: XCTestCase {
    func testClientRequestJsonV1_decoding() {
        let data = """
            { "command": "deprecated", "args": ["foo", "bar"], "stdin": "stdin" }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: nil, monitor: nil)
            .copy(\.windowId, nil)
            .copy(\.monitor, nil)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV2_decoding() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin" }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: nil, monitor: nil)
            .copy(\.windowId, nil)
            .copy(\.monitor, nil)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV3_decoding() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin", "windowId": null, "monitor": null }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: nil, monitor: nil)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV3_decoding2() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin", "windowId": 1, "monitor": 2 }
            """.data(using: .utf8)!
        let expected = ClientRequest(args: ["foo", "bar"], stdin: "stdin", windowId: 1, monitor: 2)
        assertSucc(ClientRequest.decodeJson(data), expected)
    }

    func testClientRequestJsonV9999_decoding() {
        let data = """
            { "args": ["foo", "bar"], "stdin": "stdin", "yet another future field": 1 }
            """.data(using: .utf8)!
        assertSucc(ClientRequest.decodeJson(data))
    }

    func testClientRequestJsonCompatibility_encoding() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let testData = [
            (ClientRequest(args: ["args"], stdin: "stdin", windowId: 0, monitor: 1), """
                {"args":["args"],"monitor":1,"stdin":"stdin","windowId":0}
                """),
            (ClientRequest(args: ["args"], stdin: "stdin", windowId: nil, monitor: nil), """
                {"args":["args"],"monitor":null,"stdin":"stdin","windowId":null}
                """),
        ]
        for (req, expectedJson) in testData {
            let data = try! encoder.encode(req)
            let str = String.init(data: data, encoding: .utf8)!
            assertEquals(str, expectedJson)
        }
    }

    func testServerEventEncoding() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let testData: [(ServerEvent, String)] = [
            (.focusChanged(windowId: 123, tags: ["1"]),
             #"{"_event":"focus-changed","tags":["1"],"windowId":123}"#),

            (.focusedMonitorChanged(tags: ["2"], monitorId_oneBased: 1),
             #"{"_event":"focused-monitor-changed","monitorId":1,"tags":["2"]}"#),

            (.tagsChanged(tags: ["2"], prevTags: ["1"]),
             #"{"_event":"tags-changed","prevTags":["1"],"tags":["2"]}"#),

            (.modeChanged(mode: "resize"),
             #"{"_event":"mode-changed","mode":"resize"}"#),

            (.windowDetected(windowId: 456, tags: ["1"], appBundleId: "com.example", appName: "Example"),
             #"{"_event":"window-detected","appBundleId":"com.example","appName":"Example","tags":["1"],"windowId":456}"#),

            (.bindingTriggered(mode: "main", binding: "alt-h"),
             #"{"_event":"binding-triggered","binding":"alt-h","mode":"main"}"#),
        ]
        for (event, expectedJson) in testData {
            let data = try! encoder.encode(event)
            let str = String(data: data, encoding: .utf8)!
            assertEquals(str, expectedJson)
        }
    }

    func testServerEventDecoding() {
        let testData: [(String, ServerEventType)] = [
            (#"{"_event":"focus-changed","windowId":123,"tags":["1"],"monitorId":1}"#, .focusChanged),
            (#"{"_event":"focused-monitor-changed","tags":["2"],"monitorId":1}"#, .focusedMonitorChanged),
            (#"{"_event":"tags-changed","tags":["2"],"prevTags":["1"]}"#, .tagsChanged),
            (#"{"_event":"mode-changed","mode":"resize"}"#, .modeChanged),
            (#"{"_event":"window-detected","windowId":456}"#, .windowDetected),
            (#"{"_event":"binding-triggered","mode":"main","binding":"alt-h"}"#, .bindingTriggered),
        ]
        for (json, expectedEventType) in testData {
            let data = json.data(using: .utf8)!
            let event = try! JSONDecoder().decode(ServerEvent.self, from: data)
            assertEquals(event.eventType, expectedEventType)
        }
    }
}
