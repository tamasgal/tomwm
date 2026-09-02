@testable import AppBundle
import Common
import XCTest

@MainActor
final class ExecCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParseExecCommand() {
        testParseSingleCommandSucc("exec-and-forget echo 'foo'", ExecAndForgetCmdArgs(bashScript: " echo 'foo'"))
    }
}
