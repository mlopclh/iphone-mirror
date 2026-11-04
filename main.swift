// iPhone Mirror — shows a cable-connected iPhone's screen live on your Mac,
// including the Camera app (it uses the same CoreMediaIO capture path QuickTime uses).
// Frameless window, optional screen recording (Settings: ⌘, · Record: ⇧⌘R).
import Cocoa
import AVFoundation
import CoreMediaIO

// MARK: - Make iOS devices visible as capture sources

func enableScreenCaptureDevices() {
    var address = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    var allow: UInt32 = 1
    let err = CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address,
                                        0, nil, UInt32(MemoryLayout<UInt32>.size), &allow)
    if err != noErr { NSLog("iPhoneMirror: could not enable screen capture devices (\(err))") }
}

func iPhoneCaptureDevices() -> [AVCaptureDevice] {
    let types: [AVCaptureDevice.DeviceType]
    if #available(macOS 14.0, *) { types = [.external] } else { types = [.externalUnknown] }
    return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: nil, position: .unspecified)
        .devices
        .filter { $0.hasMediaType(.muxed) || $0.modelID.contains("iOS") }
}

// MARK: - Saved settings

enum Prefs {
    static var saveFolder: URL {
        get {
            if let p = UserDefaults.standard.string(forKey: "saveFolder") { return URL(fileURLWithPath: p) }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/iPhone Mirror")
        }
        set { UserDefaults.standard.set(newValue.path, forKey: "saveFolder") }
    }
    static var recordAudio: Bool {
        get { UserDefaults.standard.object(forKey: "recordAudio") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "recordAudio") }
    }
    static var revealWhenDone: Bool {
        get { UserDefaults.standard.object(forKey: "revealWhenDone") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "revealWhenDone") }
    }
    static var showRecBadge: Bool {
        get { UserDefaults.standard.object(forKey: "showRecBadge") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showRecBadge") }
    }
}

// MARK: - Video view

final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(previewLayer)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override var mouseDownCanMoveWindow: Bool { true }
}

// MARK: - Recording delegate (kept separate so AVFoundation can call it from any thread)

final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    var onStart: () -> Void = {}
    var onFinish: (URL, Error?) -> Void = { _, _ in }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { self.onStart() }
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { self.onFinish(outputFileURL, error) }
    }
}

// MARK: - Settings window

final class SettingsController: NSObject {
    var window: NSWindow?
    let pathLabel = NSTextField(labelWithString: "")

