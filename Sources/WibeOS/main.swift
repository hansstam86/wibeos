import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

// Main menu (so Cmd+Q / Cmd+V etc. work)
let mainMenu = NSMenu()

let appItem = NSMenuItem()
mainMenu.addItem(appItem)
let appMenu = NSMenu()
appMenu.addItem(NSMenuItem(title: "Log Out Persona", action: #selector(AppDelegate.logoutPersona(_:)), keyEquivalent: "L"))
appMenu.addItem(NSMenuItem(title: "Reboot wibeOS", action: #selector(AppDelegate.reboot(_:)), keyEquivalent: "r"))
appMenu.addItem(NSMenuItem(title: "Reset API Key…", action: #selector(AppDelegate.resetKey(_:)), keyEquivalent: ""))
appMenu.addItem(.separator())
appMenu.addItem(NSMenuItem(title: "Quit wibeOS", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
appItem.submenu = appMenu

let editItem = NSMenuItem()
mainMenu.addItem(editItem)
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
editItem.submenu = editMenu

let viewItem = NSMenuItem()
mainMenu.addItem(viewItem)
let viewMenu = NSMenu(title: "View")
viewMenu.addItem(NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f"))
viewItem.submenu = viewMenu

app.mainMenu = mainMenu
app.run()
