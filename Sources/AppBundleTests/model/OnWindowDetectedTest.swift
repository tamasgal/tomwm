@testable import AppBundle
import Common
import XCTest

@MainActor
final class OnWindowDetectedTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testMatcherCommandReceivesDetectedWindowId() async {
        let detected = TestWindow.new(id: 2)
        let focused = TestWindow.new(id: 1)
        assertEquals(focused.focusWindow(), true)
        assertEquals(focus.windowOrNil?.windowId, 1)

        let callback = WindowDetectedCallback(
            matcher: .command(parseCommand("test %{window-id} = 2").cmdOrDie),
            rawRun: .empty,
        )

        assertEquals(await callback.matches(detected), true)
        assertEquals(await callback.matches(focused), false)
    }

    func testRunCommandReceivesDetectedWindowIdInEnv() async {
        let detected = TestWindow.new(id: 2)
        let focused = TestWindow.new(id: 1)
        assertEquals(focused.focusWindow(), true)

        config.onWindowDetected = [
            WindowDetectedCallback(
                matcher: .command(.empty), // true
                rawRun: parseCommand("tag 5").cmdOrDie,
            ),
        ]

        await tryOnWindowDetected(detected) // todo: tryOnWindowDetected must not be called manually in tests

        assertEquals(detected.tags.tagNames, ["5"])
        assertEquals(focused.tags.tagNames, ["1"])
    }

    /// The tag matcher holds a name, resolved when the callback runs rather than when it is parsed
    func testLegacyTagMatcher() async {
        let onTagOne = TestWindow.new(id: 1)
        let onTagFive = TestWindow.new(id: 2, tags: TagMask(index: 4))

        let parsed = parseConfig("""
            [[on-window-detected]]
            if.tag = '5'
            run = []
            """)
        assertEquals(parsed.errors, [])
        let callback = parsed.config.onWindowDetected.singleOrNil().orDie()

        assertEquals(await callback.matches(onTagFive), true)
        assertEquals(await callback.matches(onTagOne), false)
    }
}
