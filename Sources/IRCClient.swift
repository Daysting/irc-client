import Foundation
import Network

final class IRCClient {
    var onMessage: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    var onOperatorStatusChanged: ((Bool) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "DaystingIRC.Connection")
    private var isConnected = false
    private var activeConfig: IRCServerConfig?

    private var awaitingCAP = false
    private var isSASLRequested = false
    private var isSASLComplete = false
    private var saslAuthenticateSent = false
    private var hasCompletedRegistration = false
    private var didJoinChannel = false
    private var awaitingNickServIdentify = false
    private var nickServTimeoutWorkItem: DispatchWorkItem?
    private var isOperator = false
    private var candidateNicks: [String] = []
    private var candidateNickIndex = 0

    func connect(config: IRCServerConfig) {
        disconnect()
        activeConfig = config

        awaitingCAP = false
        isSASLRequested = false
        isSASLComplete = false
        saslAuthenticateSent = false
        hasCompletedRegistration = false
        didJoinChannel = false
        awaitingNickServIdentify = false
        nickServTimeoutWorkItem = nil
        candidateNicks = []
        candidateNickIndex = 0
        setOperatorStatus(false)

        let endpoint = NWEndpoint.Host(config.host)
        guard let nwPort = NWEndpoint.Port(rawValue: config.port) else {
            onStatus?("Invalid port: \(config.port)")
            return
        }

        let parameters = makeParameters(useTLS: config.useTLS)
        let connection = NWConnection(host: endpoint, port: nwPort, using: parameters)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isConnected = true
                self.onStatus?("Connected to \(config.host):\(config.port) TLS=\(config.useTLS)")
                self.startReceiveLoop()
                self.registerSession(config: config)
            case .failed(let error):
                self.isConnected = false
                self.onStatus?("Connection failed: \(error.localizedDescription)")
            case .waiting(let error):
                self.onStatus?("Waiting: \(error.localizedDescription)")
            case .cancelled:
                self.isConnected = false
                self.onStatus?("Connection closed")
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        activeConfig = nil
        awaitingCAP = false
        isSASLRequested = false
        isSASLComplete = false
        saslAuthenticateSent = false
        hasCompletedRegistration = false
        didJoinChannel = false
        awaitingNickServIdentify = false
        nickServTimeoutWorkItem?.cancel()
        nickServTimeoutWorkItem = nil
        candidateNicks = []
        candidateNickIndex = 0
        setOperatorStatus(false)
    }

