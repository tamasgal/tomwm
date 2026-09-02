@testable import AppBundle
import Common
import XCTest

@MainActor
final class ConfigTest: XCTestCase {
    func testEmptyConfig() {
        let result = parseConfig("")
        assertEquals(result.errors, [])
        assertEquals(result.warnings, [])
        assertTrue(result.allowReloadConfig)
    }

    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"), encoding: .utf8)
        let result = parseConfig(toml)
        assertEquals(result.errors, [])
        assertEquals(result.warnings, [])
    }

    // =========================================================== Tags

    func testParseTags() {
        let result = parseConfig(
            """
            tags = ['web', 'code', 'chat']
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.tags, ["web", "code", "chat"])
    }

    func testDefaultTags() {
        assertEquals(parseConfig("").config.tags, ["base", "web", "dev", "doc", "img", "vid", "mus", "eml", "foo"])
    }

    func testEmptyTagsIsAnError() {
        assertEquals(parseConfig("tags = []").strErrors, ["[ERROR] tags: At least one tag is required"])
    }

    func testDuplicatedTags() {
        assertEquals(
            parseConfig("tags = ['a', 'b', 'a']").strErrors,
            ["[ERROR] tags: Contains duplicated tag names"],
        )
    }

    func testTooManyTags() {
        let tags = (1 ... 33).map { "'\($0)'" }.joined(separator: ", ")
        assertEquals(
            parseConfig("tags = [\(tags)]").strErrors,
            ["[ERROR] tags: At most 32 tags are supported, got 33"],
        )
    }

    func testIllegalTagNames() {
        assertEquals(parseConfig("tags = ['']").strErrors, ["[ERROR] tags: Empty tag name is forbidden"])
        assertEquals(parseConfig("tags = ['-foo']").strErrors, ["[ERROR] tags: Tag names starting with dash are disallowed"])
        assertEquals(parseConfig("tags = ['a,b']").strErrors, ["[ERROR] tags: Tag names are not allowed to contain comma"])
        assertEquals(parseConfig("tags = ['a b']").strErrors, ["[ERROR] tags: Whitespace characters are forbidden in tag names"])
        assertEquals(parseConfig("tags = ['selected']").strErrors, ["[ERROR] tags: 'selected' is a reserved tag name"])
    }

    // =========================================================== Layout, nmaster, mfact

    func testParseDefaultLayout() {
        assertEquals(parseConfig("default-layout = 'monocle'").config.defaultLayout, .monocle)
        assertEquals(parseConfig("default-layout = 'floating'").config.defaultLayout, .floating)
        assertEquals(parseConfig("").config.defaultLayout, .tile)
        assertEquals(
            parseConfig("default-layout = 'bogus'").strErrors,
            ["[ERROR] default-layout: Can't parse layout 'bogus'. Possible values: tile|monocle|floating"],
        )
    }

    func testParseNmaster() {
        assertEquals(parseConfig("nmaster = 3").config.nmaster, 3)
        assertEquals(parseConfig("nmaster = 0").config.nmaster, 0)
        assertEquals(parseConfig("").config.nmaster, 1)
        assertEquals(parseConfig("nmaster = -1").strErrors, ["[ERROR] nmaster: nmaster can't be negative"])
        assertEquals(
            parseConfig("nmaster = 'foo'").strErrors,
            ["[ERROR] nmaster: Expected type is 'Int'. But actual type is 'String'"],
        )
    }

    func testParseMfact() {
        assertEquals(parseConfig("mfact = 0.3").config.mfact, 0.3)
        assertEquals(parseConfig("").config.mfact, 0.5)
        assertEquals(parseConfig("mfact = 0.01").strErrors, ["[ERROR] mfact: mfact must be between 0.05 and 0.95"])
        assertEquals(parseConfig("mfact = 0.99").strErrors, ["[ERROR] mfact: mfact must be between 0.05 and 0.95"])
        assertEquals(
            parseConfig("mfact = 'foo'").strErrors,
            ["[ERROR] mfact: Expected type is 'Double'. But actual type is 'String'"],
        )
    }

    // =========================================================== Removed options

    func testRemovedOptions() {
        let removed = [
            ("enable-normalization-flatten-containers = false", "tomwm has no window tree to normalize"),
            ("enable-normalization-opposite-orientation-for-nested-containers = false", "tomwm has no window tree to normalize"),
            ("default-root-container-layout = 'tiles'", "Use 'default-layout' instead"),
            ("default-root-container-orientation = 'auto'", "tomwm layouts have a fixed orientation"),
            ("accordion-padding = 30", "tomwm has no accordion layout. See 'monocle'"),
            ("persistent-workspaces = ['1']", "Use 'tags' instead. Tags always exist"),
            ("exec-on-workspace-change = ['/bin/bash']", "Use 'tomwm subscribe tags-changed' instead"),
            ("config-version = 2", "tomwm has no config versions"),
        ]
        for (line, hint) in removed {
            let key = String(line.split(separator: " ").first.orDie())
            assertEquals(
                parseConfig(line).strErrors,
                ["[ERROR] \(key): The option was removed in tomwm. \(hint)"],
                additionalMsg: line,
            )
        }
    }

    func testRemovedWorkspaceToMonitorForceAssignment() {
        assertEquals(
            parseConfig(
                """
                [workspace-to-monitor-force-assignment]
                    a = 1
                """,
            ).strErrors,
            ["[ERROR] workspace-to-monitor-force-assignment: The option was removed in tomwm. tomwm tags are per monitor, so there is nothing to assign"],
        )
    }

    // =========================================================== Modes and bindings

    func testWrongTypeForCommand() {
        let errors = parseConfig(
            """
            [mode.main.binding]
                alt-a = [1, 'focus right']
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] mode.main.binding.alt-a[0]: Expected type is 'String'. But actual type is 'Int'"])
    }

    func testDropBindings() {
        let result = parseConfig(
            """
            mode.main = {}
            """,
        )
        assertTrue(result.allowReloadConfig)
        assertEquals(result.errors, [])
        assertTrue(result.config.modes[mainModeId]?.bindings.isEmpty == true)
    }

    func testParseMode() {
        let result = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(result.errors, [])
        let binding = HotkeyBinding(.option, .h, .cmd(FocusCommand.new(direction: .left)))
        assertEquals(
            result.config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testModesMustContainDefaultModeError() {
        let result = parseConfig(
            """
            [mode.foo.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] mode: Please specify 'main' mode"])
        assertEquals(result.config.modes[mainModeId], nil)
    }

    func testHotkeyParseError() {
        let result = parseConfig(
            """
            [mode.main.binding]
                alt-hh = 'focus left'
                aalt-j = 'focus down'
                alt-k = 'focus up'
            """,
        )
        assertEquals(
            result.strErrors,
            [
                "[ERROR] mode.main.binding.aalt-j: Can't parse modifiers in 'aalt-j' binding",
                "[ERROR] mode.main.binding.alt-hh: Can't parse the key in 'alt-hh' binding",
            ],
        )
        let binding = HotkeyBinding(.option, .k, .cmd(FocusCommand.new(direction: .up)))
        assertEquals(
            result.config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    // =========================================================== Generic parsing

    func testUnknownTopLevelKeyParseError() {
        let result = parseConfig(
            """
            unknownKey = true
            nmaster = 2
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] unknownKey: Unknown top-level key"])
        assertEquals(result.config.nmaster, 2)
    }

    func testUnknownKeyParseError() {
        let result = parseConfig(
            """
            auto-reload-config = true
            [gaps]
                unknownKey = true
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] gaps.unknownKey: Unknown key"])
        assertEquals(result.config.autoReloadConfig, true)
    }

    func testTypeMismatch() {
        let errors = parseConfig(
            """
            auto-reload-config = 'true'
            """,
        ).strErrors
        assertEquals(
            errors,
            ["[ERROR] auto-reload-config: Expected type is 'Bool'. But actual type is 'String'"],
        )
    }

    func testConfigParseError() {
        assertFalse(parseConfig("true").allowReloadConfig)
        assertEquals(
            parseConfig("true").strErrors,
            ["[ERROR] (Line 1) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("\n1").strErrors,
            ["[ERROR] (Line 2) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("foo: 1").strErrors,
            ["[ERROR] (Line 1) Syntax error: missing =."],
        )

        // Doubles are a supported TOML type since mfact needs them
        assertEquals(
            parseConfig("foo = 1.0").strErrors,
            ["[ERROR] foo: Unknown top-level key"],
        )

        assertEquals(
            parseConfig("foo.bar = 1979-05-27").strErrors,
            ["[ERROR] foo.bar: Unsupported TOML type: LocalDate", "[ERROR] foo: Unknown top-level key"],
        )
    }

    func testTopLevelTypeIsNotTable() {
        let result = parseConfig("a = ")
        assertFalse(result.allowReloadConfig)
    }

    func testTomlParser() {
        let errors = parseConfig(
            """
            [[[on-window-detected]]
            if.app-id = 'com.apple.findmy'
            run = 'layout floating'

            [on-window-detected]]
            if.app-id = 'com.openai.chat'
            run = 'layout floating'
            """,
        ).strErrors
        assertEquals(errors, ["[ERROR] (Line 1) Syntax error: invalid or missing key."])
    }

    // =========================================================== on-window-detected

    func testParseOnWindowDetected() {
        let result = parseConfig(
            """
            on-window-detected = [
                { # 0
                    if = 'true',
                    check-further-callbacks = true,
                    run = ['floating on', 'tag 3'],
                },
                { # 1
                    if.app-id = 'com.apple.systempreferences',
                    run = [],
                },
                {}, # 2
                { # 3
                    if.tag = '5', run = ['layout monocle'],
                },
                { # 4
                    if = 'test %{app-bundle-id} = org.alacritty',
                    run = ['tag 4'],
                },
                { if = '', run = ''}, # 5
            ]
            """,
        )
        let matcherArgs = TestCmdArgs(rawArgs: [])
            .copy(\.lhs, .initialized(.app(.appBundleId)))
            .copy(\.infixOperator, .initialized(.equals))
            .copy(\.rhs, .initialized("org.alacritty"))
        assertEquals(result.config.onWindowDetected, [
            WindowDetectedCallback( // 0
                matcher: .command(.cmd(TrueCommand.instance)),
                checkFurtherCallbacks: true,
                rawRun: .seq([
                    .cmd(FloatingCommand(args: FloatingCmdArgs(rawArgs: ["on"]).copy(\.toggle, .on))),
                    .cmd(TagCommand(args: TagCmdArgs(rawArgs: ["3"], tags: ["3"]))),
                ]),
            ),
            WindowDetectedCallback( // 1
                matcher: .legacy(LegacyWindowDetectedCallbackMatcher(
                    appId: "com.apple.systempreferences",
                )),
                rawRun: .empty,
            ),
            WindowDetectedCallback( // 3
                matcher: .legacy(LegacyWindowDetectedCallbackMatcher(tag: "5")),
                rawRun: .cmd(LayoutCommand(args: LayoutCmdArgs(rawArgs: ["monocle"], toggleBetween: [.monocle]))),
            ),
            WindowDetectedCallback( // 4
                matcher: .command(.cmd(TestCommand(args: matcherArgs))),
                rawRun: .cmd(TagCommand(args: TagCmdArgs(rawArgs: ["4"], tags: ["4"]))),
            ),
        ])

        assertEquals(result.strErrors, [
            "[ERROR] on-window-detected[2]: Omitting 'if' is error prone. You can use `if = 'true'` to preserve the previous behavior.\nBut heads up! You may have missed 'check-further-callbacks = true'",
            "[ERROR] on-window-detected[2]: 'run' is mandatory key",
            "[ERROR] on-window-detected[5]: Omitting 'if' is error prone. You can use `if = 'true'` to preserve the previous behavior.\nBut heads up! You may have missed 'check-further-callbacks = true'",
        ])
    }

    func testParseOnWindowDetected2() {
        let result = parseConfig(
            """
            on-window-detected = [
                { check-further-callbacks = true, run = '', },
            ]
            """,
        )
        assertEquals(result.config.onWindowDetected, [
            WindowDetectedCallback(
                matcher: .command(.empty),
                checkFurtherCallbacks: true,
                rawRun: .empty,
            ),
        ])

        assertEquals(result.errors, [])
    }

    func testParseInlineTables() {
        let errors = parseConfig(
            """
            on-window-detected = [
                {
                    check-further-callbacks = true,
                    run = ['floating on', 'tag 3'],
                },
                {
                    if.app-id = 'com.apple.systempreferences',
                    run = [],
                }
            ]
            """,
        ).errors
        assertEquals(errors, [])
    }

    func testParseOnWindowDetectedRegex() {
        let result = parseConfig(
            """
            [[on-window-detected]]
                if.app-name-regex-substring = '^system settings$'
                run = []
            """,
        )
        let expected = WindowDetectedCallbackMatcher.legacy(LegacyWindowDetectedCallbackMatcher(appNameRegexSubstring: .new("^system settings$").getOrDie()))
        assertEquals(result.config.onWindowDetected.singleOrNil()!.matcher, expected)
        assertEquals(result.errors, [])
    }

    func testParseOnWindowDetectedIllegalTag() {
        let result = parseConfig(
            """
            [[on-window-detected]]
                if.tag = '-nope'
                run = []
            """,
        )
        assertEquals(result.strErrors, ["[ERROR] on-window-detected[0].if.tag: Tag names starting with dash are disallowed"])
    }

    func testRegex() {
        var devNull: [String] = []
        XCTAssertTrue("System Settings".contains(caseInsensitiveRegex: CaseInsensitiveRegex.new("settings").getOrNil(appendErrorTo: &devNull)!))
        XCTAssertTrue(!"System Settings".contains(caseInsensitiveRegex: CaseInsensitiveRegex.new("^settings^").getOrNil(appendErrorTo: &devNull)!))
    }

    // =========================================================== Gaps

    func testParseGaps() {
        let result1 = parseConfig(
            """
            [gaps]
                inner.horizontal = 10
                inner.vertical = [{ monitor."main" = 1 }, { monitor."secondary" = 2 }, 5]
                outer.left = 12
                outer.bottom = 13
                outer.top = [{ monitor."built-in" = 3 }, { monitor."secondary" = 4 }, 6]
                outer.right = [{ monitor.2 = 7 }, 8]
            """,
        )
        assertEquals(result1.errors, [])
        assertEquals(
            result1.config.gaps,
            Gaps(
                inner: .init(
                    vertical: .perMonitor(
                        [PerMonitorValue(description: .main, value: 1), PerMonitorValue(description: .secondary, value: 2)],
                        default: 5,
                    ),
                    horizontal: .constant(10),
                ),
                outer: .init(
                    left: .constant(12),
                    bottom: .constant(13),
                    top: .perMonitor(
                        [
                            PerMonitorValue(description: .pattern("built-in")!, value: 3),
                            PerMonitorValue(description: .secondary, value: 4),
                        ],
                        default: 6,
                    ),
                    right: .perMonitor([PerMonitorValue(description: .sequenceNumber(2), value: 7)], default: 8),
                ),
            ),
        )

        let result2 = parseConfig(
            """
            [gaps]
                inner.horizontal = [true]
                inner.vertical = [{ foo.main = 1 }, { monitor = { foo = 2, bar = 3 } }, 1]
            """,
        )
        assertEquals(result2.strErrors, [
            "[ERROR] gaps.inner.horizontal: The last item in the array must be of type Int",
            "[ERROR] gaps.inner.vertical[0]: The table is expected to have a single key 'monitor'",
            "[ERROR] gaps.inner.vertical[1].monitor: The table is expected to have a single key",
        ])
    }

    // =========================================================== Callbacks

    func testAfterLoginCommandDeprecation() {
        let result = parseConfig(
            """
            after-login-command = ['exec-and-forget echo hi']
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] after-login-command: The option was removed in tomwm. Use 'after-startup-command' instead"],
        )

        // Empty array is still accepted
        let okResult = parseConfig(
            """
            after-login-command = []
            """,
        )
        assertEquals(okResult.errors, [])
    }

    func testOnFocusChangedAsSingleStringAndAsList() {
        let result = parseConfig(
            """
            on-focus-changed = 'focus left'
            on-mode-changed = ['focus right', 'focus up']
            on-focused-monitor-changed = 'focus down'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.onFocusChanged.flatten().count, 1)
        XCTAssertTrue(result.config.onFocusChanged.flatten()[0] is FocusCommand)
        assertEquals(result.config.onModeChanged.flatten().count, 2)
        assertEquals(result.config.onFocusedMonitorChanged.flatten().count, 1)
    }

    func testOnFocusChangedTypeError() {
        let result = parseConfig(
            """
            on-focus-changed = 1
            """,
        )
        assertEquals(
            result.strErrors,
            ["[ERROR] on-focus-changed: Expected types are 'string' or 'array'. But actual type is 'int'"],
        )
    }

    // =========================================================== Key mapping

    func testParseKeyMapping() {
        let result = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'q'
                unicorn = 'u'

            [mode.main.binding]
                alt-unicorn = 'view 3'
            """,
        )
        assertEquals(result.errors, [])
        assertEquals(result.config.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToKeyCode: [
            "q": .q,
            "unicorn": .u,
        ]))
        let binding = HotkeyBinding(.option, .u, .cmd(ViewCommand(args: ViewCmdArgs(rawArgs: ["3"], tags: ["3"]))))
        assertEquals(result.config.modes[mainModeId]?.bindings, [binding.descriptionWithKeyCode: binding])

        let errors1 = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'qw'
                ' f' = 'f'
            """,
        ).strErrors
        assertEquals(errors1, [
            "[ERROR] key-mapping.key-notation-to-key-code: ' f' is invalid key notation",
            "[ERROR] key-mapping.key-notation-to-key-code.q: 'qw' is invalid key code",
        ])

        let dvorakResult = parseConfig(
            """
            key-mapping.preset = 'dvorak'
            """,
        )
        assertEquals(dvorakResult.errors, [])
        assertEquals(dvorakResult.config.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToKeyCode: [:]))
        assertEquals(dvorakResult.config.keyMapping.resolve()["quote"], .q)
        let colemakResult = parseConfig(
            """
            key-mapping.preset = 'colemak'
            """,
        )
        assertEquals(colemakResult.errors, [])
        assertEquals(colemakResult.config.keyMapping, KeyMapping(preset: .colemak, rawKeyNotationToKeyCode: [:]))
        assertEquals(colemakResult.config.keyMapping.resolve()["f"], .e)
    }
}

extension ParseConfigResult {
    var strErrors: [String] {
        errors.map { $0.description(.error) }
    }
}
