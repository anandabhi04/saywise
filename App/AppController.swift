import AppKit
import ChirpCore
import ChirpEngines
import Observation
import OSLog
import ServiceManagement

@MainActor
@Observable
final class AppController {
    enum Status: Equatable {
        case starting
        case loadingModels(String)
        case ready
        case recording
        case working
        case paused
        case failed(String)
    }

    /// Where a recording was started. The main window keeps its text; the others paste.
    enum RecordingSource: Equatable {
        case hotkey
        case floatingButton
        case window
    }

    private(set) var status: Status = .starting
    private(set) var modelProgress: Double = 0
    /// Bumped after each saved dictation so the History window reloads.
    private(set) var historyRevision = 0
    private(set) var recordingSource: RecordingSource?
    var settingsError: String?
    var settings: ChirpSettings {
        didSet { settingsChanged(from: oldValue) }
    }

    let paths = ChirpPaths.standard
    let history: HistoryStore?

    private static let logger = Logger(subsystem: "dev.chirp.app", category: "dictation")

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let clipStore: AudioClipStore
    @ObservationIgnored private let hotkey = HotkeyMonitor()
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private(set) lazy var bar = FloatingBarController(controller: self)
    @ObservationIgnored private var machine = HotkeyStateMachine()
    @ObservationIgnored private var lastHandsFree = false
    @ObservationIgnored private var transcriber: (any Transcriber)?
    @ObservationIgnored private var loadedEngine: SpeechEngine?
    @ObservationIgnored private var cleaner: MLXCleaner?
    @ObservationIgnored private var loadedCleanerID: String?
    @ObservationIgnored private var isLoadingModels = false
    @ObservationIgnored private var context = AppContext()
    @ObservationIgnored private var historyPurgeTimer: Task<Void, Never>?
    @ObservationIgnored private var handsFreeTimer: Task<Void, Never>?

