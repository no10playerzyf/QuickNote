import SwiftUI
import AppKit
import Carbon

final class QuickNotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: QuickNotePanel!
    private let store = SnippetStore()
    private var isPinned: Bool = false {
        didSet {
            updatePinMenuItem()
        }
    }
    private var hotKeyRef: EventHotKeyRef?
    private var pinMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?

    private let launchAgentURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.mac.QuickNote.plist")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        setupStatusItem()
        setupPanel()
        registerGlobalHotKey()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出贴贴便利贴", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "note.text", accessibilityDescription: "贴贴便利贴")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "贴贴便利贴 (⌥V)"
            button.action = #selector(statusBarClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 500)
        panel = QuickNotePanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let rootView = ContentView(
            store: store,
            isPinned: Binding(
                get: { [weak self] in self?.isPinned ?? false },
                set: { [weak self] in self?.isPinned = $0 }
            ),
            onCopyAndMaybeHide: { [weak self] _ in
                guard let self else { return }
                if !self.isPinned {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                        if !self.isPinned {
                            self.hidePanel()
                        }
                    }
                }
            },
            onClose: { [weak self] in
                self?.hidePanel()
            }
        )

        panel.contentView = NSHostingView(rootView: rootView)
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePanel()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: panel.isVisible ? "隐藏便利贴 (⌥V)" : "显示便利贴 (⌥V)", action: #selector(togglePanelAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let pinItem = NSMenuItem(title: "固定在桌面（复制后不隐藏）", action: #selector(togglePinAction), keyEquivalent: "")
        pinItem.target = self
        pinItem.state = isPinned ? .on : .off
        self.pinMenuItem = pinItem
        menu.addItem(pinItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        self.launchAtLoginMenuItem = loginItem
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出贴贴便利贴", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePanelAction() {
        togglePanel()
    }

    @objc private func togglePinAction() {
        isPinned.toggle()
    }

    private func updatePinMenuItem() {
        pinMenuItem?.state = isPinned ? .on : .off
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        positionPanelNearStatusItem()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        panel.orderOut(nil)
    }

    private func positionPanelNearStatusItem() {
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let panelSize = panel.frame.size
            var x = screenRect.midX - panelSize.width / 2
            let y = screenRect.minY - panelSize.height - 6

            if let screen = buttonWindow.screen ?? NSScreen.main {
                let frame = screen.visibleFrame
                x = max(frame.minX + 8, min(x, frame.maxX - panelSize.width - 8))
            }
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.maxX - panel.frame.width - 16
            let y = frame.maxY - panel.frame.height - 16
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if !isPinned && panel.attachedSheet == nil {
            hidePanel()
        }
    }

    // MARK: - Global Hotkey (Option + V)
    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    delegate.togglePanel()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x514E5445), id: 1) // 'QNTE'
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if handlerStatus != noErr || registerStatus != noErr {
            NSLog("[QuickNote] Hotkey registration failed: handler=%d register=%d", handlerStatus, registerStatus)
            if let button = statusItem.button {
                button.toolTip = "贴贴便利贴（快捷键 ⌥V 注册失败，可能已被占用）"
            }
            let alert = NSAlert()
            alert.messageText = "全局快捷键 ⌥V 注册失败"
            alert.informativeText = "可能已被其他应用占用（错误码：\(registerStatus != noErr ? registerStatus : handlerStatus)）。你仍可通过点击右上角菜单栏图标打开便利贴。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        }
    }

    // MARK: - Launch at Login via LaunchAgent
    private func isLaunchAtLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    @objc private func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            try? FileManager.default.removeItem(at: launchAgentURL)
        } else {
            let fallbackPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/QuickNote.app/Contents/MacOS/QuickNote").path
            let execPath = Bundle.main.executablePath ?? fallbackPath
            let plist: [String: Any] = [
                "Label": "com.mac.QuickNote",
                "ProgramArguments": [execPath],
                "RunAtLoad": true
            ]
            let dir = launchAgentURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: launchAgentURL)
            }
        }
        launchAtLoginMenuItem?.state = isLaunchAtLoginEnabled() ? .on : .off
    }
}

@main
struct QuickNoteLauncher {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
