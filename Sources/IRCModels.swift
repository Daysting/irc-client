import Foundation

struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let defaultText = RGBAColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
    static let defaultBackground = RGBAColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
}

enum AppearanceFontFamily: String, CaseIterable, Identifiable, Codable {
    case system
    case rounded
    case monospaced
    case serif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .rounded:
            return "Rounded"
        case .monospaced:
            return "Monospaced"
        case .serif:
            return "Serif"
        }
    }
}

struct AppearanceThemePreset: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var fontFamily: AppearanceFontFamily
    var fontSize: Double
    var textColor: RGBAColor
    var backgroundColor: RGBAColor
}

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

enum AnopeService: String, CaseIterable, Identifiable {
    case nickServ
    case chanServ
    case memoServ
    case operServ
    case hostServ
    case botServ

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nickServ:
            return "NickServ"
        case .chanServ:
            return "ChanServ"
        case .memoServ:
            return "MemoServ"
        case .operServ:
            return "OperServ"
        case .hostServ:
            return "HostServ"
        case .botServ:
            return "BotServ"
        }
    }
}

struct AnopeInputField: Identifiable {
    let id: String
    let label: String
    let placeholder: String
    let secure: Bool
    let isOptional: Bool

    init(id: String, label: String, placeholder: String, secure: Bool, isOptional: Bool = false) {
        self.id = id
        self.label = label
        self.placeholder = placeholder
        self.secure = secure
        self.isOptional = isOptional
    }
}

struct AnopeMenuAction: Identifiable {
    let id: String
    let service: AnopeService
    let title: String
    let commandTemplate: String
    let windowTypes: Set<IRCWindowType>
    let inputFields: [AnopeInputField]
}

enum AnopeCommandCatalog {
    static let actions: [AnopeMenuAction] = [
        AnopeMenuAction(id: "ns-help", service: .nickServ, title: "Help", commandTemplate: "/ns help", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ns-register", service: .nickServ, title: "Register", commandTemplate: "/ns register {password} {email}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true),
            AnopeInputField(id: "email", label: "Email", placeholder: "user@example.com", secure: false)
        ]),
        AnopeMenuAction(id: "ns-identify", service: .nickServ, title: "Identify", commandTemplate: "/ns identify {password}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true)
        ]),
        AnopeMenuAction(id: "ns-ghost", service: .nickServ, title: "Ghost", commandTemplate: "/ns ghost {nick} {password}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false),
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true)
        ]),
        AnopeMenuAction(id: "ns-recover", service: .nickServ, title: "Recover", commandTemplate: "/ns recover {nick} {password}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false),
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true)
        ]),
        AnopeMenuAction(id: "ns-release", service: .nickServ, title: "Release", commandTemplate: "/ns release {nick} {password}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false),
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true)
        ]),

        AnopeMenuAction(id: "cs-help", service: .chanServ, title: "Help", commandTemplate: "/cs help", windowTypes: [.server, .channel], inputFields: []),
        AnopeMenuAction(id: "cs-register", service: .chanServ, title: "Register", commandTemplate: "/cs register {channel} {description}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false),
            AnopeInputField(id: "description", label: "Description", placeholder: "Channel description", secure: false)
        ]),
        AnopeMenuAction(id: "cs-op", service: .chanServ, title: "Op", commandTemplate: "/cs op {channel} {nick}", windowTypes: [.channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-deop", service: .chanServ, title: "Deop", commandTemplate: "/cs deop {channel} {nick}", windowTypes: [.channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-voice", service: .chanServ, title: "Voice", commandTemplate: "/cs voice {channel} {nick}", windowTypes: [.channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-devoice", service: .chanServ, title: "Devoice", commandTemplate: "/cs devoice {channel} {nick}", windowTypes: [.channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),

        AnopeMenuAction(id: "ms-help", service: .memoServ, title: "Help", commandTemplate: "/ms help", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ms-send", service: .memoServ, title: "Send", commandTemplate: "/ms send {nick} {message}", windowTypes: [.server, .privateMessage], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false),
            AnopeInputField(id: "message", label: "Message", placeholder: "memo text", secure: false)
        ]),
        AnopeMenuAction(id: "ms-list", service: .memoServ, title: "List", commandTemplate: "/ms list", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ms-read", service: .memoServ, title: "Read", commandTemplate: "/ms read {number}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "number", label: "Memo Number", placeholder: "1", secure: false)
        ]),

        AnopeMenuAction(id: "os-help", service: .operServ, title: "Help", commandTemplate: "/os help", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-akill-add", service: .operServ, title: "AKILL Add", commandTemplate: "/os akill add {mask} {time} {reason}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "baduser@host", secure: false),
            AnopeInputField(id: "time", label: "Duration", placeholder: "+1d", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false)
        ]),
        AnopeMenuAction(id: "os-akill-del", service: .operServ, title: "AKILL Del", commandTemplate: "/os akill del {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "baduser@host", secure: false)
        ]),

        AnopeMenuAction(id: "hs-help", service: .hostServ, title: "Help", commandTemplate: "/hs help", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "hs-request", service: .hostServ, title: "Request", commandTemplate: "/hs request {vhost}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "vhost", label: "Requested Vhost", placeholder: "vhost.example.com", secure: false)
        ]),
        AnopeMenuAction(id: "hs-on", service: .hostServ, title: "On", commandTemplate: "/hs on", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "hs-off", service: .hostServ, title: "Off", commandTemplate: "/hs off", windowTypes: [.server, .channel, .privateMessage], inputFields: []),

        AnopeMenuAction(id: "bs-help", service: .botServ, title: "Help", commandTemplate: "/bs help", windowTypes: [.server, .channel], inputFields: []),
        AnopeMenuAction(id: "bs-assign", service: .botServ, title: "Assign", commandTemplate: "/bs assign {channel} {bot}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false),
            AnopeInputField(id: "bot", label: "Bot", placeholder: "BotNick", secure: false)
        ]),
        AnopeMenuAction(id: "bs-unassign", service: .botServ, title: "Unassign", commandTemplate: "/bs unassign {channel}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false)
        ])
    ]
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
    var enableCustomAppearance: Bool = false
    var appearanceFontFamily: AppearanceFontFamily = .system
    var appearanceFontSize: Double = 13
    var appearanceTextColor: RGBAColor = .defaultText
    var appearanceBackgroundColor: RGBAColor = .defaultBackground
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
