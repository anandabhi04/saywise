import Testing
@testable import ChirpCore

struct HotkeyStateMachineTests {
    @Test func holdThenReleaseStops() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.keyDown(0)) == .start)
        #expect(m.handle(.keyUp(1.0)) == .stop)
    }

    @Test func shortTapCancels() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.keyDown(0)) == .start)
        #expect(m.handle(.keyUp(0.1)) == .cancel)
    }

    @Test func doubleTapEntersHandsFreeUntilNextPress() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.keyDown(0)) == .start)
        #expect(m.handle(.keyUp(0.1)) == .cancel)
        #expect(m.handle(.keyDown(0.3)) == .start)
        #expect(m.isHandsFree)
        #expect(m.handle(.keyUp(0.4)) == .none)
        #expect(m.handle(.keyDown(5)) == .stop)
        #expect(m.handle(.keyUp(5.1)) == .none)
        #expect(!m.isHandsFree)
    }

    @Test func slowSecondTapIsNormalHold() {
        var m = HotkeyStateMachine()
        _ = m.handle(.keyDown(0))
        _ = m.handle(.keyUp(0.1))
        #expect(m.handle(.keyDown(1.0)) == .start)
        #expect(!m.isHandsFree)
        #expect(m.handle(.keyUp(2.0)) == .stop)
    }

    @Test func escapeAndOtherKeysCancel() {
        var m = HotkeyStateMachine()
        _ = m.handle(.keyDown(0))
        #expect(m.handle(.otherKey) == .cancel)
        _ = m.handle(.keyDown(5))
        #expect(m.handle(.escape) == .cancel)
        #expect(m.handle(.keyUp(6)) == .none)
    }

    @Test func handsFreeIgnoresOtherKeysAndStopsOnTimeout() {
        var m = HotkeyStateMachine()
        _ = m.handle(.keyDown(0)); _ = m.handle(.keyUp(0.1))
        _ = m.handle(.keyDown(0.2)); _ = m.handle(.keyUp(0.3))
        #expect(m.handle(.otherKey) == .none)
        #expect(m.handle(.handsFreeTimeout) == .stop)
    }
}
