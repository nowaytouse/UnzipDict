import SwiftUI
import AppKit

@main
struct UnzipDictApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(UnzipEngine.shared)
                .frame(minWidth: 480, minHeight: 580)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupStatusItem()
        // 悬浮窗默认不显示
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "lock.open.fill", accessibilityDescription: "UnzipDict")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "显示悬浮密码框", action: #selector(showFloating), keyEquivalent: "f"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window != floatingWindow {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
    
    @objc func showFloating() {
        Task { @MainActor in
            if floatingWindow == nil {
                createFloatingWindow()
            }
            floatingWindow?.orderFront(nil)
        }
    }
    
    @MainActor
    func createFloatingWindow() {
        let contentView = FloatingPasswordView(onClose: { [weak self] in
            self?.floatingWindow?.orderOut(nil)
        })
        .environmentObject(UnzipEngine.shared)
        
        floatingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        floatingWindow?.level = .floating
        floatingWindow?.isOpaque = false
        floatingWindow?.backgroundColor = .clear
        floatingWindow?.contentView = NSHostingView(rootView: contentView)
        floatingWindow?.isMovableByWindowBackground = true
        floatingWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 300
            let y = screen.frame.maxY - 100
            floatingWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
