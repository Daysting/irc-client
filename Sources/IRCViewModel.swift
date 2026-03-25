import Foundation

struct ClosedPrivateTabEntry: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let target: String
}

private struct PersistedPane: Codable {
    let id: String
    let title: String
    let type: IRCWindowType
    let target: String
    let unreadCount: Int
}

private struct PersistedPaneSession: Codable {
    let panes: [PersistedPane]
    let selectedWindowID: String
}

struct IRCWindowPane: Identifiable, Equatable {
    static let serverID = "server"

    let id: String
    var title: String
    var type: IRCWindowType
    var target: String
    var logs: [String]
    var unreadCount: Int

    static let server = IRCWindowPane(
        id: IRCWindowPane.serverID,
        title: "Server",
        type: .server,
        target: "",
        logs: ["Ready. Configure nick/channel and connect."],
        unreadCount: 0
    )
}

struct IRCChannelUser: Identifiable, Equatable {
    let nick: String
    let prefix: String

    var id: String {
        nick.lowercased()
    }

    var displayName: String {
        prefix + nick
    }

    var statusLabel: String {
        switch prefix {
        case "~":
            return "owner"
        case "&":
            return "admin"
        case "@":
            return "op"
        case "%":
            return "half-op"
        case "+":
            return "voice"
        default:
            return "user"
        }
    }

    var statusRank: Int {
        switch prefix {
        case "~":
            return 5
        case "&":
            return 4
        case "@":
            return 3
        case "%":
            return 2
        case "+":
            return 1
        default:
            return 0
        }
    }
}

@MainActor
final class IRCViewModel: ObservableObject {
    static let lockedHost = "irc.daysting.com"
    static let lockedPort: UInt16 = 6697
    static let lockedTLS = true

    enum ThemeImportStrategy {
        case replaceExistingNames
        case keepBoth
    }

    @Published var config = IRCServerConfig() {
        didSet {
            persistConnectionProfileIfNeeded()
        }
    }
    @Published var input = ""
    @Published var isConnected = false
    @Published var isOperator = false
    @Published private(set) var windows: [IRCWindowPane] = [IRCWindowPane.server] {
        didSet {
            persistPaneSessionIfNeeded()
        }
    }
    @Published var selectedWindowID: String = IRCWindowPane.serverID {
        didSet {
            persistPaneSessionIfNeeded()
        }
    }
    @Published var savedThemes: [AppearanceThemePreset] = [] {
        didSet {
            persistSavedThemesIfNeeded()
        }
    }
    @Published var selectedThemeID: String = ""
    @Published var themeDraftName: String = ""
    @Published var themeStatusMessage: String = ""
    @Published var themeStatusIsError: Bool = false
    @Published private(set) var channelUsersByPaneID: [String: [String: String]] = [:]
    @Published private(set) var channelTopicsByPaneID: [String: String] = [:]

    private let client = IRCClient()
    private var isRestoringState = false
    private var closedPrivateHistory: [ClosedPrivateTabEntry] = [] {
        didSet {
            persistClosedPrivateHistory()
        }
    }
    private let historyStorageKey = "DaystingIRC.closedPrivateHistory.v1"
    private let paneSessionStorageKey = "DaystingIRC.paneSession.v1"
    private let profileStorageKey = "DaystingIRC.connectionProfile.v1"
    private let themesStorageKey = "DaystingIRC.savedThemes.v1"
    private let maxPersistedHistory = 50
    private var pendingNamesByPaneID: [String: [String: String]] = [:]

