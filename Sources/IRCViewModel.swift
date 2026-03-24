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

@MainActor
final class IRCViewModel: ObservableObject {
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
    private let maxPersistedHistory = 50

    init() {
        isRestoringState = true
        config = loadConnectionProfile()
        closedPrivateHistory = loadClosedPrivateHistory()
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

    var profileValidationErrors: [String] {
        var errors: [String] = []
        if config.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Host cannot be empty")
        }
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

        let hasNickServAccount = !config.nickServAccount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasNickServPassword = !config.nickServPassword.isEmpty
        if hasNickServAccount && !hasNickServPassword {
            warnings.append("NickServ Account is set but NickServ Password is empty")
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
        config.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        let hasNickServAccount = !config.nickServAccount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasNickServPassword = !config.nickServPassword.isEmpty
        return hasNickServAccount && !hasNickServPassword
    }

    var isSASLPlainConfigurationIncomplete: Bool {
        config.enableSASL && config.saslMechanism == .plain && config.saslPassword.isEmpty
    }

    func connect() {
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
        client.connect(config: config)
    }

    func disconnect() {
        client.disconnect()
        isConnected = false
        isOperator = false
        appendLog("[action] Disconnected", to: IRCWindowPane.serverID)
    }

    func selectWindow(_ windowID: String) {
        selectedWindowID = windowID
        clearUnread(for: windowID)
    }

    func canCloseWindow(_ windowID: String) -> Bool {
        guard let pane = windows.first(where: { $0.id == windowID }) else { return false }
        return pane.type == .privateMessage
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
        if let pane = windows.first(where: { $0.id == windowID }) {
            recordClosedPrivatePane(pane)
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

    private func send(command: String) {
        if let expanded = expandedAnopeAlias(command) {
            client.sendRaw(expanded)
            appendLog("> \(expanded)", to: activeWindow.id)
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
        appendLog("> PRIVMSG \(target) :\(command)", to: paneID(for: target))
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

        if let channel = parseOwnJoinChannel(line) {
            ensureChannelPane(channel)
            return
        }

        if let routed = parseIncomingPrivmsgTarget(line) {
            if routed.target.hasPrefix("#") {
                ensureChannelPane(routed.target)
            } else {
                ensurePrivatePane(routed.target)
            }
            appendLog(line, to: paneID(for: routed.target), markUnread: true)
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

    private func parseIncomingPrivmsgTarget(_ line: String) -> (target: String, sender: String)? {
        guard line.hasPrefix(":"), line.contains(" PRIVMSG ") else { return nil }

        let prefixEnd = line.firstIndex(of: " ") ?? line.endIndex
        let prefix = String(line[line.index(after: line.startIndex)..<prefixEnd])
        let sender = prefix.split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""

        guard let privmsgRange = line.range(of: " PRIVMSG ") else { return nil }
        let afterPrivmsg = line[privmsgRange.upperBound...]
        let target = afterPrivmsg.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        guard !target.isEmpty else { return nil }

        if target.caseInsensitiveCompare(config.nickname) == .orderedSame, !sender.isEmpty {
            return (target: sender, sender: sender)
        }
        return (target: target, sender: sender)
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
        case "/ms":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG MemoServ :HELP" }
            return "PRIVMSG MemoServ :\(tail)"
        case "/os":
            let tail = parts.dropFirst().joined(separator: " ")
            guard !tail.isEmpty else { return "PRIVMSG OperServ :HELP" }
            return "PRIVMSG OperServ :\(tail)"
        default:
            return nil
        }
    }
}
