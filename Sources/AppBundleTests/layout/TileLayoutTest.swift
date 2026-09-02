@testable import AppBundle
import Common
import XCTest

/// The test monitor is 1920x1080 at (0, 0) with no gaps. arrange() asks for one point less height
/// than the monitor has, to work around macOS refusing full height in some multi monitor setups,
/// so every expected height below is computed from 1079.
private let width: CGFloat = 1920
private let height: CGFloat = 1079

@MainActor
final class TileLayoutTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testSingleWindowTakesTheWholeScreen() async throws {
        newWindows([1])
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height))
    }

    func testMasterAndStack() async throws {
        newWindows([1, 2])
        let rects = try await arrangedRects()
        let masterWidth = width * 0.55
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: masterWidth, height: height))
        assertEquals(rects[2], Rect(topLeftX: masterWidth, topLeftY: 0, width: width - masterWidth, height: height))
    }

    /// dwm divides the column height incrementally, so the remainder is spread rather than dumped
    /// on the last window
    func testStackSplitsTheColumnEvenly() async throws {
        newWindows([1, 2, 3])
        let rects = try await arrangedRects()
        let masterWidth = width * 0.55
        let stackWidth = width - masterWidth
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: masterWidth, height: height))
        assertEquals(rects[2], Rect(topLeftX: masterWidth, topLeftY: 0, width: stackWidth, height: height / 2))
        assertEquals(rects[3], Rect(topLeftX: masterWidth, topLeftY: height / 2, width: stackWidth, height: height / 2))
    }

    func testStackOfThreeCoversTheFullHeight() async throws {
        newWindows([1, 2, 3, 4])
        let rects = try await arrangedRects()
        let stack = [rects[2], rects[3], rects[4]].map { $0.orDie() }
        assertClose(stack.map(\.topLeftY), [0, height / 3, height / 3 * 2])
        assertClose(stack.reduce(0) { $0 + $1.height }, height)
    }

    func testNmasterTwo() async throws {
        newWindows([1, 2, 3])
        mainMonitorInfo.state.nmaster = 2
        let rects = try await arrangedRects()
        let masterWidth = width * 0.55
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: masterWidth, height: height / 2))
        assertEquals(rects[2], Rect(topLeftX: 0, topLeftY: height / 2, width: masterWidth, height: height / 2))
        assertEquals(rects[3], Rect(topLeftX: masterWidth, topLeftY: 0, width: width - masterWidth, height: height))
    }

    /// dwm gives the master area zero width when nmaster is zero, so everything shares the stack
    func testNmasterZeroGivesEverythingToTheStack() async throws {
        newWindows([1, 2])
        mainMonitorInfo.state.nmaster = 0
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height / 2))
        assertEquals(rects[2], Rect(topLeftX: 0, topLeftY: height / 2, width: width, height: height / 2))
    }

    /// With no stack the master area takes the whole width, whatever mfact says
    func testNmasterLargerThanWindowCount() async throws {
        newWindows([1, 2])
        mainMonitorInfo.state.nmaster = 5
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height / 2))
        assertEquals(rects[2], Rect(topLeftX: 0, topLeftY: height / 2, width: width, height: height / 2))
    }

    func testMfactMovesTheBoundary() async throws {
        newWindows([1, 2])
        mainMonitorInfo.state.mfact = 0.25
        let rects = try await arrangedRects()
        assertEquals(rects[1]?.width, width * 0.25)
        assertEquals(rects[2]?.width, width * 0.75)
    }

    func testInnerGaps() async throws {
        newWindows([1, 2, 3])
        config.gaps = Gaps(inner: .init(vertical: 10, horizontal: 20), outer: .zero)
        let rects = try await arrangedRects()
        let masterWidth = (width - 20) * 0.55
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: masterWidth, height: height))
        assertEquals(rects[2]?.topLeftX, masterWidth + 20)
        assertEquals(rects[2]?.width, width - masterWidth - 20)
        assertEquals(rects[2]?.height, (height - 10) / 2)
        assertEquals(rects[3]?.topLeftY, (height - 10) / 2 + 10)
    }

    func testOuterGaps() async throws {
        newWindows([1])
        config.gaps = Gaps(inner: .zero, outer: .init(left: 4, bottom: 8, top: 16, right: 32))
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 4, topLeftY: 16, width: width - 4 - 32, height: 1080 - 16 - 8 - 1))
    }

    func testMonocleGivesEveryWindowTheWholeScreen() async throws {
        newWindows([1, 2, 3])
        mainMonitorInfo.state.layout = .monocle
        let rects = try await arrangedRects()
        let full = Rect(topLeftX: 0, topLeftY: 0, width: width, height: height)
        assertEquals(rects[1], full)
        assertEquals(rects[2], full)
        assertEquals(rects[3], full)
    }

    func testFloatingLayoutArrangesNothing() async throws {
        newWindows([1, 2])
        mainMonitorInfo.state.layout = .floating
        _ = try await arrangedRects()
        assertNil(Window.get(byId: 1)?.lastAppliedRect)
        assertNil(Window.get(byId: 2)?.lastAppliedRect)
    }

    func testFloatingWindowsAreNotTiled() async throws {
        let windows = newWindows([1, 2, 3])
        windows[1].isFloating = true
        let rects = try await arrangedRects()
        let masterWidth = width * 0.55
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: masterWidth, height: height))
        assertEquals(rects[3], Rect(topLeftX: masterWidth, topLeftY: 0, width: width - masterWidth, height: height))
        assertNil(rects[2])
    }

    /// Whatever the layout, a dialog is managed floating
    func testDialogsAreNeverTiled() async throws {
        TestWindow.new(id: 2, isDialog: true)
        TestWindow.new(id: 1)
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height))
        assertNil(rects[2])
    }

    func testWindowsOnOtherTagsAreNotArranged() async throws {
        TestWindow.new(id: 2, tags: TagMask(index: 3))
        TestWindow.new(id: 1)
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height))
        assertNil(rects[2])
    }

    func testMinimizedWindowsAreNotArranged() async throws {
        let windows = newWindows([1, 2])
        windows[1].macosState = .minimized
        let rects = try await arrangedRects()
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height))
        assertNil(rects[2])
    }

    func testFullscreenWindowCoversTheScreen() async throws {
        let windows = newWindows([1, 2])
        _ = windows[1].focusWindow()
        windows[1].isFullscreen = true
        let rects = try await arrangedRects()
        assertEquals(rects[2], Rect(topLeftX: 0, topLeftY: 0, width: width, height: 1080))
        assertEquals(rects[1], Rect(topLeftX: 0, topLeftY: 0, width: width, height: height))
    }

    /// Switching tags parks the windows nobody is looking at off screen, and brings back the rest
    func testHideAndUnhideOnTagSwitch() async throws {
        let windows = newWindows([1, 2])
        windows[1].tags = TagMask(index: 1)
        _ = try await arrangedRects()
        assertEquals(windows[0].isHiddenInCornerForTest, false)
        assertEquals(windows[1].isHiddenInCornerForTest, true)

        await parseCommand("view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        _ = try await arrangedRects()
        assertEquals(windows[0].isHiddenInCornerForTest, true)
        assertEquals(windows[1].isHiddenInCornerForTest, false)
    }
}