    init() {
        isRestoringState = true
        config = loadConnectionProfile()
        // The client is intentionally locked to the production Daysting endpoint.
        config.host = Self.lockedHost
        config.port = Self.lockedPort
        config.useTLS = Self.lockedTLS
        closedPrivateHistory = loadClosedPrivateHistory()
        savedThemes = loadSavedThemes()
        selectedThemeID = savedThemes.first?.id ?? ""
        restorePaneSession()
        isRestoringState = false

        client.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleIncomingLine(message)
            }
        }

        client.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.appendLog("[status] \(status)", to: IRCWindowPane.serverID)
                if status.starts(with: "Connected") {
                    self?.isConnected = true
                }
                if status == "Connection closed" || status.starts(with: "Connection failed") {
                    self?.isConnected = false
                    self?.isOperator = false
                }
            }
        }

        client.onOperatorStatusChanged = { [weak self] state in
            Task { @MainActor in
                self?.isOperator = state
            }
        }
    }

    var contextualCommands: [IRCContextCommand] {
        IRCCommandCatalog.commands.filter { $0.windowTypes.contains(activeWindow.type) }
    }

    var activeWindow: IRCWindowPane {
        windows.first(where: { $0.id == selectedWindowID }) ?? IRCWindowPane.server
    }

    var activeWindowTitle: String {
        activeWindow.title
    }

    var activeLogs: [String] {
        activeWindow.logs
    }

    var activeUserList: [IRCChannelUser] {
        switch activeWindow.type {
        case .channel:
            let users = channelUsersByPaneID[activeWindow.id] ?? [:]
            return users
                .map { IRCChannelUser(nick: $0.key, prefix: $0.value) }
                .sorted {
                    if $0.statusRank != $1.statusRank {
                        return $0.statusRank > $1.statusRank
                    }
                    return $0.nick.localizedCaseInsensitiveCompare($1.nick) == .orderedAscending
                }
        case .privateMessage:
            guard !activeWindow.target.isEmpty else { return [] }
            return [IRCChannelUser(nick: activeWindow.target, prefix: "")]
        case .server:
            return []
        }
    }

    var activeChannelTopic: String {
        guard activeWindow.type == .channel else { return "" }
        let topic = channelTopicsByPaneID[activeWindow.id]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return topic.isEmpty ? "No topic set" : topic
    }

    var profileValidationErrors: [String] {
        var errors: [String] = []
        if !config.channel.hasPrefix("#") {
            errors.append("Primary channel must start with #")
        }
        return errors
    }

    var profileValidationWarnings: [String] {
        var warnings: [String] = []

        let invalidAutoJoin = invalidAutoJoinEntries()
        if !invalidAutoJoin.isEmpty {
            warnings.append("Ignoring invalid auto-join entries: \(invalidAutoJoin.joined(separator: ", "))")
        }

        let hasOperName = !config.operName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasOperPassword = !config.operPassword.isEmpty
        if hasOperName != hasOperPassword {
            warnings.append("OPER automation requires both OPER Name and OPER Password")
        }

        if config.enableSASL && config.saslMechanism == .plain && config.saslPassword.isEmpty {
            warnings.append("SASL PLAIN is enabled without a SASL password")
        }

        return warnings
    }

    var canConnectWithCurrentProfile: Bool {
        profileValidationErrors.isEmpty
    }

    var isHostInvalid: Bool {
        false
    }

    var isPrimaryChannelInvalid: Bool {
        !config.channel.hasPrefix("#")
    }

    var hasInvalidAutoJoinEntries: Bool {
        !invalidAutoJoinEntries().isEmpty
    }

    var isOperConfigurationIncomplete: Bool {
        let hasOperName = !config.operName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasOperPassword = !config.operPassword.isEmpty
        return hasOperName != hasOperPassword
    }

    var isNickServConfigurationIncomplete: Bool {
        false
    }

    var isSASLPlainConfigurationIncomplete: Bool {
        config.enableSASL && config.saslMechanism == .plain && config.saslPassword.isEmpty
    }

    var hasSelectedSavedTheme: Bool {
        savedThemes.contains(where: { $0.id == selectedThemeID })
    }

    func saveCurrentTheme() {
        let trimmed = themeDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let clampedSize = max(10, min(24, config.appearanceFontSize))
        if let existingIndex = savedThemes.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            let existingID = savedThemes[existingIndex].id
            savedThemes[existingIndex] = AppearanceThemePreset(
                id: existingID,
                name: trimmed,
                fontFamily: config.appearanceFontFamily,
                fontSize: clampedSize,
                textColor: config.appearanceTextColor,
                backgroundColor: config.appearanceBackgroundColor
            )
            selectedThemeID = existingID
            appendLog("[theme] Overwrote theme \(trimmed)", to: IRCWindowPane.serverID)
            setThemeStatus("Overwrote theme \(trimmed)", isError: false)
            return
        }

        let preset = AppearanceThemePreset(
            id: UUID().uuidString,
            name: trimmed,
            fontFamily: config.appearanceFontFamily,
            fontSize: clampedSize,
            textColor: config.appearanceTextColor,
            backgroundColor: config.appearanceBackgroundColor
        )
        savedThemes.append(preset)
        selectedThemeID = preset.id
        appendLog("[theme] Saved theme \(preset.name)", to: IRCWindowPane.serverID)
        setThemeStatus("Saved theme \(preset.name)", isError: false)
    }

    func applySelectedTheme() {
        guard let theme = savedThemes.first(where: { $0.id == selectedThemeID }) else { return }
        config.enableCustomAppearance = true
        config.appearanceFontFamily = theme.fontFamily
        config.appearanceFontSize = max(10, min(24, theme.fontSize))
        config.appearanceTextColor = theme.textColor
        config.appearanceBackgroundColor = theme.backgroundColor
        appendLog("[theme] Applied theme \(theme.name)", to: IRCWindowPane.serverID)
        setThemeStatus("Applied theme \(theme.name)", isError: false)
    }

    func deleteSelectedTheme() {
        guard let index = savedThemes.firstIndex(where: { $0.id == selectedThemeID }) else { return }
        let removedName = savedThemes[index].name
        savedThemes.remove(at: index)
        selectedThemeID = savedThemes.first?.id ?? ""
        appendLog("[theme] Deleted theme \(removedName)", to: IRCWindowPane.serverID)
        setThemeStatus("Deleted theme \(removedName)", isError: false)
    }

    func resetAppearanceToDefaults() {
        config.enableCustomAppearance = false
        config.appearanceFontFamily = .system
        config.appearanceFontSize = 13
        config.appearanceTextColor = .defaultText
        config.appearanceBackgroundColor = .defaultBackground
        appendLog("[theme] Appearance reset to defaults", to: IRCWindowPane.serverID)
        setThemeStatus("Appearance reset to defaults", isError: false)
    }

    func exportThemesData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(savedThemes)
    }

    @discardableResult
    func importThemesData(_ data: Data, strategy: ThemeImportStrategy) -> Int {
        let decoder = JSONDecoder()
        guard let incoming = try? decoder.decode([AppearanceThemePreset].self, from: data) else {
            setThemeStatus("Import failed: invalid theme JSON", isError: true)
            return 0
        }

        var updates = 0
        for theme in incoming {
            let normalizedName = theme.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { continue }

            let normalized = AppearanceThemePreset(
                id: theme.id.isEmpty ? UUID().uuidString : theme.id,
                name: normalizedName,
                fontFamily: theme.fontFamily,
                fontSize: max(10, min(24, theme.fontSize)),
                textColor: theme.textColor,
                backgroundColor: theme.backgroundColor
            )

            switch strategy {
            case .replaceExistingNames:
                if let index = savedThemes.firstIndex(where: { $0.name.caseInsensitiveCompare(normalized.name) == .orderedSame }) {
                    let preservedID = savedThemes[index].id
                    savedThemes[index] = AppearanceThemePreset(
                        id: preservedID,
                        name: normalized.name,
                        fontFamily: normalized.fontFamily,
                        fontSize: normalized.fontSize,
                        textColor: normalized.textColor,
                        backgroundColor: normalized.backgroundColor
                    )
                    selectedThemeID = preservedID
                    updates += 1
                } else {
                    savedThemes.append(normalized)
                    selectedThemeID = normalized.id
                    updates += 1
                }
            case .keepBoth:
                let uniqueName = uniqueImportedThemeName(baseName: normalized.name)
                let imported = AppearanceThemePreset(
                    id: UUID().uuidString,
                    name: uniqueName,
                    fontFamily: normalized.fontFamily,
                    fontSize: normalized.fontSize,
                    textColor: normalized.textColor,
                    backgroundColor: normalized.backgroundColor
                )
                savedThemes.append(imported)
                selectedThemeID = imported.id
                updates += 1
            }
        }

        if updates == 0 {
            setThemeStatus("Import completed: no valid themes found", isError: true)
            return 0
        }

        appendLog("[theme] Imported \(updates) theme(s)", to: IRCWindowPane.serverID)
        setThemeStatus("Imported \(updates) theme(s)", isError: false)
        return updates
    }

    func setThemeStatus(_ message: String, isError: Bool) {
        themeStatusMessage = message
        themeStatusIsError = isError
    }

    private func uniqueImportedThemeName(baseName: String) -> String {
        if !savedThemes.contains(where: { $0.name.caseInsensitiveCompare(baseName) == .orderedSame }) {
            return baseName
        }

        let importedBase = "\(baseName) (Imported)"
        if !savedThemes.contains(where: { $0.name.caseInsensitiveCompare(importedBase) == .orderedSame }) {
            return importedBase
        }

        var suffix = 2
        while savedThemes.contains(where: { $0.name.caseInsensitiveCompare("\(importedBase) \(suffix)") == .orderedSame }) {
            suffix += 1
        }
        return "\(importedBase) \(suffix)"
    }

    func connect() {
        config.host = Self.lockedHost
        config.port = Self.lockedPort
        config.useTLS = Self.lockedTLS

        for channel in autoJoinChannels(from: config) {
            ensureChannelPane(channel)
        }

        let saslState: String
        if config.enableSASL {
            switch config.saslMechanism {
            case .plain:
                saslState = config.saslPassword.isEmpty ? "off" : "plain"
            case .external:
                saslState = "external"
            }
        } else {
            saslState = "off"
        }
        let nickServState = config.nickServPassword.isEmpty ? "off" : "on"
        let delayedJoinState = (config.delayJoinUntilNickServIdentify && !config.nickServPassword.isEmpty) ? "on(\(config.nickServIdentifyTimeoutSeconds)s)" : "off"
        appendLog("[action] Connecting to \(config.host):\(config.port) TLS=\(config.useTLS) SASL=\(saslState) NickServ=\(nickServState) DelayJoin=\(delayedJoinState)", to: IRCWindowPane.serverID)
        pendingNamesByPaneID.removeAll()
        channelUsersByPaneID.removeAll()
        channelTopicsByPaneID.removeAll()
        client.connect(config: config)
    }

    func disconnect() {
        client.disconnect()
        isConnected = false
        isOperator = false
        pendingNamesByPaneID.removeAll()
        channelUsersByPaneID.removeAll()
        channelTopicsByPaneID.removeAll()
        appendLog("[action] Disconnected", to: IRCWindowPane.serverID)
    }

    func selectWindow(_ windowID: String) {
        selectedWindowID = windowID
        clearUnread(for: windowID)
    }

    func canCloseWindow(_ windowID: String) -> Bool {
        guard let pane = windows.first(where: { $0.id == windowID }) else { return false }
        return pane.type == .privateMessage || pane.type == .channel
    }

    var canReopenLastPrivateWindow: Bool {
        !closedPrivateHistory.isEmpty
    }

    var recentClosedPrivateWindows: [ClosedPrivateTabEntry] {
        var seen = Set<String>()
        var recent: [ClosedPrivateTabEntry] = []

        for pane in closedPrivateHistory.reversed() {
            guard !seen.contains(pane.id) else { continue }
            seen.insert(pane.id)
            recent.append(pane)
            if recent.count >= 10 {
                break
            }
        }

        return recent
    }

    func closeWindow(_ windowID: String) {
        guard canCloseWindow(windowID) else { return }
        guard let pane = windows.first(where: { $0.id == windowID }) else { return }

        if pane.type == .privateMessage {
            recordClosedPrivatePane(pane)
        }

        if pane.type == .channel {
            if isConnected, !pane.target.isEmpty {
                client.sendRaw("PART \(pane.target) :Leaving")
                appendLog("> PART \(pane.target) :Leaving", to: IRCWindowPane.serverID)
            }
            channelUsersByPaneID.removeValue(forKey: pane.id)
            channelTopicsByPaneID.removeValue(forKey: pane.id)
            pendingNamesByPaneID.removeValue(forKey: pane.id)
        }

        windows.removeAll { $0.id == windowID }

        if selectedWindowID == windowID {
            selectedWindowID = IRCWindowPane.serverID
            clearUnread(for: IRCWindowPane.serverID)
        }
    }

    func closeOtherPrivateWindows(keeping windowID: String) {
        let toClose = windows.filter { $0.type == .privateMessage && $0.id != windowID }
        guard !toClose.isEmpty else { return }

        toClose.forEach { recordClosedPrivatePane($0) }
        windows.removeAll { $0.type == .privateMessage && $0.id != windowID }

        if selectedWindowID != IRCWindowPane.serverID,
            !windows.contains(where: { $0.id == selectedWindowID })
        {
            selectedWindowID = IRCWindowPane.serverID
            clearUnread(for: IRCWindowPane.serverID)
        }

        appendLog("[action] Closed other private tabs", to: IRCWindowPane.serverID)
    }

    func closeAllPrivateWindows() {
        let privateIDs = windows
            .filter { $0.type == .privateMessage }
            .map { $0.id }

        guard !privateIDs.isEmpty else { return }
        windows
            .filter { $0.type == .privateMessage }
            .forEach { recordClosedPrivatePane($0) }
        windows.removeAll { $0.type == .privateMessage }

        if privateIDs.contains(selectedWindowID) {
            selectedWindowID = IRCWindowPane.serverID
            clearUnread(for: IRCWindowPane.serverID)
        }

        appendLog("[action] Closed all private tabs", to: IRCWindowPane.serverID)
    }

    func reopenLastClosedPrivateWindow() {
        guard let pane = closedPrivateHistory.popLast() else { return }
        guard !windows.contains(where: { $0.id == pane.id }) else { return }

        let restored = IRCWindowPane(
            id: pane.id,
            title: pane.title,
            type: .privateMessage,
            target: pane.target,
            logs: ["[restored] Private tab reopened"],
            unreadCount: 0
        )
        windows.append(restored)
        selectedWindowID = restored.id
        clearUnread(for: restored.id)
        appendLog("[action] Reopened private tab \(restored.title)", to: IRCWindowPane.serverID)
    }

    func reopenClosedPrivateWindow(windowID: String) {
        guard let historyIndex = closedPrivateHistory.lastIndex(where: { $0.id == windowID }) else { return }
        let pane = closedPrivateHistory.remove(at: historyIndex)
        guard !windows.contains(where: { $0.id == pane.id }) else { return }

        let restored = IRCWindowPane(
            id: pane.id,
            title: pane.title,
            type: .privateMessage,
            target: pane.target,
            logs: ["[restored] Private tab reopened"],
            unreadCount: 0
        )
        windows.append(restored)
        selectedWindowID = restored.id
        clearUnread(for: restored.id)
        appendLog("[action] Reopened private tab \(restored.title)", to: IRCWindowPane.serverID)
    }

    func sendCurrentInput() {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        input = ""
        send(command: command)
    }

    func executeAnopeCommand(_ command: String) {
        let cleaned = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        send(command: cleaned)
    }

    func send(shortcut: ServiceShortcut) {
        send(command: shortcut.commandTemplate)
    }

    func executeContextCommand(_ template: IRCContextCommand) {
        if template.requiresOperator && !isOperator {
            appendLog("[blocked] Operator privileges required for \(template.title)", to: activeWindow.id)
            return
        }

        let expanded = expandCommandTemplate(template.command)
        if expanded.contains("<") && expanded.contains(">") {
            input = expanded
            appendLog("[hint] Fill placeholders and send: \(expanded)", to: activeWindow.id)
            return
        }

        send(command: expanded)
    }

    func openPrivateConversation(with nick: String) {
        let cleaned = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        ensurePrivatePane(cleaned)
        selectWindow(paneID(for: cleaned))
    }

    func prefillWhois(for nick: String) {
        let cleaned = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        input = "/WHOIS \(cleaned)"
    }

    func prefillMention(for nick: String) {
        let cleaned = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let mention = "\(cleaned): "
        if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input = mention
        } else if !input.contains(cleaned) {
            input = "\(mention)\(input)"
        }
    }

    func performChannelUserMode(_ action: ChannelUserModeAction, for nick: String) {
        let cleanedNick = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedNick.isEmpty else { return }

        guard activeWindow.type == .channel else {
            appendLog("[hint] \(action.title) is only available in channel windows", to: activeWindow.id)
            return
        }

        let channel = activeWindow.target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard channel.hasPrefix("#") else {
            appendLog("[hint] No active channel available for \(action.title.lowercased())", to: activeWindow.id)
            return
        }

        send(command: "/MODE \(channel) \(action.modeChange) \(cleanedNick)")
    }

    private func send(command: String) {
        if let expanded = expandedAnopeAlias(command) {
            client.sendRaw(expanded)
            appendLog("> \(expanded)", to: activeWindow.id)
            return
        }

        if command.lowercased().hasPrefix("/me") {
            let payload = command.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !payload.isEmpty else {
                appendLog("[hint] Usage: /me <action>", to: activeWindow.id)
                return
            }

            let target = messageTarget()
            if target.hasPrefix("#") {
                ensureChannelPane(target)
            } else {
                ensurePrivatePane(target)
            }

            client.sendRaw("PRIVMSG \(target) :\u{1}ACTION \(payload)\u{1}")
            appendLog("* \(config.nickname) \(payload)", to: paneID(for: target))
            return
        }

        if command.hasPrefix("/") {
            let raw = String(command.dropFirst())
            if isOperatorCommand(raw) && !isOperator {
                appendLog("[blocked] Operator command requires server operator login", to: activeWindow.id)
                return
            }
            client.sendRaw(raw)
            appendLog("> \(raw)", to: activeWindow.id)
            return
        }

        let target = messageTarget()
        if target.hasPrefix("#") {
            ensureChannelPane(target)
        } else {
            ensurePrivatePane(target)
        }
        client.sendMessage(channel: target, message: command)
        appendLog("<\(config.nickname)> \(command)", to: paneID(for: target))
    }

    private func expandCommandTemplate(_ template: String) -> String {
        let target = messageTarget()
        return template
            .replacingOccurrences(of: "{target}", with: target)
            .replacingOccurrences(of: "{channel}", with: channelTarget(for: activeWindow))
            .replacingOccurrences(of: "{nick}", with: config.nickname)
    }

    private func messageTarget() -> String {
        switch activeWindow.type {
        case .server:
            return config.channel
        case .channel, .privateMessage:
            return activeWindow.target.isEmpty ? config.channel : activeWindow.target
        }
    }

    private func channelTarget(for pane: IRCWindowPane) -> String {
        if pane.type == .channel, !pane.target.isEmpty {
            return pane.target
        }
        return config.channel
    }

    private func isOperatorCommand(_ raw: String) -> Bool {
        let commandName = raw.split(separator: " ", omittingEmptySubsequences: true).first?.uppercased() ?? ""
        if commandName == "OPER" {
            return false
        }

        let restricted: Set<String> = [
            "KILL",
            "REHASH",
            "RESTART",
            "DIE",
            "WALLOPS",
            "GLOBOPS",
            "CONNECT",
            "SQUIT"
        ]
        return restricted.contains(commandName)
    }

    private func handleIncomingLine(_ line: String) {
        appendLog(line, to: IRCWindowPane.serverID, markUnread: true)

        if let topicEvent = parseTopicEvent(line) {
            ensureChannelPane(topicEvent.channel)
            setChannelTopic(topicEvent.topic, forChannel: topicEvent.channel)
        }

        processUserListEvent(line)

        if let channel = parseOwnJoinChannel(line) {
            ensureChannelPane(channel)
            upsertUser(config.nickname, inChannel: channel)
            return
        }

        if let routed = parseIncomingPrivmsgTarget(line) {
            if routed.target.hasPrefix("#") {
                ensureChannelPane(routed.target)
            } else {
                ensurePrivatePane(routed.target)
            }

            if routed.isAction {
                appendLog("* \(routed.sender) \(routed.message)", to: paneID(for: routed.target), markUnread: true)
            } else {
                appendLog("<\(routed.sender)> \(routed.message)", to: paneID(for: routed.target), markUnread: true)
            }

            if routed.target.hasPrefix("#") {
                upsertUser(routed.sender, inChannel: routed.target)
            }
        }
    }

    private func parseOwnJoinChannel(_ line: String) -> String? {
        guard line.contains(" JOIN ") else { return nil }
        guard line.hasPrefix(":") else { return nil }

        let prefixEnd = line.firstIndex(of: " ") ?? line.endIndex
        let prefix = String(line[line.index(after: line.startIndex)..<prefixEnd])
        let senderNick = prefix.split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""
        guard senderNick.caseInsensitiveCompare(config.nickname) == .orderedSame else { return nil }

        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let joinIndex = parts.firstIndex(of: "JOIN"), parts.indices.contains(joinIndex + 1) else { return nil }
        let rawChannel = String(parts[joinIndex + 1]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return rawChannel.hasPrefix("#") ? rawChannel : nil
    }

    private func parseIncomingPrivmsgTarget(_ line: String) -> (target: String, sender: String, message: String, isAction: Bool)? {
        guard line.hasPrefix(":"), line.contains(" PRIVMSG ") else { return nil }

        let prefixEnd = line.firstIndex(of: " ") ?? line.endIndex
        let prefix = String(line[line.index(after: line.startIndex)..<prefixEnd])
        let sender = prefix.split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""

        guard let privmsgRange = line.range(of: " PRIVMSG ") else { return nil }
        let afterPrivmsg = line[privmsgRange.upperBound...]
        let split = afterPrivmsg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let target = split.first.map(String.init) ?? ""
        guard !target.isEmpty else { return nil }

        let message = parseTrailingMessage(from: line)
        let actionPrefix = "\u{1}ACTION "
        let isAction = message.hasPrefix(actionPrefix) && message.hasSuffix("\u{1}")
        let normalizedMessage: String
        if isAction {
            normalizedMessage = String(message.dropFirst(actionPrefix.count).dropLast())
        } else {
            normalizedMessage = message
        }

        if target.caseInsensitiveCompare(config.nickname) == .orderedSame, !sender.isEmpty {
            return (target: sender, sender: sender, message: normalizedMessage, isAction: isAction)
        }
        return (target: target, sender: sender, message: normalizedMessage, isAction: isAction)
    }

    private func parseTopicEvent(_ line: String) -> (channel: String, topic: String?)? {
        if line.hasPrefix(":"), line.contains(" 332 ") {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard tokens.count >= 4 else { return nil }
            let channel = tokens[3].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard channel.hasPrefix("#") else { return nil }
            let topic = parseTrailingMessage(from: line)
            return (channel: channel, topic: topic)
        }

        if line.hasPrefix(":"), line.contains(" 331 ") {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard tokens.count >= 4 else { return nil }
            let channel = tokens[3].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard channel.hasPrefix("#") else { return nil }
            return (channel: channel, topic: nil)
        }

        if line.hasPrefix(":"), line.contains(" TOPIC ") {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard tokens.count >= 3 else { return nil }
            guard tokens[1] == "TOPIC" else { return nil }
            let channel = tokens[2].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard channel.hasPrefix("#") else { return nil }
            let topic = parseTrailingMessage(from: line)
            return (channel: channel, topic: topic)
        }

        return nil
    }

    private func parseTrailingMessage(from line: String) -> String {
        guard let range = line.range(of: " :") else { return "" }
        return String(line[range.upperBound...])
    }

    private func setChannelTopic(_ topic: String?, forChannel channel: String) {
        let key = paneID(for: channel)
        let cleaned = topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if cleaned.isEmpty {
            channelTopicsByPaneID.removeValue(forKey: key)
        } else {
            channelTopicsByPaneID[key] = cleaned
        }
    }

    private func processUserListEvent(_ line: String) {
        if let names = parseNamesReply(line) {
            mergePendingNames(names.users, forChannel: names.channel)
            return
        }

        if let endNames = parseEndOfNames(line) {
            commitPendingNames(forChannel: endNames)
            return
        }

        if let join = parseJoinEvent(line) {
            upsertUser(join.nick, inChannel: join.channel)
            return
        }

        if let part = parsePartEvent(line) {
            removeUser(part.nick, fromChannel: part.channel)
            return
        }

        if let mode = parseChannelModeEvent(line) {
            applyChannelModeEvent(mode)
            return
        }

        if let nick = parseNickChangeEvent(line) {
            renameUser(oldNick: nick.oldNick, newNick: nick.newNick)
            return
        }

        if let quitNick = parseQuitEvent(line) {
            removeUserFromAllChannels(quitNick)
        }
    }

    private func parseNamesReply(_ line: String) -> (channel: String, users: [String: String])? {
        guard line.hasPrefix(":"), line.contains(" 353 ") else { return nil }
        guard let trailing = line.range(of: " :") else { return nil }

        let header = String(line[..<trailing.lowerBound])
        let tokens = header.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard tokens.count >= 5 else { return nil }

        let channel = tokens[4]
        guard channel.hasPrefix("#") else { return nil }

        let nickListRaw = String(line[trailing.upperBound...])
        let users = nickListRaw
            .split(separator: " ", omittingEmptySubsequences: true)
            .compactMap { parseNickWithPrefix(String($0)) }
            .reduce(into: [String: String]()) { result, entry in
                result[entry.nick] = strongerPrefix(result[entry.nick] ?? "", entry.prefix)
            }

        return (channel: channel, users: users)
    }

    private func parseEndOfNames(_ line: String) -> String? {
        guard line.hasPrefix(":"), line.contains(" 366 ") else { return nil }
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard tokens.count >= 4 else { return nil }
        let channel = tokens[3].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return channel.hasPrefix("#") ? channel : nil
    }

    private func parseJoinEvent(_ line: String) -> (nick: String, channel: String)? {
        guard line.hasPrefix(":"), line.contains(" JOIN ") else { return nil }
        guard let commandRange = line.range(of: " JOIN ") else { return nil }

        let prefix = String(line[line.index(after: line.startIndex)..<commandRange.lowerBound])
        let nick = prefix.split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""
        guard !nick.isEmpty else { return nil }

        let suffix = String(line[commandRange.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard suffix.hasPrefix("#") else { return nil }
        return (nick: nick, channel: suffix)
    }

    private func parsePartEvent(_ line: String) -> (nick: String, channel: String)? {
        guard line.hasPrefix(":"), line.contains(" PART ") else { return nil }
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
        guard tokens.count >= 3 else { return nil }
        let nick = tokens[0].dropFirst().split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""
        let channel = String(tokens[2]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard !nick.isEmpty, channel.hasPrefix("#") else { return nil }
        return (nick: nick, channel: channel)
    }

    private func parseQuitEvent(_ line: String) -> String? {
        guard line.hasPrefix(":"), line.contains(" QUIT") else { return nil }
        let nick = line
            .dropFirst()
            .split(separator: "!", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        return nick.isEmpty ? nil : nick
    }

    private func parseNickChangeEvent(_ line: String) -> (oldNick: String, newNick: String)? {
        guard line.hasPrefix(":"), line.contains(" NICK ") else { return nil }
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
        guard tokens.count >= 3 else { return nil }

        let oldNick = tokens[0].dropFirst().split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""
        let newNick = String(tokens[2]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard !oldNick.isEmpty, !newNick.isEmpty else { return nil }
        return (oldNick: oldNick, newNick: newNick)
    }

    private func parseChannelModeEvent(_ line: String) -> (channel: String, modeString: String, args: [String])? {
        guard line.hasPrefix(":"), line.contains(" MODE ") else { return nil }
        let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard tokens.count >= 4 else { return nil }
        guard tokens[1] == "MODE" else { return nil }

        let channel = tokens[2].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard channel.hasPrefix("#") else { return nil }

        let modeString = tokens[3].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        let args = tokens.count > 4 ? Array(tokens.dropFirst(4)) : []
        return (channel: channel, modeString: modeString, args: args)
    }

    private func parseNickWithPrefix(_ token: String) -> (nick: String, prefix: String)? {
        guard !token.isEmpty else { return nil }

        let validPrefixes = "~&@%+"
        var prefix = ""
        var nickStart = token.startIndex
        while nickStart < token.endIndex, validPrefixes.contains(token[nickStart]) {
            let current = String(token[nickStart])
            prefix = strongerPrefix(prefix, current)
            nickStart = token.index(after: nickStart)
        }

        let nick = String(token[nickStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nick.isEmpty else { return nil }
        return (nick: nick, prefix: prefix)
    }

    private func strongerPrefix(_ lhs: String, _ rhs: String) -> String {
        let order = ["": 0, "+": 1, "%": 2, "@": 3, "&": 4, "~": 5]
        let leftRank = order[lhs] ?? 0
        let rightRank = order[rhs] ?? 0
        return rightRank > leftRank ? rhs : lhs
    }

    private func prefix(for mode: Character) -> String {
        switch mode {
        case "q":
            return "~"
        case "a":
            return "&"
        case "o":
            return "@"
        case "h":
            return "%"
        case "v":
            return "+"
        default:
            return ""
        }
    }

    private func applyChannelModeEvent(_ event: (channel: String, modeString: String, args: [String])) {
        let trackedModes: Set<Character> = ["q", "a", "o", "h", "v"]
        var addMode = true
        var argIndex = 0
        let key = paneID(for: event.channel)

        for mode in event.modeString {
            if mode == "+" {
                addMode = true
                continue
            }
            if mode == "-" {
                addMode = false
                continue
            }
            guard trackedModes.contains(mode) else { continue }
            guard event.args.indices.contains(argIndex) else { break }

            let nick = normalizeNickToken(event.args[argIndex])
            argIndex += 1
            guard !nick.isEmpty else { continue }

            var users = channelUsersByPaneID[key] ?? [:]
            if addMode {
                let granted = prefix(for: mode)
                users[nick] = strongerPrefix(users[nick] ?? "", granted)
            } else {
                // On removal we conservatively keep known lower modes when available,
                // otherwise fall back to regular user status.
                let removed = prefix(for: mode)
                if users[nick] == removed {
                    users[nick] = ""
                }
            }
            channelUsersByPaneID[key] = users
        }
    }

    private func normalizeNickToken(_ token: String) -> String {
        parseNickWithPrefix(token)?.nick ?? token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergePendingNames(_ users: [String: String], forChannel channel: String) {
        let key = paneID(for: channel)
        var pending = pendingNamesByPaneID[key] ?? [:]
        for (nick, prefix) in users {
            pending[nick] = strongerPrefix(pending[nick] ?? "", prefix)
        }
        pendingNamesByPaneID[key] = pending
    }

    private func commitPendingNames(forChannel channel: String) {
        let key = paneID(for: channel)
        guard let pending = pendingNamesByPaneID[key] else { return }
        channelUsersByPaneID[key] = pending
        pendingNamesByPaneID.removeValue(forKey: key)
    }

    private func upsertUser(_ nick: String, inChannel channel: String) {
        let normalizedNick = normalizeNickToken(nick)
        guard !normalizedNick.isEmpty else { return }

        let key = paneID(for: channel)
        var users = channelUsersByPaneID[key] ?? [:]
        users[normalizedNick] = strongerPrefix(users[normalizedNick] ?? "", "")
        channelUsersByPaneID[key] = users
    }

    private func removeUser(_ nick: String, fromChannel channel: String) {
        let normalizedNick = normalizeNickToken(nick)
        guard !normalizedNick.isEmpty else { return }

        let key = paneID(for: channel)
        guard var users = channelUsersByPaneID[key] else { return }
        users.removeValue(forKey: normalizedNick)
        channelUsersByPaneID[key] = users
    }

    private func removeUserFromAllChannels(_ nick: String) {
        let normalizedNick = normalizeNickToken(nick)
        guard !normalizedNick.isEmpty else { return }
        for key in channelUsersByPaneID.keys {
            channelUsersByPaneID[key]?.removeValue(forKey: normalizedNick)
        }
    }

    private func renameUser(oldNick: String, newNick: String) {
        let oldNormalized = normalizeNickToken(oldNick)
        let newNormalized = normalizeNickToken(newNick)
        guard !oldNormalized.isEmpty, !newNormalized.isEmpty else { return }

        for key in channelUsersByPaneID.keys {
            if let oldPrefix = channelUsersByPaneID[key]?[oldNormalized] {
                channelUsersByPaneID[key]?.removeValue(forKey: oldNormalized)
                channelUsersByPaneID[key]?[newNormalized] = oldPrefix
            }
        }
    }

    private func ensureChannelPane(_ channel: String) {
        let id = paneID(for: channel)
        guard !windows.contains(where: { $0.id == id }) else { return }
        windows.append(
            IRCWindowPane(
                id: id,
                title: channel,
                type: .channel,
                target: channel,
                logs: [],
                unreadCount: 0
            )
        )
    }

    private func ensurePrivatePane(_ nick: String) {
        let id = paneID(for: nick)
        guard !windows.contains(where: { $0.id == id }) else { return }
        windows.append(
            IRCWindowPane(
                id: id,
                title: "@\(nick)",
                type: .privateMessage,
                target: nick,
                logs: [],
                unreadCount: 0
            )
        )
    }

    private func autoJoinChannels(from config: IRCServerConfig) -> [String] {
        let extras = config.autoJoinChannelsCSV
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("#") }

        var channels = [config.channel]
        for channel in extras where !channels.contains(where: { $0.caseInsensitiveCompare(channel) == .orderedSame }) {
            channels.append(channel)
        }
        return channels
    }

    private func invalidAutoJoinEntries() -> [String] {
        config.autoJoinChannelsCSV
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    private func recordClosedPrivatePane(_ pane: IRCWindowPane) {
        guard pane.type == .privateMessage else { return }
        closedPrivateHistory.append(
            ClosedPrivateTabEntry(
                id: pane.id,
                title: pane.title,
                target: pane.target
            )
        )
        if closedPrivateHistory.count > maxPersistedHistory {
            let overflow = closedPrivateHistory.count - maxPersistedHistory
            closedPrivateHistory.removeFirst(overflow)
        }
    }

    private func persistClosedPrivateHistory() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(closedPrivateHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyStorageKey)
    }

    private func loadClosedPrivateHistory() -> [ClosedPrivateTabEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyStorageKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([ClosedPrivateTabEntry].self, from: data)) ?? []
    }

    private func persistPaneSessionIfNeeded() {
        guard !isRestoringState else { return }
        persistPaneSession()
    }

    private func persistConnectionProfileIfNeeded() {
        guard !isRestoringState else { return }
        persistConnectionProfile()
    }

    private func persistSavedThemesIfNeeded() {
        guard !isRestoringState else { return }
        persistSavedThemes()
    }

    private func persistConnectionProfile() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(config) else { return }
        UserDefaults.standard.set(data, forKey: profileStorageKey)
    }

    private func loadConnectionProfile() -> IRCServerConfig {
        guard let data = UserDefaults.standard.data(forKey: profileStorageKey) else {
            return IRCServerConfig()
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode(IRCServerConfig.self, from: data)) ?? IRCServerConfig()
    }

    private func persistSavedThemes() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(savedThemes) else { return }
        UserDefaults.standard.set(data, forKey: themesStorageKey)
    }

    private func loadSavedThemes() -> [AppearanceThemePreset] {
        guard let data = UserDefaults.standard.data(forKey: themesStorageKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([AppearanceThemePreset].self, from: data)) ?? []
    }

    private func persistPaneSession() {
        let panes = windows.map { pane in
            PersistedPane(
                id: pane.id,
                title: pane.title,
                type: pane.type,
                target: pane.target,
                unreadCount: pane.unreadCount
            )
        }

        let session = PersistedPaneSession(
            panes: panes,
            selectedWindowID: selectedWindowID
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: paneSessionStorageKey)
    }

    private func restorePaneSession() {
        guard let data = UserDefaults.standard.data(forKey: paneSessionStorageKey) else { return }
        let decoder = JSONDecoder()
        guard let session = try? decoder.decode(PersistedPaneSession.self, from: data) else { return }

        var restored: [IRCWindowPane] = []
        var hasServerPane = false

        for pane in session.panes {
            if pane.type == .server {
                hasServerPane = true
            }
            restored.append(
                IRCWindowPane(
                    id: pane.id,
                    title: pane.title,
                    type: pane.type,
                    target: pane.target,
                    logs: [],
                    unreadCount: max(0, pane.unreadCount)
                )
            )
        }

        if !hasServerPane {
            restored.insert(IRCWindowPane.server, at: 0)
        }

        if restored.isEmpty {
            restored = [IRCWindowPane.server]
        }

        windows = restored
        if windows.contains(where: { $0.id == session.selectedWindowID }) {
            selectedWindowID = session.selectedWindowID
        } else {
            selectedWindowID = IRCWindowPane.serverID
        }
    }

    private func paneID(for target: String) -> String {
        if target.hasPrefix("#") {
            return "channel:\(target.lowercased())"
        }
        return "query:\(target.lowercased())"
    }

    private func appendLog(_ line: String, to windowID: String, markUnread: Bool = false) {
        guard let idx = windows.firstIndex(where: { $0.id == windowID }) else {
            if windowID == IRCWindowPane.serverID {
                windows[0].logs.append(line)
            }
            return
        }
        windows[idx].logs.append(line)

        if markUnread, windows[idx].id != selectedWindowID {
            windows[idx].unreadCount += 1
        }
    }

    private func clearUnread(for windowID: String) {
        guard let idx = windows.firstIndex(where: { $0.id == windowID }) else { return }
        windows[idx].unreadCount = 0
    }

    private func expandedAnopeAlias(_ command: String) -> String? {
        let parts = command.split(separator: " ", omittingEmptySubsequences: true)
        guard let head = parts.first?.lowercased() else { return nil }

        switch head {
        case "/ns":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG NickServ :HELP" }
            return "PRIVMSG NickServ :\(tail)"
        case "/cs":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG ChanServ :HELP" }
            return "PRIVMSG ChanServ :\(tail)"
        case "/ms":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG MemoServ :HELP" }
            return "PRIVMSG MemoServ :\(tail)"
        case "/os":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG OperServ :HELP" }
            return "PRIVMSG OperServ :\(tail)"
        case "/hs":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG HostServ :HELP" }
            return "PRIVMSG HostServ :\(tail)"
        case "/bs":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG BotServ :HELP" }
            return "PRIVMSG BotServ :\(tail)"
        default:
            return nil
        }
    }
}
