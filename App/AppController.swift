import AppKit
import ChirpCore
import ChirpEngines
import Observation
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

    private(set) var status: Status = .starting
    private(set) var modelProgress: Double = 0
    /// Bumped after each saved dictation so the History window reloads.
    private(set) var historyRevision = 0
    var settingsError: String?
    var settings: ChirpSettings {
        didSet { settingsChanged(from: oldValue) }
    }

    let paths = ChirpPaths.standard
    let history: HistoryStore?

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let clipStore: AudioClipStore
    @ObservationIgnored private let hotkey = HotkeyMonitor()
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored let pill = PillController()
    @ObservationIgnored private var machine = HotkeyStateMachine()
    @ObservationIgnored private var transcriber: (any Transcriber)?
    @ObservationIgnored private var loadedEngine: SpeechEngine?
    @ObservationIgnored private var cleaner: MLXCleaner?
    @ObservationIgnored private var loadedCleanerID: String?
    @ObservationIgnored private var isLoadingModels = false
    @ObservationIgnored private var context = AppContext()
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
            settingsError = "The settings file was broken. A copy is saved as settings.broken.json. Chirp started with default settings."
        }
        history = try? HistoryStore(path: paths.historyDatabase.path)
        recorder.onLevel = { [weak self] level in self?.pill.model.push(level) }
        hotkey.onEvent = { [weak self] event in self?.handle(event) }
    }

    var needsSetup: Bool { Permission.allCases.contains { !$0.isGranted } }

    func start() {
        hotkey.triggerKey = settings.triggerKey
        startHotkeyIfAllowed()
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
                    transcriber = try await EngineLoader.transcriber(
                        for: engine, modelsDirectory: paths.modelsDirectory,
                        progress: { [weak self] p in Task { @MainActor in self?.modelProgress = p } })
                    loadedEngine = engine
                }
                if cleaner == nil || loadedCleanerID != cleanupModelID {
                    modelProgress = 0
                    status = .loadingModels("Downloading and loading the cleanup model…")
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
                return
            } catch {
                if engine != settings.speechEngine || cleanupModelID != settings.cleanupModelID {
                    continue
                }
                status = .failed("Could not load models: \(error.localizedDescription)")
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
        case .start: startRecording()
        case .stop: stopRecording()
        case .cancel: cancelRecording()
        case .none: break
        }
    }

    private func startRecording() {
        guard status == .ready else {
            if case .loadingModels = status { pill.flash("Loading models…") }
            if case .failed = status { pill.flash("Models failed. Open setup.") }
            // The press is ignored, so the next press must start fresh.
            machine = HotkeyStateMachine()
            return
        }
        guard Permission.microphone.isGranted else {
            machine = HotkeyStateMachine()
            pill.flash("Mic not allowed")
            WindowCoordinator.shared.showSetup()
            return
        }
        context = ContextReader.current()
        do {
            try recorder.start()
        } catch {
            machine = HotkeyStateMachine()
            pill.flash("Mic not available")
            return
        }
        status = .recording
        pill.show(.recording)
        playSound("Tink")
        if machine.isHandsFree { scheduleHandsFreeTimeout() }
    }

    private func stopRecording() {
        guard status == .recording, let transcriber, let cleaner else { return }
        handsFreeTimer?.cancel()
        let samples = recorder.stop()
        status = .working
        pill.show(.working)
        playSound("Pop")
        let audioFileName = settings.keepAudio && settings.historyRetention != .off
            ? try? clipStore.save(samples) : nil
        let input = DictationInput(
            samples: samples, context: context, settings: settings,
            audioFileName: audioFileName)
        let pipeline = DictationPipeline(
            transcriber: transcriber, cleaner: cleaner, inserter: PasteInserter(),
            history: settings.historyRetention == .off ? nil : history)
        Task {
            let outcome = await pipeline.run(input)
            switch outcome {
            case .noSpeech, .transcriptionFailed:
                if let audioFileName {
                    try? clipStore.delete(fileName: audioFileName)
                }
            case .delivered:
                break
            }
            finish(outcome)
        }
    }

    private func cancelRecording() {
        guard status == .recording else { return }
        handsFreeTimer?.cancel()
        recorder.cancel()
        status = .ready
        pill.hide()
    }

    private func finish(_ outcome: DictationOutcome) {
        status = .ready
        switch outcome {
        case .noSpeech:
            pill.hide()
        case .transcriptionFailed:
            pill.flash("Couldn't transcribe")
        case let .delivered(result):
            switch result.insert {
            case .pasted: pill.hide()
            case .copiedNoTextField: pill.flash("Copied — no text field")
            case .copiedNoPermission: pill.flash("Copied — allow Accessibility to paste")
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
            guard !Task.isCancelled else { return }
            self?.handle(.handsFreeTimeout)
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
            _ = try? await history?.purge(olderThan: Date().addingTimeInterval(-Double(days) * 86_400))
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

    var statusText: String {
        switch status {
        case .starting: "Starting…"
        case let .loadingModels(message): message
        case .ready: "Ready — hold \(settings.triggerKey.displayName) to talk"
        case .recording: "Listening…"
        case .working: "Working…"
        case .paused: "Paused"
        case let .failed(message): message
        }
    }

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
