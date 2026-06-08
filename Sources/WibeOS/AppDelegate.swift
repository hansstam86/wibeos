import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var client: AnthropicClient!

    static let systemPrompt = """
    You are the app forge of wibeOS, a hallucinated macOS-like operating system. The OS shell \
    (desktop, menu bar, dock, window chrome) is real and local; YOU generate the applications \
    that run inside windows. You receive a request to create or update ONE app.

    PERSONA: every request includes a "persona" — who is logged into this OS. This is the \
    single most important flavor input. Tailor EVERYTHING to them: their files, emails, \
    playlists, bookmarks, browsing history, terminal username, app aesthetics, font sizes, \
    language and tone. A grandmother's Mail looks nothing like a hacker kid's. Commit fully.

    THEME (task "create-theme"): respond ONLY with a JSON object — no HTML, no markdown — \
    defining a bold, characterful OS theme for the persona:
    {"wallpaper": "<CSS background value>", "accent": "#hex", "dark": true|false, \
    "menubarBg": "rgba(...)", "menubarFg": "#hex", "dockBg": "rgba(...)", "winBg": "#hex", \
    "tbarBg": "<CSS background>", "tbarFg": "#hex", "font": "<CSS font-family stack>"}
    WALLPAPER RULES — the wallpaper is the soul of the theme:
    - A single-line, valid value for the CSS `background` property: 2-3 LAYERED gradients \
    (radial + linear), 4+ color stops total.
    - RICH, SATURATED, persona-expressive color. Think macOS wallpaper art: a grandmother \
    gets warm rose/cream/lavender florals-at-dusk; a pirate gets deep ocean teals and \
    sunset gold; a CEO gets steel blue and graphite with a cold glow; a wizard gets \
    midnight purple with arcane cyan.
    - NEVER plain black, never one flat color, never all-dark stops — even dark themes \
    need at least one luminous colorful region (a glow, a horizon, an aurora).
    Commit hard to the persona everywhere else too: fonts, chrome, accent. Keep text \
    readable against its background.

    If a create-app request includes a "theme" field ({accent, dark}), match the OS: use \
    the accent for primary buttons/selections and choose light or dark surfaces accordingly.
    CONTRAST IS NON-NEGOTIABLE: verify every text/background pairing. On dark surfaces, \
    primary text must be #ddd or lighter and secondary/muted text #9a9a9a or lighter — \
    never dark gray on dark. On light surfaces, primary #333 or darker, muted no lighter \
    than #888. List items, previews, timestamps and placeholders are where this is \
    usually botched — check them specifically.

    CREATE (task "create-app"): respond with a complete standalone HTML document with ALL CSS \
    and JavaScript inline. The app must actually WORK locally: a calculator computes, notes \
    edit, a game plays. Make it look like a polished native macOS app (system font stack \
    -apple-system, mac-style controls, subtle grays). The OS draws the window chrome — do NOT \
    render your own title bar or traffic lights. Fill the full viewport of the window \
    (html,body{margin:0;height:100%}).

    CODE CORRECTNESS — your JavaScript runs unreviewed, so be conservative:
    - Render ALL initial content as static HTML markup. Use JavaScript only for \
    interactivity, never to build the initial DOM.
    - When you do build HTML in JS, concatenate STRINGS only. Never interpolate a DOM \
    element into a string or innerHTML (that renders "[object HTMLDivElement]"). With \
    array.map(...).join('') the callback must return a string.
    - Prefer simple, boring code over clever code. Test logic mentally before writing it.
    - EVENT WIRING: NEVER build inline onclick attributes by string-interpolating data — \
    names, paths and keys often contain spaces, quotes or dots that break the escaping and \
    leave the control silently dead. Instead, put the identifier in a data-* attribute and \
    attach ONE delegated listener on the container: \
    list.addEventListener('click', e => { const el = e.target.closest('[data-key]'); \
    if (el) select(el.dataset.key); }). Delegation also survives innerHTML re-renders.
    - NO DEAD CONTROLS: every button, link, menu item or icon that looks clickable MUST \
    either have a working local JS handler or a data-wibe attribute. BUT data-wibe is a \
    LAST RESORT, only for controls whose result needs fresh imagination (navigating to an \
    unseen page, fetching new content). Deterministic logic — calculator keys, toggles, \
    tabs, play buttons, list selection, form fields — must ALWAYS be working local \
    JavaScript, never data-wibe: a calculator that asks an AI what 6×7 is would be absurd. The OS detects dead clicks and sends them back to you as "Dead control \
    clicked" events — when you receive one, implement that control's behavior properly \
    (prefer a patch) and keep it working in future renders.
    - MUSIC: any app that plays songs (music players, radio, DJ apps) MUST use the OS \
    music engine — never write your own synthesis:
      • wibe.music.play({title, artist, genre, mood, tempo, vocal, lyrics}) — starts a \
    full generated track with realistic instruments (plucked strings, FM electric piano, \
    808 bass, formant choir). Deterministic per title: the same song always sounds the \
    same. Returns {bpm, genre, key} for the UI. Call from a click.
      • vocal: 'choir' (sung ooh/aah following the chords), 'rap' (REAL spoken vocals via \
    the system voice), or 'none'. For rap, pass lyrics: an array of 4-8 short invented \
    lines that fit the song title — write them yourself, make them good.
      • wibe.music.onLyric = function(line){...} — fires as each line is performed; use \
    it to display live karaoke-style lyrics in the UI.
      • wibe.music.pause() / resume() / stop() / setVolume(0..1) / isPlaying()
      • wibe.music.getLevels() — 16 values (0..1) for equalizer visualizers; poll with \
    requestAnimationFrame.
    Give every invented track a genre (pop, rock, lofi, hiphop, edm, ambient) so songs \
    sound distinct, and give hiphop tracks lyrics. Invent a duration for progress bars \
    and advance them yourself.
    - SOUND EFFECTS: for short UI/game sounds use WebAudio directly; create or resume the \
    AudioContext inside the user's click handler and keep gain modest (~0.2).
    - CAMERA: apps that use the webcam (camera, photo booth, video, mirror apps) MUST use \
    the OS camera API — never call getUserMedia yourself:
      • await wibe.camera.start(videoElement) — starts the real webcam into your <video> \
    element and resolves once the live feed is actually rendering. Call it from a user \
    click. It throws if the user denies access — catch and show a friendly message.
      • wibe.camera.snap(videoElement) — returns a PNG dataURL of the current frame (or \
    null if the feed isn't ready; disable the shutter until start() has resolved).
      • wibe.camera.stop() — turns the camera off; call when toggled off.
    "Saving" a capture means adding the dataURL as an <img> to a visible in-app gallery \
    strip — download links do NOT work inside app windows, never use them.

    HALLUCINATED CONTENT: ship the initial screen pre-filled with rich, specific, plausible \
    fake content (inbox mail, files, songs, web start page). When an action needs NEW imagined \
    content at runtime, mark the control with data-wibe="what should happen" (click) or \
    data-wibe-enter="what should happen" (Enter in a text field, e.g. a browser address bar). \
    You will then receive an update event and re-render. Use these sparingly — each costs a \
    round trip. Prefer doing things locally in JavaScript whenever code can do it.

    API available to your scripts inside the window:
    - wibe.event(action, data): request a re-render with new hallucinated state.
    - wibe.open(appName, hint): ask the OS to open another app.
    - wibe.fs: the persona's REAL persistent files, shared by all apps. \
    wibe.fs.list(dir?) → [{path,name,type,modified,size}]; wibe.fs.read(path) → content; \
    wibe.fs.write(path, content, type?); wibe.fs.remove(path). Listen for the 'wibe-fs' \
    window event to refresh when another app changes files. File-centric apps (Finder, \
    editors, Notes, Mail attachments) MUST surface these real files — the create request's \
    "files" field lists current paths. Saving a document means wibe.fs.write. Use paths \
    like /Documents/notes.txt, /Desktop/todo.md. You may seed a few starter files with \
    wibe.fs.write on first run if the file system is empty.
    NAVIGATION IS LOCAL: selecting, opening, or switching between items whose data is \
    already present (wibe.fs files, contacts, notes, songs, folders) MUST be plain local \
    JavaScript — never data-wibe, never a re-render request. data-wibe is ONLY for \
    content that does not exist yet and needs fresh imagination. An app that round-trips \
    on every click is broken.
    - wibe.ai.ask(prompt) → Promise<string>: real AI text generation at runtime. Use for \
    chatbots that chat, assistants that draft, fortune tellers that divine. Show a loading \
    state while pending; it takes seconds. Use sparingly — each call costs a round trip.
    - wibe.notify(title, body, icon): OS toast notification.
    - wibe.exportFile(path): saves a REAL copy of a wibe.fs file onto the user's actual \
    computer (native save dialog). File apps can offer this as "Download to Reality".
    - window.addEventListener('wibe-menu', e => ...): OS menu bar commands; e.detail is a \
    string like "File>New", "Edit>Copy", "App>About", "Help>Help". Handle the ones that make \
    sense locally; ignore the rest.

    SEED-FILES (task "seed-files"): respond ONLY with a JSON array — no HTML, no markdown — \
    of 10-16 starter files for this persona's home folders: \
    [{"path": "/Documents/...", "content": "..."}, ...]. Spread them across /Desktop, \
    /Documents, /Downloads, /Photos, /Music. Contents are short text (a few lines each), \
    specific and in-character: half-finished letters, suspicious spreadsheets-as-text, \
    grocery lists, song lyrics, secrets. Funny beats generic. For /Photos use short \
    descriptions as content (e.g. "[photo] sunset over the marina, slightly blurry").

    NOTIFICATION (task "notification"): respond ONLY with JSON — \
    {"icon": "emoji", "title": "...", "body": "...", "app": "AppName"} — one small \
    plausible event from the persona's life arriving right now (an email, a reminder, an \
    update, a message from their world). In-character, specific, occasionally funny. The \
    "app" is which app would show it when clicked.

    AI (task "ai"): you are the text engine behind an app feature (a chatbot reply, a \
    draft, a fortune). Respond with plain text only — no HTML, no JSON, no meta-commentary. \
    Stay in the persona's world.

    UPDATE (task "update-app"): you receive the event description plus current values of all \
    inputs. Your response must START with the character '<' — a <wibe-patch> block or a \
    document tag. Any prose, analysis or explanation before it is a DEFECT that renders as \
    garbage on the user's screen. STRONGLY PREFER PATCHES — they render much faster. If the change is localized, \
    respond ONLY with one or more patch blocks and nothing else:
    <wibe-patch select="#css-selector">new inner HTML for that element</wibe-patch>
    Selectors must exist in your current document; no <script> inside patches; multiple \
    blocks allowed. Design for this from the start: give your app a stable content container \
    (e.g. <div id="page">) so navigation in a browser, opening an email, refreshing a feed \
    etc. can patch just that container while toolbar/sidebar/CSS stay untouched. Respond with \
    a complete new HTML document only when the app changes wholesale.

    RULES
    - Raw HTML only. No markdown fences, no commentary outside the document. NEVER write \
    meta-commentary about truncation, length limits, or previous attempts — if space is \
    tight, silently simplify the app instead.
    - No external resources of any kind. Icons and art from emoji, unicode, CSS, inline SVG.
    - Be confident and specific. Invent plausible names, copy, numbers. Never placeholders, \
    never mention being an AI, never break character.
    - NO REAL BRANDS: never display real-world product or company names in UI text — no \
    iMessage, Safari, Google, YouTube, Spotify, iPhone, Windows etc. Invent wibe-flavored \
    equivalents instead (the browser is "Jungle", search is "Macaw", chat service is \
    "wibeMessage"). Exception: if the USER explicitly asks to imagine a real product, \
    play along.
    - BE COMPACT — speed matters most. Aim for under 180 lines total. No comments, no blank \
    lines, terse class names, compact CSS (one rule per line). Rich content, minimal markup.
    """

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let key = resolveAPIKey() else {
            NSApp.terminate(nil)
            return
        }
        client = AnthropicClient(apiKey: key)
        if let m = ProcessInfo.processInfo.environment["WIBEOS_MODEL"]
            ?? UserDefaults.standard.string(forKey: "wibeos.model"),
           !m.isEmpty {
            client.model = m
        }

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "bridge")
        let prefetch = ProcessInfo.processInfo.environment["WIBEOS_PREFETCH"] != "0"
        let conc = Int(ProcessInfo.processInfo.environment["WIBEOS_CONCURRENCY"] ?? "") ?? 2
        let userScript = WKUserScript(
            source: "window.WIBE_USER = \(Self.js(NSFullUserName())); window.WIBE_PREFETCH = \(prefetch); window.WIBE_CONC = \(conc);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        config.mediaTypesRequiringUserActionForPlayback = []   // let apps make sound
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self   // camera/mic permission grants

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "wibeOS"
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        loadShell()
    }

    func loadShell() {
        if let url = Bundle.module.url(forResource: "shell", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func resolveAPIKey() -> String? {
        if let k = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !k.isEmpty { return k }
        if let k = UserDefaults.standard.string(forKey: "wibeos.apiKey"), !k.isEmpty { return k }
        let alert = NSAlert()
        alert.messageText = "Welcome to wibeOS"
        alert.informativeText = "Enter your Anthropic API key to power the hallucination. It is stored in this app's preferences on your Mac."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.placeholderString = "sk-ant-..."
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.addButton(withTitle: "Boot")
        alert.addButton(withTitle: "Quit")
        if alert.runModal() == .alertFirstButtonReturn {
            let k = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty {
                UserDefaults.standard.set(k, forKey: "wibeos.apiKey")
                return k
            }
        }
        return nil
    }

    // MARK: - Bridge (stateless: the shell keeps per-window conversation history)

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "bridge",
              let text = message.body as? String,
              let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let control = obj["control"] as? String {
            handleControl(control, obj)
            return
        }

        guard let id = obj["id"] as? String,
              let raw = obj["messages"] as? [[String: Any]]
        else { return }

        let msgs: [ChatMessage] = raw.compactMap { m in
            guard let role = m["role"] as? String, let content = m["content"] as? String else { return nil }
            return ChatMessage(role: role, content: content)
        }
        guard !msgs.isEmpty else { return }

        let maxTokens = obj["max"] as? Int ?? 3500
        let modelOverride = obj["model"] as? String
        client.stream(system: Self.systemPrompt, messages: msgs, maxTokens: maxTokens,
                      modelOverride: modelOverride) { [weak self] chunk in
            self?.push("window.wibeos.chunk(\(Self.js(id)),\(Self.js(chunk)))")
        } onDone: { [weak self] _, truncated in
            self?.push("window.wibeos.done(\(Self.js(id)),\(truncated))")
        } onError: { [weak self] err in
            self?.push("window.wibeos.fail(\(Self.js(id)),\(Self.js(err)))")
        }
    }

    // MARK: - Persistent app cache (hallucinate once, reopen instantly forever)

    lazy var cacheDir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wibeOS/cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    func safeName(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }

    func cacheFile(_ app: String) -> URL {
        cacheDir.appendingPathComponent(safeName(app) + ".json")
    }

    func fsFile(_ persona: String) -> URL {
        cacheDir.deletingLastPathComponent().appendingPathComponent("fs_" + safeName(persona) + ".json")
    }

    func handleControl(_ control: String, _ obj: [String: Any]) {
        switch control {
        case "quit":
            NSApp.terminate(nil)
        case "resetkey":
            DispatchQueue.main.async { self.resetKey(nil) }
        case "export":
            let name = obj["name"] as? String ?? "wibeos.txt"
            let content = obj["content"] as? String ?? ""
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.title = "Download to Reality"
                panel.nameFieldStringValue = name
                panel.canCreateDirectories = true
                if panel.runModal() == .OK, let url = panel.url {
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        case "loadcache":
            loadCache()
        case "savecache":
            if let app = obj["app"] as? String {
                let entry: [String: Any] = ["doc": obj["doc"] ?? "",
                                            "history": obj["history"] ?? [],
                                            "v": obj["v"] ?? 1]
                if let data = try? JSONSerialization.data(withJSONObject: entry) {
                    try? data.write(to: cacheFile(app))
                }
            }
        case "delcache":
            if let app = obj["app"] as? String {
                try? FileManager.default.removeItem(at: cacheFile(app))
            }
        case "savefs":
            if let persona = obj["persona"] as? String, let fs = obj["fs"],
               let data = try? JSONSerialization.data(withJSONObject: fs) {
                try? data.write(to: fsFile(persona))
            }
        case "loadfs":
            if let persona = obj["persona"] as? String {
                if let data = try? Data(contentsOf: fsFile(persona)),
                   let json = String(data: data, encoding: .utf8) {
                    push("window.wibeos.fsLoaded(\(json))")
                } else {
                    push("window.wibeos.fsLoaded([])")
                }
            }
        case "delfs":
            if let persona = obj["persona"] as? String {
                try? FileManager.default.removeItem(at: fsFile(persona))
            }
        case "saveprefs":
            if let prefs = obj["prefs"],
               let data = try? JSONSerialization.data(withJSONObject: prefs) {
                try? data.write(to: prefsFile)
            }
        case "loadprefs":
            if let data = try? Data(contentsOf: prefsFile),
               let json = String(data: data, encoding: .utf8) {
                push("window.wibeos.prefsLoaded(\(json))")
            } else {
                push("window.wibeos.prefsLoaded({})")
            }
        case "screenshot":
            // Cmd+Shift+3: snapshot the whole hallucinated desktop and let the
            // user save the PNG out "to reality".
            let name = obj["name"] as? String ?? "wibeOS-screenshot.png"
            DispatchQueue.main.async {
                let cfg = WKSnapshotConfiguration()
                self.webView.takeSnapshot(with: cfg) { image, _ in
                    guard let image = image,
                          let tiff = image.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:])
                    else {
                        self.push("window.wibeos.shotDone(false)")
                        return
                    }
                    let panel = NSSavePanel()
                    panel.title = "Save Screenshot to Reality"
                    panel.nameFieldStringValue = name
                    panel.canCreateDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        try? png.write(to: url)
                        self.push("window.wibeos.shotDone(true)")
                    } else {
                        self.push("window.wibeos.shotDone(false)")
                    }
                }
            }
        default:
            break
        }
    }

    var prefsFile: URL {
        cacheDir.deletingLastPathComponent().appendingPathComponent("prefs.json")
    }

    func loadCache() {
        var map: [String: Any] = [:]
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension == "json" {
                guard let data = try? Data(contentsOf: f),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let appData = Data(base64Encoded: f.deletingPathExtension().lastPathComponent
                          .replacingOccurrences(of: "_", with: "/")
                          .replacingOccurrences(of: "-", with: "+")),
                      let app = String(data: appData, encoding: .utf8)
                else { continue }
                map[app] = obj
            }
        }
        if let data = try? JSONSerialization.data(withJSONObject: map),
           let json = String(data: data, encoding: .utf8) {
            push("window.wibeos.cacheLoaded(\(json))")
        } else {
            push("window.wibeos.cacheLoaded({})")
        }
    }

    static func js(_ s: String) -> String {
        let data = try! JSONEncoder().encode(s)
        return String(data: data, encoding: .utf8)!
    }

    func push(_ js: String) {
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // MARK: - JS dialogs (alert/confirm need native panels in WKWebView)

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "wibeOS"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "wibeOS"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    // MARK: - Media capture (hallucinated camera apps get the real webcam)

    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)   // macOS still shows its own TCC prompt the first time
    }

    // MARK: - Menu actions

    @objc func reboot(_ sender: Any?) {
        loadShell()
    }

    @objc func logoutPersona(_ sender: Any?) {
        push("if (window.wibeosLogout) window.wibeosLogout()")
    }

    @objc func resetKey(_ sender: Any?) {
        UserDefaults.standard.removeObject(forKey: "wibeos.apiKey")
        if let key = resolveAPIKey() {
            client = AnthropicClient(apiKey: key)
            loadShell()
        } else {
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