    func show() {
        if window == nil { build(); window?.center() }
        pathLabel.stringValue = Prefs.saveFolder.path
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func checkbox(_ title: String, _ on: Bool, _ action: Selector) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: self, action: action)
        b.state = on ? .on : .off
        return b
    }

    private func build() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 210),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "iPhone Mirror Settings"
        w.isReleasedWhenClosed = false

        let header = NSTextField(labelWithString: "Recording")
        header.font = .boldSystemFont(ofSize: 13)
        let hint = NSTextField(labelWithString: "Start or stop with ⇧⌘R, the Record menu, or by right-clicking the mirror.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)

        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        let choose = NSButton(title: "Choose…", target: self, action: #selector(chooseFolder))
        let open = NSButton(title: "Open", target: self, action: #selector(openFolder))
        let folderRow = NSStackView(views: [NSTextField(labelWithString: "Save to:"), pathLabel, choose, open])
        folderRow.orientation = .horizontal
        folderRow.spacing = 8

        let stack = NSStackView(views: [
            header, hint, folderRow,
            checkbox("Include iPhone audio in recordings", Prefs.recordAudio, #selector(toggleAudio(_:))),
            checkbox("Show the file in Finder when a recording stops", Prefs.revealWhenDone, #selector(toggleReveal(_:))),
            checkbox("Show a red REC badge in the mirror while recording", Prefs.showRecBadge, #selector(toggleBadge(_:))),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            folderRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        w.contentView = content
        window = w
    }

    @objc func chooseFolder() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = Prefs.saveFolder
        panel.beginSheetModal(for: window) { resp in
            if resp == .OK, let url = panel.url {
                Prefs.saveFolder = url
                self.pathLabel.stringValue = url.path
            }
        }
    }

    @objc func openFolder() {
        let url = Prefs.saveFolder
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    @objc func toggleAudio(_ s: NSButton) { Prefs.recordAudio = s.state == .on }
    @objc func toggleReveal(_ s: NSButton) { Prefs.revealWhenDone = s.state == .on }
    @objc func toggleBadge(_ s: NSButton) { Prefs.showRecBadge = s.state == .on }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    var window: NSWindow!
    let preview = PreviewView(frame: NSRect(x: 0, y: 0, width: 360, height: 780))
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let recBadge = NSTextField(labelWithString: "")
    let session = AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "iphonemirror.capture")
    let audioOut = AVCaptureAudioPreviewOutput()
    let movieOut = AVCaptureMovieFileOutput()
    let recDelegate = RecordingDelegate()
    let settings = SettingsController()
    var currentDevice: AVCaptureDevice?
    var currentInput: AVCaptureDeviceInput?
    let deviceMenu = NSMenu(title: "Device")
    var tokens: [NSObjectProtocol] = []
    var isFloating = false
    var playAudio = false
    var showControls = false
    var recording = false
    var recordStart = Date()
    var recTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenus()
        buildWindow()
        enableScreenCaptureDevices()
        observeDevices()
        audioOut.volume = 0
        preview.previewLayer.session = session
        recDelegate.onStart = { [weak self] in self?.recordingStarted() }
        recDelegate.onFinish = { [weak self] url, err in self?.recordingStopped(url: url, error: err) }

        setStatus("Connect your iPhone with a cable, unlock it, and tap “Trust” if asked…")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    self.setStatus("Camera access is off for iPhone Mirror.\nTurn it on in System Settings › Privacy & Security › Camera, then reopen the app.")
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
                self.refreshDevices()
            }
        }
        // iOS devices can take a couple of seconds to appear after enabling.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.refreshDevices() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard recording else { return .terminateNow }
        // Finish writing the movie file before quitting.
        recDelegate.onFinish = { _, _ in sender.reply(toApplicationShouldTerminate: true) }
        sessionQueue.async { self.movieOut.stopRecording() }
        return .terminateLater
    }

    // MARK: Window (frameless)

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 780),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "iPhone Mirror"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenPrimary]
        window.delegate = self
        applyControlsVisibility()

        let content = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        preview.frame = content.bounds
        preview.autoresizingMask = [.width, .height]
        preview.menu = buildContextMenu()
        content.addSubview(preview)

        statusLabel.textColor = .white
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(statusLabel)

        recBadge.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        recBadge.textColor = .white
        recBadge.drawsBackground = true
        recBadge.backgroundColor = .systemRed
        recBadge.wantsLayer = true
        recBadge.layer?.cornerRadius = 6
        recBadge.layer?.masksToBounds = true
        recBadge.isHidden = true
        recBadge.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(recBadge)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -40),
            recBadge.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            recBadge.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
        ])

        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applyControlsVisibility() {
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(b)?.isHidden = !showControls
        }
    }

    func setStatus(_ text: String?) {
        statusLabel.stringValue = text ?? ""
        statusLabel.isHidden = (text == nil)
    }

    func fitWindow(width: Int32, height: Int32) {
        guard width > 0, height > 0, !window.styleMask.contains(.fullScreen) else { return }
        let w = CGFloat(width), h = CGFloat(height)
        window.contentAspectRatio = NSSize(width: w, height: h)

        let current = window.frame.size
        let longSide = max(current.width, current.height)
        var size = h >= w ? NSSize(width: longSide * w / h, height: longSide)
                          : NSSize(width: longSide, height: longSide * h / w)
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let scale = min(1, (visible.width * 0.95) / size.width, (visible.height * 0.9) / size.height)
        size = NSSize(width: size.width * scale, height: size.height * scale)

        let old = window.frame
        var frame = NSRect(origin: .zero, size: size)
        frame.origin = NSPoint(x: old.midX - size.width / 2, y: old.midY - size.height / 2)
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        window.setFrame(frame, display: true, animate: true)
    }

    // MARK: Devices

    func observeDevices() {
        let nc = NotificationCenter.default
        tokens.append(nc.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDevices()
        })
        tokens.append(nc.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            if let dev = note.object as? AVCaptureDevice, dev.uniqueID == self.currentDevice?.uniqueID {
                self.stopCapture()
                self.setStatus("iPhone disconnected.\nReconnect the cable and unlock your iPhone.")
            }
            self.refreshDevices()
        })
        // Fires when the phone rotates (portrait <-> landscape) or the stream size changes.
        tokens.append(nc.addObserver(forName: AVCaptureInput.Port.formatDescriptionDidChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let port = note.object as? AVCaptureInput.Port,
                  port.input === self.currentInput, port.mediaType == .video,
                  let desc = port.formatDescription else { return }
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            self.fitWindow(width: dims.width, height: dims.height)
        })
    }

    func refreshDevices() {
        let devices = iPhoneCaptureDevices()

        deviceMenu.removeAllItems()
        if devices.isEmpty {
            let none = NSMenuItem(title: "No iPhone found", action: nil, keyEquivalent: "")
            none.isEnabled = false
            deviceMenu.addItem(none)
        }
        for d in devices {
            let item = NSMenuItem(title: d.localizedName, action: #selector(pickDevice(_:)), keyEquivalent: "")
            item.representedObject = d.uniqueID
            item.state = (d.uniqueID == currentDevice?.uniqueID) ? .on : .off
            item.target = self
            deviceMenu.addItem(item)
        }
        deviceMenu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        deviceMenu.addItem(refresh)

        if currentDevice == nil, let first = devices.first {
            startCapture(first)
        }
    }

    @objc func refreshAction() { refreshDevices() }

    @objc func pickDevice(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let dev = iPhoneCaptureDevices().first(where: { $0.uniqueID == id }) else { return }
        startCapture(dev)
    }

    func startCapture(_ device: AVCaptureDevice) {
        let input: AVCaptureDeviceInput
        do { input = try AVCaptureDeviceInput(device: device) }
        catch {
            setStatus("Couldn't open \(device.localizedName):\n\(error.localizedDescription)")
            return
        }
        currentDevice = device
        currentInput = input
        window.title = device.localizedName
        setStatus(nil)

        sessionQueue.async {
            if self.movieOut.isRecording { self.movieOut.stopRecording() }
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            if self.session.canAddInput(input) { self.session.addInput(input) }
            if self.session.canAddOutput(self.audioOut) { self.session.addOutput(self.audioOut) }
            self.session.commitConfiguration()
            self.useBestFormat(device)
            if !self.session.isRunning { self.session.startRunning() }
        }

        let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        fitWindow(width: dims.width, height: dims.height)
        refreshDevices()
    }

    func stopCapture() {
        currentDevice = nil
        currentInput = nil
        window.title = "iPhone Mirror"
        sessionQueue.async {
            if self.movieOut.isRecording { self.movieOut.stopRecording() }
            self.session.stopRunning()
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.commitConfiguration()
        }
    }

    // MARK: Recording

    @objc func toggleRecording() {
        if recording {
            sessionQueue.async { self.movieOut.stopRecording() }
            return
        }
        guard let device = currentDevice else { NSSound.beep(); return }

        let folder = Prefs.saveFolder
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { showError("Can't save to \(folder.path)", error); return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = folder.appendingPathComponent("iPhone Mirror \(fmt.string(from: Date())).mov")
        let withAudio = Prefs.recordAudio

        // The recorder is only attached while recording, so it can't lower live-view quality.
        sessionQueue.async {
            self.session.beginConfiguration()
            if self.session.canAddOutput(self.movieOut) { self.session.addOutput(self.movieOut) }
            self.session.commitConfiguration()
            self.useBestFormat(device)
            self.movieOut.connection(with: .audio)?.isEnabled = withAudio
            self.movieOut.startRecording(to: url, recordingDelegate: self.recDelegate)
        }
    }

    /// Pin the iPhone feed to its highest-resolution format (otherwise macOS may pick a lower one).
    /// Call on sessionQueue.
    func useBestFormat(_ device: AVCaptureDevice) {
        func area(_ f: AVCaptureDevice.Format) -> Int32 {
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return d.width * d.height
        }
        guard let best = device.formats.max(by: { area($0) < area($1) }) else { return }
        do {
            try device.lockForConfiguration()
            device.activeFormat = best
            device.unlockForConfiguration()
        } catch {
            NSLog("iPhoneMirror: couldn't set format (\(error))")
        }
    }

    func detachRecorder() {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            guard self.session.outputs.contains(self.movieOut) else { return }
            self.session.beginConfiguration()
            self.session.removeOutput(self.movieOut)
            self.session.commitConfiguration()
            self.useBestFormat(device)
        }
    }

    func recordingStarted() {
        recording = true
        recordStart = Date()
        updateBadge()
        recTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateBadge),
                                        userInfo: nil, repeats: true)
    }

    @objc func updateBadge() {
        let secs = Int(Date().timeIntervalSince(recordStart))
        recBadge.stringValue = String(format: "  ● REC %d:%02d  ", secs / 60, secs % 60)
        recBadge.isHidden = !(recording && Prefs.showRecBadge)
    }

    func recordingStopped(url: URL, error: Error?) {
        recording = false
        recTimer?.invalidate()
        recTimer = nil
        recBadge.isHidden = true
        detachRecorder()

        if FileManager.default.fileExists(atPath: url.path) {
            if Prefs.revealWhenDone { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        } else if let error {
            showError("Recording failed", error)
        }
    }

    func showError(_ title: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.beginSheetModal(for: window)
    }

    @objc func openRecordings() {
        let url = Prefs.saveFolder
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    @objc func showSettings() { settings.show() }

    // MARK: Menus

    func buildMenus() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide iPhone Mirror", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit iPhone Mirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let recItem = NSMenuItem()
        let recMenu = NSMenu(title: "Record")
        let rec = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "r")
        rec.keyEquivalentModifierMask = [.command, .shift]
        rec.target = self
        recMenu.addItem(rec)
        let openRec = NSMenuItem(title: "Open Recordings Folder", action: #selector(openRecordings), keyEquivalent: "")
        openRec.target = self
        recMenu.addItem(openRec)
        recItem.submenu = recMenu
        main.addItem(recItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        for item in viewMenuItems() { viewMenu.addItem(item) }
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let devItem = NSMenuItem()
        devItem.submenu = deviceMenu
        main.addItem(devItem)

        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = winMenu
        main.addItem(winItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = winMenu
    }

    func viewMenuItems(withShortcuts: Bool = true) -> [NSMenuItem] {
        func item(_ title: String, _ action: Selector, _ key: String, _ mods: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: withShortcuts ? key : "")
            i.keyEquivalentModifierMask = mods
            i.target = self
            return i
        }
        let fs = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)),
                            keyEquivalent: withShortcuts ? "f" : "")
        fs.keyEquivalentModifierMask = [.command, .control]
        return [
            item("Keep on Top", #selector(toggleFloat), "t"),
            item("Play iPhone Audio", #selector(toggleAudio), "a", [.command, .shift]),
            item("Show Window Buttons", #selector(toggleControls), "b", [.command, .shift]),
            .separator(),
            fs,
        ]
    }

    // Right-click menu on the mirror itself (handy since there's no title bar).
    func buildContextMenu() -> NSMenu {
        let m = NSMenu()
        let rec = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "")
        rec.target = self
        m.addItem(rec)
        m.addItem(.separator())
        for item in viewMenuItems(withShortcuts: false) { m.addItem(item) }
        m.addItem(.separator())
        let s = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: "")
        s.target = self
        m.addItem(s)
        m.addItem(withTitle: "Quit iPhone Mirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return m
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleRecording):
            item.title = recording ? "Stop Recording" : "Start Recording"
            return recording || currentDevice != nil
        case #selector(toggleFloat):
            item.state = isFloating ? .on : .off
        case #selector(toggleAudio):
            item.state = playAudio ? .on : .off
        case #selector(toggleControls):
            item.state = showControls ? .on : .off
        default: break
        }
        return true
    }

    @objc func toggleFloat() {
        isFloating.toggle()
        window.level = isFloating ? .floating : .normal
    }

    @objc func toggleAudio() {
        playAudio.toggle()
        audioOut.volume = playAudio ? 1 : 0
    }

    @objc func toggleControls() {
        showControls.toggle()
        applyControlsVisibility()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
