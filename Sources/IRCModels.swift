import Foundation

enum SASLMechanism: String, CaseIterable, Identifiable, Codable {
    case plain = "PLAIN"
    case external = "EXTERNAL"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain:
            return "PLAIN"
        case .external:
            return "EXTERNAL"
        }
    }
}

enum IRCWindowType: String, CaseIterable, Identifiable, Codable {
    case server
    case channel
    case privateMessage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .server:
            return "Server"
        case .channel:
            return "Channel"
        case .privateMessage:
            return "Private"
        }
    }
}

struct IRCContextCommand: Identifiable {
    let id: String
    let title: String
    let command: String
    let windowTypes: Set<IRCWindowType>
    let requiresOperator: Bool
}

struct IRCServerConfig: Codable {
    var host: String = "irc.daysting.com"
    var port: UInt16 = 6697
    var nickname: String = "daystingUser"
    var alternateNicknamesCSV: String = ""
    var username: String = "daystingUser"
    var realName: String = "Daysting IRC User"
    var channel: String = "#general"
    var autoJoinChannelsCSV: String = ""
    var useTLS: Bool = true
    var enableSASL: Bool = true
    var saslMechanism: SASLMechanism = .plain
    var saslUsername: String = ""
    var saslPassword: String = ""
    var nickServAccount: String = ""
    var nickServPassword: String = ""
    var operName: String = ""
    var operPassword: String = ""
    var delayJoinUntilNickServIdentify: Bool = false
    var nickServIdentifyTimeoutSeconds: Int = 10
}

enum IRCCommandCatalog {
    static let commands: [IRCContextCommand] = [
        IRCContextCommand(
            id: "server-lusers",
            title: "LUSERS",
            command: "/LUSERS",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-motd",
            title: "MOTD",
            command: "/MOTD",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-time",
            title: "TIME",
            command: "/TIME",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-version",
            title: "VERSION",
            command: "/VERSION",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-info",
            title: "INFO",
            command: "/INFO",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-admin",
            title: "ADMIN",
            command: "/ADMIN",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-map",
            title: "MAP",
            command: "/MAP",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-links",
            title: "LINKS",
            command: "/LINKS",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-list",
            title: "LIST",
            command: "/LIST",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "server-whois-target",
            title: "WHOIS Current Target",
            command: "/WHOIS {target}",
            windowTypes: [.server, .privateMessage],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "channel-names",
            title: "NAMES",
            command: "/NAMES {channel}",
            windowTypes: [.channel],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "channel-topic",
            title: "TOPIC",
            command: "/TOPIC {channel}",
            windowTypes: [.channel],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "channel-mode",
            title: "MODE",
            command: "/MODE {channel}",
            windowTypes: [.channel],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "channel-who",
            title: "WHO",
            command: "/WHO {channel}",
            windowTypes: [.channel],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "channel-part",
            title: "PART",
            command: "/PART {channel}",
            windowTypes: [.channel],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "channel-cycle",
            title: "Cycle (PART/JOIN)",
            command: "/PART {channel} :Rejoining",
            windowTypes: [.channel],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "private-notice",
            title: "NOTICE Current Target",
            command: "/NOTICE {target} :Hello",
            windowTypes: [.privateMessage],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "private-query",
            title: "QUERY Current Target",
            command: "/QUERY {target}",
            windowTypes: [.privateMessage],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "private-away",
            title: "AWAY",
            command: "/AWAY",
            windowTypes: [.privateMessage, .server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "oper-oper",
            title: "OPER (Manual)",
            command: "/OPER <name> <password>",
            windowTypes: [.server],
            requiresOperator: false
        ),
        IRCContextCommand(
            id: "oper-wallops",
            title: "WALLOPS",
            command: "/WALLOPS :Operator notice",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-rehash",
            title: "REHASH",
            command: "/REHASH",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-restart",
            title: "RESTART",
            command: "/RESTART",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-die",
            title: "DIE",
            command: "/DIE",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-stats-u",
            title: "STATS u",
            command: "/STATS u",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-connect",
            title: "CONNECT (Manual)",
            command: "/CONNECT <server> <port>",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-squit",
            title: "SQUIT (Manual)",
            command: "/SQUIT <server> :reason",
            windowTypes: [.server],
            requiresOperator: true
        ),
        IRCContextCommand(
            id: "oper-kill",
            title: "KILL (Manual)",
            command: "/KILL <nick> :reason",
            windowTypes: [.server, .channel, .privateMessage],
            requiresOperator: true
        )
    ]
}

enum ServiceShortcut: String, CaseIterable, Identifiable {
    case memoSend
    case memoInbox
    case operHelp
    case operMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memoSend:
            return "MemoServ: Send"
        case .memoInbox:
            return "MemoServ: Inbox"
        case .operHelp:
            return "OperServ: Help"
        case .operMode:
            return "OperServ: MODE +o"
        }
    }

    var commandTemplate: String {
        switch self {
        case .memoSend:
            return "PRIVMSG MemoServ :SEND <nick> <message>"
        case .memoInbox:
            return "PRIVMSG MemoServ :LIST"
        case .operHelp:
            return "PRIVMSG OperServ :HELP"
        case .operMode:
            return "PRIVMSG OperServ :MODE #channel +o <nick>"
        }
    }
}
