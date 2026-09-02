@testable import AppBundle
import Common
import Foundation
import XCTest

private func assertPrimitive(_ actual: Result<Primitive, InterVarExpansionError>, _ expected: Primitive, file: StaticString = #filePath, line: UInt = #line) {
    switch actual {
        case .failure: failExpectedActual("Result.success(\(expected.toString()))", actual, file: file, line: line)
        case .success(let primitive):
            if primitive.kind != expected.kind || primitive.toString() != expected.toString() {
                failExpectedActual("\(expected.kind.rawValue)(\(expected.toString()))", "\(primitive.kind.rawValue)(\(primitive.toString()))", file: file, line: line)
            }
    }
}

@MainActor
private func tagRef(_ index: Int, monitor: MonitorInfo = mainMonitorInfo) -> TagRef {
    TagRef(name: config.tags[index], mask: TagMask(index: index), monitor: monitor)
}

@MainActor
final class FormatTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testTomObjKind() {
        let window = TestWindow.new(id: 1)
        assertEquals(TomObj.window(.forTest(window: window, title: nil)).kind, .window)
        assertEquals(TomObj.tag(tagRef(0)).kind, .tag)
        assertEquals(TomObj.app(TestApp.shared).kind, .app)
        assertEquals(TomObj.monitor(mainMonitorInfo).kind, .monitor)
    }

    func testResolveWindowForFormatVarPrefetchesTitleOnlyWhenNeeded() async throws {
        let window = TestWindow.new(id: 7)
        let withTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: .window(.windowTitle), .nonCancellable)
        assertEquals(withTitle.title, "TestWindow(7)")

        let withoutTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: .window(.windowId), .nonCancellable)
        assertNil(withoutTitle.title)
    }

    func testResolveWindowForFormatTokensPrefetchesTitleOnlyWhenNeeded() async throws {
        let window = TestWindow.new(id: 3)

        let withTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: [
            .literal("foo"),
            .interVar(.formatVar(.window(.windowTitle))),
        ], .nonCancellable)
        assertEquals(withTitle.title, "TestWindow(3)")

        let withoutTitle = try await WindowWithPrefetchedTitle.resolveWindow(window, for: [
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.newline)),
        ], .nonCancellable)
        assertNil(withoutTitle.title)
    }

    func testFormatEmptyInput() {
        let result: [TomObj] = []
        assertSucc(result.format([.interVar(.formatVar(.window(.windowId)))]), [])
    }

    func testFormatWithNewlineAndTab() {
        let window = TestWindow.new(id: 42)
        let objs: [TomObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.format([
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.tab)),
            .literal("X"),
            .interVar(.plainInterVar(.newline)),
            .literal("end"),
        ])
        assertSucc(result, ["42\tX\nend"])
    }

    func testFormatMultipleRightPaddingColumns() {
        let windows: [TomObj] = [
            .window(.forTest(window: TestWindow.new(id: 2), title: "a")),
            .window(.forTest(window: TestWindow.new(id: 100), title: "bb")),
        ]
        let result = windows.format([
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.rightPadding)),
            .literal(" | "),
            .interVar(.formatVar(.window(.windowTitle))),
            .interVar(.plainInterVar(.rightPadding)),
            .literal(" END"),
        ])
        assertSucc(result, [
            "2   | a  END",
            "100 | bb END",
        ])
    }

    func testFormatFailureAccumulatesErrors() {
        let objs: [TomObj] = [.tag(tagRef(0))]
        let result = objs.format([
            .interVar(.formatVar(.window(.windowId))),
            .interVar(.plainInterVar(.rightPadding)),
            .interVar(.formatVar(.window(.windowTitle))),
        ])
        switch result {
            case .success: XCTFail("expected failure")
            case .failure(let msg):
                let msg = msg.map(\.description).joined(separator: "\n")
                assertTrue(msg.contains("Unknown interpolation variable 'window-id'"))
                assertTrue(msg.contains("Unknown interpolation variable 'window-title'"))
        }
    }

    func testPrimitiveKind() {
        assertEquals(Primitive.bool(true).kind, .bool)
        assertEquals(Primitive.int(7).kind, .int)
        assertEquals(Primitive.string("x").kind, .string)
    }

    func testPrimitiveToString() {
        assertEquals(Primitive.bool(true).toString(), "true")
        assertEquals(Primitive.bool(false).toString(), "false")
        assertEquals(Primitive.int(42).toString(), "42")
        assertEquals(Primitive.string("hello").toString(), "hello")
    }

    func testPrimitiveIntConvenienceConstructors() {
        assertEquals(Primitive.int(UInt32(5)).toString(), "5")
        assertEquals(Primitive.int(Int32(-3)).toString(), "-3")
        assertEquals(Primitive.int(Int(123)).toString(), "123")
    }

    func testPrimitiveEncoding() throws {
        let cases: [(Primitive, String)] = [
            (.bool(true), "true"),
            (.bool(false), "false"),
            (.int(42), "42"),
            (.string("hi"), "\"hi\""),
        ]
        for (primitive, expected) in cases {
            let data = try JSONEncoder().encode(primitive)
            assertEquals(String(data: data, encoding: .utf8), expected)
        }
    }

    func testPrimitiveKindRawValues() {
        assertEquals(Primitive.Kind.bool.rawValue, "Bool")
        assertEquals(Primitive.Kind.int.rawValue, "Int")
        assertEquals(Primitive.Kind.string.rawValue, "String")
    }

    func testExpandWindowIdAndIsFullscreen() {
        let window = TestWindow.new(id: 9)
        window.isFullscreen = true
        let obj = TomObj.window(.forTest(window: window, title: "title-x"))

        assertPrimitive(FormatVar.window(.windowId).expandFormatVar(obj: obj), .int(Int64(9)))
        assertPrimitive(FormatVar.window(.windowIsFullscreen).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.window(.windowTitle).expandFormatVar(obj: obj), .string("title-x"))
    }

    func testExpandWindowIsFloating() {
        let window = TestWindow.new(id: 1)
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowIsFloating).expandFormatVar(obj: obj), .bool(false))
        assertPrimitive(FormatVar.window(.windowIsDialog).expandFormatVar(obj: obj), .bool(false))

        window.isFloating = true
        assertPrimitive(FormatVar.window(.windowIsFloating).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.window(.windowIsDialog).expandFormatVar(obj: obj), .bool(false))
    }

    func testExpandWindowIsDialogImpliesFloating() {
        let window = TestWindow.new(id: 1, isDialog: true)
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowIsDialog).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.window(.windowIsFloating).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandWindowTagsAndIsVisible() {
        let window = TestWindow.new(id: 1, tags: [TagMask(index: 0), TagMask(index: 2)])
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowTags).expandFormatVar(obj: obj), .string("1,3"))
        assertPrimitive(FormatVar.window(.windowIsVisible).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandWindowIsVisibleForHiddenTag() {
        let window = TestWindow.new(id: 1, tags: TagMask(index: 1))
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.window(.windowTags).expandFormatVar(obj: obj), .string("2"))
        assertPrimitive(FormatVar.window(.windowIsVisible).expandFormatVar(obj: obj), .bool(false))
    }

    func testExpandWindowToTagVarsIsNotPossible() {
        let window = TestWindow.new(id: 1)
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertFail(FormatVar.tag(.tagName).expandFormatVar(obj: obj).mapError(\.description).map { _ in "" })
    }

    func testExpandWindowToMonitor() {
        let window = TestWindow.new(id: 1)
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(mainMonitorInfo.name))
        assertPrimitive(FormatVar.monitor(.monitorIsMain).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandWindowToMonitorWhenMonitorPointIsStale() {
        let window = TestWindow.new(id: 1)
        window.monitorPoint = CGPoint(x: -5000, y: -5000)
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(mainMonitorInfo.name))
    }

    func testExpandWindowToApp() {
        let window = TestWindow.new(id: 1)
        let obj = TomObj.window(.forTest(window: window, title: nil))
        assertPrimitive(FormatVar.app(.appPid).expandFormatVar(obj: obj), .int(Int64(0)))
        assertPrimitive(FormatVar.app(.appBundleId).expandFormatVar(obj: obj), .string("com.tamasgal.tomwm.test-app"))
    }

    func testExpandTagVars() {
        TestWindow.new(id: 1)
        let obj = TomObj.tag(tagRef(0))
        assertPrimitive(FormatVar.tag(.tagName).expandFormatVar(obj: obj), .string("1"))
        assertPrimitive(FormatVar.tag(.tagIsSelected).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.tag(.tagIsOccupied).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandTagVarsForUnselectedTag() {
        TestWindow.new(id: 1)
        let obj = TomObj.tag(tagRef(2))
        assertPrimitive(FormatVar.tag(.tagName).expandFormatVar(obj: obj), .string("3"))
        assertPrimitive(FormatVar.tag(.tagIsSelected).expandFormatVar(obj: obj), .bool(false))
        assertPrimitive(FormatVar.tag(.tagIsOccupied).expandFormatVar(obj: obj), .bool(false))
    }

    func testExpandTagIsOccupiedForHiddenTag() {
        TestWindow.new(id: 1, tags: TagMask(index: 3))
        let obj = TomObj.tag(tagRef(3))
        assertPrimitive(FormatVar.tag(.tagIsSelected).expandFormatVar(obj: obj), .bool(false))
        assertPrimitive(FormatVar.tag(.tagIsOccupied).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandTagToMonitor() {
        let obj = TomObj.tag(tagRef(0))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(mainMonitorInfo.name))
        assertPrimitive(FormatVar.monitor(.monitorIsMain).expandFormatVar(obj: obj), .bool(true))
    }

    func testExpandMonitorVars() {
        let monitor = mainMonitorInfo
        let obj = TomObj.monitor(monitor)
        assertPrimitive(FormatVar.monitor(.monitorAppKitNsScreenScreensId).expandFormatVar(obj: obj), .int(Int64(monitor.monitorAppKitNsScreenScreensId)))
        assertPrimitive(FormatVar.monitor(.monitorName).expandFormatVar(obj: obj), .string(monitor.name))
        assertPrimitive(FormatVar.monitor(.monitorIsMain).expandFormatVar(obj: obj), .bool(true))
        assertPrimitive(FormatVar.monitor(.monitorId_oneBased).expandFormatVar(obj: obj), .int(Int64(1)))
        assertPrimitive(FormatVar.monitor(.monitorLayout).expandFormatVar(obj: obj), .string("tile"))
        assertPrimitive(FormatVar.monitor(.monitorLayoutSymbol).expandFormatVar(obj: obj), .string("[]="))
        assertPrimitive(FormatVar.monitor(.monitorTags).expandFormatVar(obj: obj), .string("1"))
        assertPrimitive(FormatVar.monitor(.monitorNmaster).expandFormatVar(obj: obj), .int(Int64(1)))
        assertPrimitive(FormatVar.monitor(.monitorMfact).expandFormatVar(obj: obj), .double(0.55))
    }

    func testExpandMonitorVarsFollowMonitorState() {
        let monitor = mainMonitorInfo
        let state = monitor.state
        state.layout = .monocle
        state.tagset = [TagMask(index: 0), TagMask(index: 4)]
        state.nmaster = 2
        state.mfact = 0.6
        let obj = TomObj.monitor(monitor)
        assertPrimitive(FormatVar.monitor(.monitorLayout).expandFormatVar(obj: obj), .string("monocle"))
        assertPrimitive(FormatVar.monitor(.monitorLayoutSymbol).expandFormatVar(obj: obj), .string("[M]"))
        assertPrimitive(FormatVar.monitor(.monitorTags).expandFormatVar(obj: obj), .string("1,5"))
        assertPrimitive(FormatVar.monitor(.monitorNmaster).expandFormatVar(obj: obj), .int(Int64(2)))
        assertPrimitive(FormatVar.monitor(.monitorMfact).expandFormatVar(obj: obj), .double(0.6))
    }

    func testExpandAppVars() {
        let obj = TomObj.app(TestApp.shared)
        assertPrimitive(FormatVar.app(.appBundleId).expandFormatVar(obj: obj), .string("com.tamasgal.tomwm.test-app"))
        assertPrimitive(FormatVar.app(.appName).expandFormatVar(obj: obj), .string("com.tamasgal.tomwm.test-app"))
        assertPrimitive(FormatVar.app(.appPid).expandFormatVar(obj: obj), .int(Int64(0)))
        assertPrimitive(FormatVar.app(.appExecPath).expandFormatVar(obj: obj), .string("NULL-APP-EXEC-PATH"))
        assertPrimitive(FormatVar.app(.appBundlePath).expandFormatVar(obj: obj), .string("NULL-APP-BUNDLE-PATH"))
    }

    func testPlainInterVarExpand() {
        assertPrimitive(PlainInterVar.newline.expandFormatVar(), .string("\n"))
        assertPrimitive(PlainInterVar.tab.expandFormatVar(), .string("\t"))
    }

    func testRightPaddingCannotBeExpanded() {
        switch PlainInterVar.rightPadding.expandFormatVar() {
            case .success(let primitive): XCTFail("expected failure, got \(primitive.toString())")
            case .failure(let error):
                assertEquals(error.description, "'right-padding' interpolation variable cannot be expanded")
        }
    }

    func testInterVarExpandDelegates() {
        let window = TestWindow.new(id: 5)
        let obj = TomObj.window(.forTest(window: window, title: nil))

        assertPrimitive(InterVar.formatVar(.window(.windowId)).expandFormatVar(obj: obj), .int(Int64(5)))
        assertPrimitive(InterVar.plainInterVar(.newline).expandFormatVar(obj: obj), .string("\n"))
    }

    func testUnknownInterpolationVariableMessageForTag() {
        let msg = unknownInterpolationVariable(variable: "bogus", .tag(tagRef(0)))
        assertTrue(msg.starts(with: "Unknown interpolation variable 'bogus'."))
        assertTrue(msg.contains("Possible values:"))
        assertTrue(msg.contains("tag-is-selected"))
        assertTrue(msg.contains("monitor-name"))
        assertTrue(msg.contains("right-padding"))
    }

    func testUnknownInterpolationVariableMessageForWindow() {
        let window = TestWindow.new(id: 1)
        let msg = unknownInterpolationVariable(variable: "workspace", .window(.forTest(window: window, title: nil)))
        assertTrue(msg.starts(with: "Unknown interpolation variable 'workspace'."))
        assertTrue(msg.contains("window-is-floating"))
        assertTrue(msg.contains("window-tags"))
        assertTrue(msg.contains("monitor-layout-symbol"))
        assertTrue(msg.contains("app-name"))
    }

    func testInterpolationTokensParsesVarsAndLiterals() {
        let result = "%{window-id} | %{monitor-tags}".interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self)
        assertSucc(result, [
            .interVar(.formatVar(.window(.windowId))),
            .literal(" | "),
            .interVar(.formatVar(.monitor(.monitorTags))),
        ])
    }

    func testInterpolationTokensParsesPlainInterVars() {
        let result = "%{window-tags}%{right-padding}%{newline}".interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self)
        assertSucc(result, [
            .interVar(.formatVar(.window(.windowTags))),
            .interVar(.plainInterVar(.rightPadding)),
            .interVar(.plainInterVar(.newline)),
        ])
    }

    func testInterpolationTokensParsesLiteralOnly() {
        let result = "no vars here".interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self)
        assertSucc(result, [.literal("no vars here")])
    }

    func testInterpolationTokensRejectsRemovedWorkspaceVar() {
        switch "%{workspace}".interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self) {
            case .success(let tokens): failExpectedActual("Result.failure", tokens)
            case .failure(let msg): assertTrue(msg.starts(with: "Can't parse 'workspace'."))
        }
    }

    func testInterpolationTokensRejectsUnbalancedCurlyBraces() {
        switch "%{window-id".interpolationTokens(interpolationChar: "%", ofInterVarType: InterVar.self) {
            case .success(let tokens): failExpectedActual("Result.failure", tokens)
            case .failure(let msg): assertEquals(msg, "Unbalanced curly braces")
        }
    }

    func testFormatToJsonEmptyInput() {
        let result: [TomObj] = []
        assertSucc(
            result.formatToJson([.interVar(.formatVar(.window(.windowId)))], ignoreRightPaddingVar: true),
            JSONEncoder.tomWmDefault.encodeToString([[String: Primitive]]()).orDie(),
        )
    }

    func testFormatToJsonSingleObject() {
        let window = TestWindow.new(id: 42)
        window.isFullscreen = true
        let objs: [TomObj] = [.window(.forTest(window: window, title: "hello"))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.formatVar(.window(.windowTitle))),
                .interVar(.formatVar(.window(.windowIsFullscreen))),
                .interVar(.formatVar(.window(.windowTags))),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([[
            "window-id": Primitive.int(42),
            "window-title": Primitive.string("hello"),
            "window-is-fullscreen": Primitive.bool(true),
            "window-tags": Primitive.string("1"),
        ]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonMultipleObjects() {
        let objs: [TomObj] = [
            .window(.forTest(window: TestWindow.new(id: 1), title: nil)),
            .window(.forTest(window: TestWindow.new(id: 2), title: nil)),
        ]
        let result = objs.formatToJson(
            [.interVar(.formatVar(.window(.windowId)))],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([
            ["window-id": Primitive.int(1)],
            ["window-id": Primitive.int(2)],
        ])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonIgnoresLiterals() {
        let window = TestWindow.new(id: 7)
        let objs: [TomObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .literal("ignored-prefix"),
                .interVar(.formatVar(.window(.windowId))),
                .literal("  "),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([["window-id": Primitive.int(7)]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonIgnoresRightPaddingWhenFlagTrue() {
        let window = TestWindow.new(id: 8)
        let objs: [TomObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.rightPadding)),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([["window-id": Primitive.int(8)]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonRightPaddingFailsWhenFlagFalse() {
        let window = TestWindow.new(id: 8)
        let objs: [TomObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.rightPadding)),
            ],
            ignoreRightPaddingVar: false,
        )
        assertFail(result, "'right-padding' interpolation variable cannot be expanded")
    }

    func testFormatToJsonExpandsPlainInterVars() {
        let window = TestWindow.new(id: 11)
        let objs: [TomObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowId))),
                .interVar(.plainInterVar(.newline)),
                .interVar(.plainInterVar(.tab)),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([[
            "window-id": Primitive.int(11),
            "newline": Primitive.string("\n"),
            "tab": Primitive.string("\t"),
        ]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonTagObject() {
        TestWindow.new(id: 1)
        let objs: [TomObj] = [.tag(tagRef(0))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.tag(.tagName))),
                .interVar(.formatVar(.tag(.tagIsSelected))),
                .interVar(.formatVar(.tag(.tagIsOccupied))),
                .interVar(.formatVar(.monitor(.monitorId_oneBased))),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([[
            "tag": Primitive.string("1"),
            "tag-is-selected": Primitive.bool(true),
            "tag-is-occupied": Primitive.bool(true),
            "monitor-id": Primitive.int(1),
        ]])
        assertSucc(result, expected.orDie())
    }

    func testFormatToJsonFailsOnUnknownInterpolationVariable() {
        let objs: [TomObj] = [.tag(tagRef(0))]
        let result = objs.formatToJson(
            [.interVar(.formatVar(.window(.windowId)))],
            ignoreRightPaddingVar: true,
        )
        switch result {
            case .success: XCTFail("expected failure")
            case .failure(let msg):
                assertTrue(msg.starts(with: "Unknown interpolation variable 'window-id'."))
        }
    }

    func testFormatToJsonReturnsFirstFailureForMultipleObjects() {
        TestWindow.new(id: 1)
        let objs: [TomObj] = [
            .tag(tagRef(0)),
            .tag(tagRef(1)),
        ]
        let result = objs.formatToJson(
            [.interVar(.formatVar(.window(.windowId)))],
            ignoreRightPaddingVar: true,
        )
        assertFail(result)
    }

    func testFormatToJsonOverlappingKeysKeepLastValue() {
        let window = TestWindow.new(id: 5)
        window.isFullscreen = false
        let objs: [TomObj] = [.window(.forTest(window: window, title: nil))]
        let result = objs.formatToJson(
            [
                .interVar(.formatVar(.window(.windowIsFullscreen))),
                .literal(" between literals "),
                .interVar(.formatVar(.window(.windowIsFullscreen))),
            ],
            ignoreRightPaddingVar: true,
        )
        let expected = JSONEncoder.tomWmDefault.encodeToString([[
            "window-is-fullscreen": Primitive.bool(false),
        ]])
        assertSucc(result, expected.orDie())
    }
}
