import Testing
@testable import ChirpCore

struct ListeningTimeTests {
    @Test func pausedTimeDoesNotUseListeningLimit() {
        var time = ListeningTime()
        time.resume(at: 10)
        #expect(time.remaining(at: 110) == 500)
        time.pause(at: 110)
        #expect(time.remaining(at: 10_000) == 500)
        time.resume(at: 10_000)
        #expect(time.remaining(at: 10_200) == 300)
        time.pause(at: 10_200)
        time.resume(at: 20_000)
        #expect(time.remaining(at: 20_299) == 1)
        #expect(time.remaining(at: 20_300) == 0)
        #expect(time.remaining(at: 20_400) == 0)
    }

    @Test func repeatedPauseAndResumeKeepElapsedTime() {
        var time = ListeningTime()
        time.pause(at: 0)
        time.resume(at: 10)
        time.resume(at: 20)
        time.pause(at: 40)
        time.pause(at: 90)
        #expect(time.remaining(at: 100) == 570)
        time.resume(at: 100)
        #expect(time.remaining(at: 110) == 560)
        time = ListeningTime()
        #expect(time.remaining(at: 1_000) == 600)
    }

    @Test func pausedHandsFreeStillStopsOnFnAndCancelsOnEscape() {
        for event in [HotkeyEvent.keyDown(10_000), .escape] {
            var machine = HotkeyStateMachine()
            _ = machine.handle(.keyDown(0))
            _ = machine.handle(.keyUp(0.1))
            _ = machine.handle(.keyDown(0.2))
            _ = machine.handle(.keyUp(0.3))
            var time = ListeningTime()
            time.resume(at: 0.2)
            time.pause(at: 10.2)
            #expect(time.remaining(at: 10_000) == 590)
            #expect(machine.isHandsFree)
            #expect(machine.handle(event) == (event == .escape ? .cancel : .stop))
            #expect(!machine.isHandsFree)
        }
    }

}