    init() {
        settingsStore = SettingsStore(url: paths.settingsFile)
        clipStore = AudioClipStore(directory: paths.audioDirectory)
        do {
            settings = try settingsStore.load()
        } catch {
            let backup = paths.root.appendingPathComponent("settings.broken.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: paths.settingsFile, to: backup)
            settings = ChirpSettings()
            settingsError = "The settings file was broken. A copy is saved as settings.broken.json. Saywise started with default settings."
        }
        history = try? HistoryStore(path: paths.historyDatabase.path)
        recorder.onLevel = { [weak self] level in self?.bar.model.push(level) }
        hotkey.onEvent = { [weak self] event in self?.handle(event) }
    }

    var hotkeyIsRunning: Bool { hotkey.isRunning }

    var needsSetup: Bool { Permission.allCases.contains { !$0.isGranted } }

    func start() {
        hotkey.triggerKey = settings.triggerKey
        bar.setVisible(settings.showFloatingButton)
        startHotkeyIfAllowed()
        historyPurgeTimer?.cancel()
        historyPurgeTimer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(86_400)) }
                catch { return }
                guard let self else { return }
                await self.purgeHistory()
            }
        }
        Task {
            await purgeHistory()
            await loadModels()
        }
    }

    func startHotkeyIfAllowed() {
        if Permission.inputMonitoring.isGranted { hotkey.start() }
    }

    func loadModels() async {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }

        while true {
            let engine = settings.speechEngine
            let cleanupModelID = settings.cleanupModelID
            do {
                if transcriber == nil || loadedEngine != engine {
                    modelProgress = 0
                    status = .loadingModels("Downloading and loading the speech model…")
                    bar.rest()
                    transcriber = try await EngineLoader.transcriber(
                        for: engine, modelsDirectory: paths.modelsDirectory,
                        progress: { [weak self] p in Task { @MainActor in self?.modelProgress = p } })
                    loadedEngine = engine
                }
                if cleaner == nil || loadedCleanerID != cleanupModelID {
                    modelProgress = 0
                    status = .loadingModels("Downloading and loading the cleanup model…")
                    bar.rest()
                    let loaded = try await MLXCleaner.load(
                        modelID: cleanupModelID, modelsDirectory: paths.modelsDirectory,
                        progress: { [weak self] p in Task { @MainActor in self?.modelProgress = p } })
                    await loaded.warmUp()
                    cleaner = loaded
                    loadedCleanerID = cleanupModelID
                }
                // Settings can change at any await; only become ready for the current pair.
                if loadedEngine != settings.speechEngine || loadedCleanerID != settings.cleanupModelID {
                    continue
                }
                status = .ready
                bar.rest()
                return
            } catch {
                if engine != settings.speechEngine || cleanupModelID != settings.cleanupModelID {
                    continue
                }
                status = .failed("Could not load models: \(error.localizedDescription)")
                bar.rest()
                WindowCoordinator.shared.showSetup()
                return
            }
        }
    }

    func redownloadModels() {
        guard canReloadModels else { return }
        transcriber = nil
        cleaner = nil
        try? FileManager.default.removeItem(at: paths.modelsDirectory)
        Task { await loadModels() }
    }

    func togglePause() {
        switch status {
        case .ready: status = .paused
        case .paused: status = .ready
        default: return
        }
        bar.rest()
    }

    var isMicOn: Bool { status != .paused }

    func setMicOn(_ on: Bool) {
        if on != isMicOn { togglePause() }
    }

    /// Click to start, click again to stop. Used by the floating button and the main window.
    func toggleRecording(from source: RecordingSource) {
        switch status {
        case .recording: stopRecording()
        case .ready: startRecording(from: source)
        case .loadingModels: bar.flash(.message("Getting ready · \(modelProgressText)", isError: false), for: 2)
        case .failed: bar.flash(.message("Saywise could not load its models", isError: true), for: 3)
        default: break
        }
    }

    func deleteHistoryEntry(_ entry: HistoryEntry) async {
        guard let history else { return }
        do {
            try await history.delete(id: entry.id)
        } catch {
            return
        }
        if let audioFileName = entry.audioFileName {
            try? clipStore.delete(fileName: audioFileName)
        }
        historyRevision += 1
    }

    func clearHistory() async {
        try? await history?.deleteAll()
        try? clipStore.deleteAll()
        historyRevision += 1
    }

    // MARK: - Dictation

    private func handle(_ event: HotkeyEvent) {
        switch machine.handle(event) {
        case .start: startRecording(from: .hotkey)
        case .stop: stopRecording()
        case .cancel: cancelRecording()
        case .none: break
        }
        if status == .recording, lastHandsFree != machine.isHandsFree {
            lastHandsFree = machine.isHandsFree
            bar.show(.listening(handsFree: lastHandsFree))
        }
    }

    private func startRecording(from source: RecordingSource) {
        guard status == .ready else {
            if case .loadingModels = status { bar.flash(.message("Getting ready", isError: true), for: 3) }
            if case .failed = status { bar.flash(.message("Saywise could not load its models", isError: true), for: 3) }
            // The press is ignored, so the next press must start fresh.
            machine = HotkeyStateMachine()
            return
        }
        guard Permission.microphone.isGranted else {
            machine = HotkeyStateMachine()
            bar.flash(.message("Microphone not allowed", isError: true), for: 3)
            WindowCoordinator.shared.showSetup()
            return
        }
        // The main window is in front while it records, so reading the front app would find Saywise.
        context = source == .window
            ? AppContext(bundleID: Bundle.main.bundleIdentifier, appName: "Saywise")
            : ContextReader.current()
        do {
            try recorder.start()
        } catch {
            machine = HotkeyStateMachine()
            bar.flash(.message("Microphone not available", isError: true), for: 3)
            return
        }
        status = .recording
        recordingSource = source
        lastHandsFree = isHandsFree
        bar.show(.listening(handsFree: isHandsFree))
        playSound("Tink")
        if source != .hotkey || machine.isHandsFree { scheduleHandsFreeTimeout() }
    }

    private func stopRecording() {
        guard status == .recording, let transcriber, let cleaner else { return }
        handsFreeTimer?.cancel()
        let samples = recorder.stop()
        let source = recordingSource ?? .hotkey
        // A click can stop a hotkey recording, so the key's next press must start fresh.
        machine = HotkeyStateMachine()
        status = .working
        bar.show(.finishing)
        playSound("Pop")
        let audioFileName = settings.keepAudio && settings.historyRetention != .off
            ? try? clipStore.save(samples) : nil
        let input = DictationInput(
            samples: samples, context: context, settings: settings,
            audioFileName: audioFileName)
        let pipeline = DictationPipeline(
            transcriber: transcriber, cleaner: cleaner,
            inserter: source == .window ? KeepInWindowInserter() as any TextInserter : PasteInserter(),
            history: settings.historyRetention == .off ? nil : history)
        Task {
            let outcome = await pipeline.run(input)
            switch outcome {
            case .noSpeech:
                if let audioFileName {
                    try? clipStore.delete(fileName: audioFileName)
                }
            case let .transcriptionFailed(error):
                Self.logger.error("Transcription failed: \(error, privacy: .public); audio clip: \(audioFileName ?? "none", privacy: .public)")
            case .delivered:
                break
            }
            finish(outcome, source: source)
        }
    }

    private func cancelRecording() {
        guard status == .recording else { return }
        handsFreeTimer?.cancel()
        recorder.cancel()
        status = .ready
        recordingSource = nil
        bar.rest()
    }

    private func finish(_ outcome: DictationOutcome, source: RecordingSource) {
        status = .ready
        recordingSource = nil
        switch outcome {
        case .noSpeech:
            bar.flash(.message("No speech heard", isError: true), for: 3)
        case .transcriptionFailed:
            bar.flash(.message("Could not hear you", isError: true), for: 3)
        case let .delivered(result):
            if source == .window {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result.finalText, forType: .string)
                bar.flash(.copied, for: 3)
            } else {
                switch result.insert {
                case .pasted: bar.flash(.pasted, for: 0.4)
                case .copiedNoTextField, .copiedNoPermission: bar.flash(.copied, for: 3)
                }
            }
            markDictionaryUsed(result.usedDictionaryEntryIDs)
            historyRevision += 1
        }
        // A model change made while dictating is applied now.
        if loadedEngine != settings.speechEngine || loadedCleanerID != settings.cleanupModelID {
            Task { await loadModels() }
        }
    }

    private func scheduleHandsFreeTimeout() {
        handsFreeTimer?.cancel()
        handsFreeTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(HotkeyStateMachine.handsFreeLimit))
            guard !Task.isCancelled, let self else { return }
            if self.recordingSource == .hotkey {
                self.handle(.handsFreeTimeout)
            } else {
                self.stopRecording()
            }
        }
    }

    private func markDictionaryUsed(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let now = Date()
        var dictionary = settings.dictionary
        for index in dictionary.indices where ids.contains(dictionary[index].id) {
            dictionary[index].lastUsedAt = now
        }
        settings.dictionary = dictionary
    }

    private func playSound(_ name: String) {
        guard settings.soundsEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: - Settings

    private var canReloadModels: Bool {
        switch status {
        case .ready, .failed, .paused: true
        default: false
        }
    }

    private func settingsChanged(from old: ChirpSettings) {
        do {
            try settingsStore.save(settings)
        } catch {
            settingsError = "Could not save settings: \(error.localizedDescription)"
        }
        if old.triggerKey != settings.triggerKey {
            hotkey.triggerKey = settings.triggerKey
            machine = HotkeyStateMachine()
        }
        if old.launchAtLogin != settings.launchAtLogin { applyLaunchAtLogin() }
        if old.showFloatingButton != settings.showFloatingButton {
            bar.setVisible(settings.showFloatingButton)
        }
        if old.historyRetention != settings.historyRetention { Task { await purgeHistory() } }
        let modelsChanged = old.speechEngine != settings.speechEngine || old.cleanupModelID != settings.cleanupModelID
        if modelsChanged && canReloadModels { Task { await loadModels() } }
    }

    private func applyLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settingsError = "Could not change start at login: \(error.localizedDescription)"
        }
    }

    private func purgeHistory() async {
        guard let days = settings.historyRetention.days else { return }
        if days == 0 {
            try? await history?.deleteAll()
            try? clipStore.deleteAll()
        } else {
            if let purged = try? await history?.purge(olderThan: Date().addingTimeInterval(-Double(days) * 86_400)) {
                for fileName in purged.audioFileNames {
                    try? clipStore.delete(fileName: fileName)
                }
            }
        }
        historyRevision += 1
    }

    // MARK: - Display

    var shouldShowSetup: Bool {
        switch status {
        case .loadingModels, .failed: true
        default: needsSetup
        }
    }

    var isHandsFree: Bool { machine.isHandsFree }

    var statusText: String {
        switch status {
        case .starting, .loadingModels: "Getting ready"
        case .ready: "Ready"
        case .recording: "Listening"
        case .working: "Finishing"
        case .paused: "Mic is off"
        case .failed: "Needs attention"
        }
    }

    var statusHint: String {
        status == .ready ? "Hold \(settings.triggerKey.displayName) in any app" : ""
    }

    var modelProgressText: String {
        if let bytes = modelBytes, bytes.total > 0 {
            let f = ByteCountFormatter(); f.countStyle = .file
            return "\(f.string(fromByteCount: bytes.done)) of \(f.string(fromByteCount: bytes.total))"
        }
        return "\(Int((modelProgress * 100).rounded()))%"
    }

    private(set) var modelBytes: (done: Int64, total: Int64)?
    var loadingDetail: String { if case let .loadingModels(m) = status { m } else { "" } }
    var failureDetail: String { if case let .failed(m) = status { m } else { "" } }

    var menuBarSymbol: String {
        switch status {
        case .starting, .loadingModels: "arrow.down.circle"
        case .ready: "waveform"
        case .recording: "waveform.circle.fill"
        case .working: "ellipsis.circle"
        case .paused: "pause.circle"
        case .failed: "exclamationmark.triangle"
        }
    }
}

/// The main window shows the text itself, so nothing is pasted.
private struct KeepInWindowInserter: TextInserter {
    func insert(_ text: String) async -> InsertOutcome { .pasted }
}