    func sendRaw(_ line: String) {
        guard isConnected, let connection else { return }
        let data = Data((line + "\r\n").utf8)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.onStatus?("Send error: \(error.localizedDescription)")
            }
        })
    }

    func sendMessage(channel: String, message: String) {
        sendRaw("PRIVMSG \(channel) :\(message)")
    }

    private func makeParameters(useTLS: Bool) -> NWParameters {
        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
            return NWParameters(tls: tlsOptions)
        }
        return NWParameters.tcp
    }

    private func registerSession(config: IRCServerConfig) {
        let shouldUseSASL = shouldUseSASL(config)
        candidateNicks = parseNickCandidates(from: config)
        candidateNickIndex = 0

        if shouldUseSASL {
            awaitingCAP = true
            onStatus?("Requesting IRCv3 CAP LS for SASL")
            sendRaw("CAP LS 302")
        }

        sendRaw("NICK \(candidateNicks.first ?? config.nickname)")
        sendRaw("USER \(config.username) 0 * :\(config.realName)")
        // Registration-dependent actions are triggered after welcome (001),
        // or after SASL success when CAP is in use.
    }

    private func shouldUseSASL(_ config: IRCServerConfig) -> Bool {
        guard config.enableSASL else { return false }
        switch config.saslMechanism {
        case .plain:
            return !config.saslPassword.isEmpty
        case .external:
            return true
        }
    }

    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            if let content, !content.isEmpty, let text = String(data: content, encoding: .utf8) {
                self.handleIncoming(text)
            }

            if isComplete {
                self.isConnected = false
                self.onStatus?("Server closed the connection")
                return
            }

            if let error {
                self.isConnected = false
                self.onStatus?("Receive error: \(error.localizedDescription)")
                return
            }

            self.startReceiveLoop()
        }
    }

    private func handleIncoming(_ raw: String) {
        let lines = raw.replacingOccurrences(of: "\r", with: "").split(separator: "\n", omittingEmptySubsequences: false)
        for lineSlice in lines {
            let line = String(lineSlice)
            if line.hasPrefix("PING ") {
                let payload = line.replacingOccurrences(of: "PING", with: "PONG")
                sendRaw(payload)
            }
            handleProtocolLine(line)
            onMessage?(line)
        }
    }

    private func handleProtocolLine(_ line: String) {
        guard !line.isEmpty else { return }

        let tokens = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !tokens.isEmpty else { return }

        let commandIndex = tokens.first?.hasPrefix(":") == true ? 1 : 0
        guard tokens.indices.contains(commandIndex) else { return }
        let command = tokens[commandIndex]

        switch command {
        case "CAP":
            handleCAP(tokens: tokens, fullLine: line)
        case "AUTHENTICATE":
            handleAuthenticate(tokens: tokens)
        case "381":
            setOperatorStatus(true)
            onStatus?("Operator status granted")
        case "491":
            setOperatorStatus(false)
            onStatus?("Operator login denied")
        case "221":
            if let modes = tokens.last {
                setOperatorStatus(modes.contains("o"))
            }
        case "MODE":
            handleModeChange(tokens: tokens)
        case "433":
            handleNicknameInUse()
        case "900", "903":
            if awaitingCAP {
                onStatus?("SASL authentication succeeded")
                isSASLComplete = true
                sendRaw("CAP END")
                awaitingCAP = false
                completeRegistrationPostAuth()
            }
        case "904", "905", "906", "907":
            if awaitingCAP {
                onStatus?("SASL authentication failed; continuing without SASL")
                sendRaw("CAP END")
                awaitingCAP = false
                completeRegistrationPostAuth()
            }
        case "001":
            if !awaitingCAP {
                completeRegistrationPostAuth()
            }
        default:
            if awaitingNickServIdentify {
                let lowered = line.lowercased()
                if isNickServIdentifySuccess(line: lowered) {
                    awaitingNickServIdentify = false
                    nickServTimeoutWorkItem?.cancel()
                    nickServTimeoutWorkItem = nil
                    joinConfiguredChannels(reason: "NickServ identify succeeded")
                } else if isNickServIdentifyFailure(line: lowered) {
                    awaitingNickServIdentify = false
                    nickServTimeoutWorkItem?.cancel()
                    nickServTimeoutWorkItem = nil
                    onStatus?("NickServ identify failed; joining anyway")
                    joinConfiguredChannels(reason: "NickServ identify failed")
                }
            }
        }
    }

    private func handleModeChange(tokens: [String]) {
        guard let config = activeConfig else { return }
        guard tokens.count >= 4 else { return }

        let target = tokens[2].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard target.caseInsensitiveCompare(config.nickname) == .orderedSame else { return }

        let modeString = tokens[3].trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
        if modeString.contains("+o") {
            setOperatorStatus(true)
        } else if modeString.contains("-o") {
            setOperatorStatus(false)
        }
    }

    private func setOperatorStatus(_ newValue: Bool) {
        guard isOperator != newValue else { return }
        isOperator = newValue
        onOperatorStatusChanged?(newValue)
    }

    private func handleCAP(tokens: [String], fullLine: String) {
        guard tokens.count >= 4 else { return }
        let subcommand = tokens[2].uppercased()

        if subcommand == "LS" {
            let capList = fullLine.lowercased()
            if capList.contains("sasl") && !isSASLRequested {
                isSASLRequested = true
                onStatus?("Server supports SASL, requesting capability")
                sendRaw("CAP REQ :sasl")
            } else {
                onStatus?("Server CAP LS did not advertise SASL")
                sendRaw("CAP END")
                awaitingCAP = false
                completeRegistrationPostAuth()
            }
            return
        }

        if subcommand == "ACK" {
            let ackLine = fullLine.lowercased()
            if ackLine.contains("sasl") {
                onStatus?("SASL capability acknowledged")
                if let mechanism = activeConfig?.saslMechanism.rawValue {
                    sendRaw("AUTHENTICATE \(mechanism)")
                }
            }
            return
        }

        if subcommand == "NAK" {
            onStatus?("Server rejected SASL capability; continuing without SASL")
            sendRaw("CAP END")
            awaitingCAP = false
            completeRegistrationPostAuth()
        }
    }

    private func handleAuthenticate(tokens: [String]) {
        guard awaitingCAP, tokens.count >= 2 else { return }
        guard tokens[1] == "+" else { return }
        guard let config = activeConfig else { return }

        guard !saslAuthenticateSent else { return }
        saslAuthenticateSent = true

        if config.saslMechanism == .external {
            sendRaw("AUTHENTICATE +")
            return
        }

        let authcid = config.saslUsername.isEmpty ? config.username : config.saslUsername
        let payload = "\(authcid)\u{0}\(authcid)\u{0}\(config.saslPassword)"
        let encoded = Data(payload.utf8).base64EncodedString()
        sendRaw("AUTHENTICATE \(encoded)")
    }

    private func completeRegistrationPostAuth() {
        guard !hasCompletedRegistration, let config = activeConfig else { return }
        hasCompletedRegistration = true

        if !config.nickServPassword.isEmpty {
            onStatus?("Sending /NS IDENTIFY with password")
            sendRaw("PRIVMSG NickServ :IDENTIFY \(config.nickServPassword)")
        }

        if !config.operName.isEmpty && !config.operPassword.isEmpty {
            onStatus?("Sending /OPER login")
            sendRaw("OPER \(config.operName) \(config.operPassword)")
        }

        let shouldDelayJoin = config.delayJoinUntilNickServIdentify && !config.nickServPassword.isEmpty
        if shouldDelayJoin {
            awaitingNickServIdentify = true
            scheduleNickServFallbackJoin(timeoutSeconds: max(3, config.nickServIdentifyTimeoutSeconds))
            onStatus?("Waiting for NickServ identify before joining channels")
            return
        }

        joinConfiguredChannels(reason: "Standard post-auth join")
    }

    private func joinConfiguredChannels(reason: String) {
        guard !didJoinChannel, let config = activeConfig else { return }
        didJoinChannel = true
        let channels = parseAutoJoinChannels(from: config)
        for channel in channels {
            sendRaw("JOIN \(channel)")
        }

        let summary = channels.joined(separator: ", ")

        if isSASLComplete {
            onStatus?("Joined \(summary) with SASL session (\(reason))")
        } else {
            onStatus?("Joined \(summary) without SASL (\(reason))")
        }
    }

    private func scheduleNickServFallbackJoin(timeoutSeconds: Int) {
        nickServTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.awaitingNickServIdentify {
                self.awaitingNickServIdentify = false
                self.onStatus?("NickServ identify wait timed out after \(timeoutSeconds)s")
                self.joinConfiguredChannels(reason: "NickServ timeout fallback")
            }
        }
        nickServTimeoutWorkItem = workItem
        queue.asyncAfter(deadline: .now() + .seconds(timeoutSeconds), execute: workItem)
    }

    private func parseNickCandidates(from config: IRCServerConfig) -> [String] {
        let extras = config.alternateNicknamesCSV
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var list = [config.nickname]
        for nick in extras where !list.contains(where: { $0.caseInsensitiveCompare(nick) == .orderedSame }) {
            list.append(nick)
        }
        return list
    }

    private func handleNicknameInUse() {
        guard candidateNickIndex + 1 < candidateNicks.count else {
            onStatus?("Nickname is in use and no alternate nicknames are available")
            return
        }

        candidateNickIndex += 1
        let nextNick = candidateNicks[candidateNickIndex]
        onStatus?("Nickname in use. Trying alternate nickname: \(nextNick)")
        sendRaw("NICK \(nextNick)")
    }

    private func parseAutoJoinChannels(from config: IRCServerConfig) -> [String] {
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

    private func isNickServIdentifySuccess(line: String) -> Bool {
        guard line.contains("nickserv") else { return false }
        return line.contains("you are now identified")
            || line.contains("you are now recognized")
            || line.contains("password accepted")
            || line.contains("identified for")
    }

    private func isNickServIdentifyFailure(line: String) -> Bool {
        guard line.contains("nickserv") else { return false }
        return line.contains("password incorrect")
            || line.contains("invalid password")
            || line.contains("authentication failed")
            || line.contains("identify failed")
    }
}
