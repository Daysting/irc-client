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
    var fontName: String?
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

enum ChannelUserModeAction: String, CaseIterable, Identifiable {
    case op
    case deop
    case voice
    case devoice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .op:
            return "Op"
        case .deop:
            return "Deop"
        case .voice:
            return "Voice"
        case .devoice:
            return "Devoice"
        }
    }

    var modeChange: String {
        switch self {
        case .op:
            return "+o"
        case .deop:
            return "-o"
        case .voice:
            return "+v"
        case .devoice:
            return "-v"
        }
    }
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
        AnopeMenuAction(id: "ns-custom", service: .nickServ, title: "Custom NickServ Command", commandTemplate: "/ns {command}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "command", label: "Command", placeholder: "command args...", secure: false)
        ]),
        AnopeMenuAction(id: "ns-register", service: .nickServ, title: "Register", commandTemplate: "/ns register {password} {email}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true),
            AnopeInputField(id: "email", label: "Email", placeholder: "user@example.com", secure: false)
        ]),
        AnopeMenuAction(id: "ns-identify", service: .nickServ, title: "Identify", commandTemplate: "/ns identify {password}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true)
        ]),
        AnopeMenuAction(id: "ns-logout", service: .nickServ, title: "Logout", commandTemplate: "/ns logout", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ns-info", service: .nickServ, title: "Info", commandTemplate: "/ns info {nick}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "ns-list", service: .nickServ, title: "List", commandTemplate: "/ns list {pattern}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "pattern", label: "Pattern", placeholder: "nick*", secure: false)
        ]),
        AnopeMenuAction(id: "ns-status", service: .nickServ, title: "Status", commandTemplate: "/ns status {nick}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false)
        ]),
        AnopeMenuAction(id: "ns-alist", service: .nickServ, title: "AList", commandTemplate: "/ns alist", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ns-update", service: .nickServ, title: "Update", commandTemplate: "/ns update", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ns-group", service: .nickServ, title: "Group", commandTemplate: "/ns group {target} {password}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "target", label: "Target Nick", placeholder: "registeredNick", secure: false),
            AnopeInputField(id: "password", label: "Password", placeholder: "password", secure: true)
        ]),
        AnopeMenuAction(id: "ns-ungroup", service: .nickServ, title: "Ungroup", commandTemplate: "/ns ungroup", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ns-drop", service: .nickServ, title: "Drop", commandTemplate: "/ns drop {nick}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "ns-set-password", service: .nickServ, title: "Set Password", commandTemplate: "/ns set password {newpassword}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "newpassword", label: "New Password", placeholder: "new password", secure: true)
        ]),
        AnopeMenuAction(id: "ns-set-email", service: .nickServ, title: "Set Email", commandTemplate: "/ns set email {email}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "email", label: "Email", placeholder: "user@example.com", secure: false)
        ]),
        AnopeMenuAction(id: "ns-set-kill", service: .nickServ, title: "Set Kill", commandTemplate: "/ns set kill {value}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "value", label: "Kill Value", placeholder: "ON/OFF/QUICK/IMMED", secure: false)
        ]),
        AnopeMenuAction(id: "ns-set-protect", service: .nickServ, title: "Set Protect", commandTemplate: "/ns set protect {value}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "value", label: "Protect Value", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "ns-set-hide-email", service: .nickServ, title: "Set Hide Email", commandTemplate: "/ns set hide email {value}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "value", label: "Hide Email", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "ns-set-hide-usermask", service: .nickServ, title: "Set Hide Usermask", commandTemplate: "/ns set hide usermask {value}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "value", label: "Hide Usermask", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "ns-cert-add", service: .nickServ, title: "Cert Add", commandTemplate: "/ns cert add {fingerprint}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "fingerprint", label: "Fingerprint", placeholder: "SHA256 fingerprint", secure: false)
        ]),
        AnopeMenuAction(id: "ns-cert-del", service: .nickServ, title: "Cert Del", commandTemplate: "/ns cert del {fingerprint}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "fingerprint", label: "Fingerprint", placeholder: "SHA256 fingerprint", secure: false)
        ]),
        AnopeMenuAction(id: "ns-cert-list", service: .nickServ, title: "Cert List", commandTemplate: "/ns cert list", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
        AnopeMenuAction(id: "ns-access-add", service: .nickServ, title: "Access Add", commandTemplate: "/ns access add {mask}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "nick!user@host", secure: false)
        ]),
        AnopeMenuAction(id: "ns-access-del", service: .nickServ, title: "Access Del", commandTemplate: "/ns access del {mask}", windowTypes: [.server, .channel, .privateMessage], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "nick!user@host", secure: false)
        ]),
        AnopeMenuAction(id: "ns-access-list", service: .nickServ, title: "Access List", commandTemplate: "/ns access list", windowTypes: [.server, .channel, .privateMessage], inputFields: []),
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
        AnopeMenuAction(id: "cs-custom", service: .chanServ, title: "Custom ChanServ Command", commandTemplate: "/cs {command}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "command", label: "Command", placeholder: "command args...", secure: false)
        ]),
        AnopeMenuAction(id: "cs-register", service: .chanServ, title: "Register", commandTemplate: "/cs register {channel} {description}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false),
            AnopeInputField(id: "description", label: "Description", placeholder: "Channel description", secure: false)
        ]),
        AnopeMenuAction(id: "cs-identify", service: .chanServ, title: "Identify", commandTemplate: "/cs identify {channel} {password}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false),
            AnopeInputField(id: "password", label: "Password", placeholder: "channel password", secure: true)
        ]),
        AnopeMenuAction(id: "cs-info", service: .chanServ, title: "Info", commandTemplate: "/cs info {channel}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-list", service: .chanServ, title: "List", commandTemplate: "/cs list {pattern}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "pattern", label: "Pattern", placeholder: "#chan*", secure: false)
        ]),
        AnopeMenuAction(id: "cs-drop", service: .chanServ, title: "Drop", commandTemplate: "/cs drop {channel}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false)
        ]),
        AnopeMenuAction(id: "cs-topic", service: .chanServ, title: "Topic", commandTemplate: "/cs topic {channel} {topic}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "topic", label: "Topic", placeholder: "new topic", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-desc", service: .chanServ, title: "Set Description", commandTemplate: "/cs set {channel} desc {description}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "description", label: "Description", placeholder: "channel description", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-url", service: .chanServ, title: "Set URL", commandTemplate: "/cs set {channel} url {url}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "url", label: "URL", placeholder: "https://example.com", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-email", service: .chanServ, title: "Set Email", commandTemplate: "/cs set {channel} email {email}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "email", label: "Email", placeholder: "ops@example.com", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-mlock", service: .chanServ, title: "Set MLOCK", commandTemplate: "/cs set {channel} mlock {modes}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "modes", label: "Modes", placeholder: "+nt", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-private", service: .chanServ, title: "Set Private", commandTemplate: "/cs set {channel} private {value}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "value", label: "Private", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-secure", service: .chanServ, title: "Set Secure", commandTemplate: "/cs set {channel} secure {value}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "value", label: "Secure", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-keeptopic", service: .chanServ, title: "Set KeepTopic", commandTemplate: "/cs set {channel} keeptopic {value}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "value", label: "KeepTopic", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "cs-set-topiclock", service: .chanServ, title: "Set TopicLock", commandTemplate: "/cs set {channel} topiclock {value}", windowTypes: [.server, .channel], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "value", label: "TopicLock", placeholder: "ON/OFF", secure: false)
        ]),
        AnopeMenuAction(id: "cs-op", service: .chanServ, title: "Op", commandTemplate: "/cs op {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-deop", service: .chanServ, title: "Deop", commandTemplate: "/cs deop {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-voice", service: .chanServ, title: "Voice", commandTemplate: "/cs voice {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-devoice", service: .chanServ, title: "Devoice", commandTemplate: "/cs devoice {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-kick", service: .chanServ, title: "Kick", commandTemplate: "/cs kick {channel} {nick} {reason}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname", placeholder: "nickname", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-ban", service: .chanServ, title: "Ban", commandTemplate: "/cs ban {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname/Mask", placeholder: "nickname or *!*@host", secure: false)
        ]),
        AnopeMenuAction(id: "cs-unban", service: .chanServ, title: "Unban", commandTemplate: "/cs unban {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "nick", label: "Nickname/Mask", placeholder: "nickname or *!*@host", secure: false)
        ]),
        AnopeMenuAction(id: "cs-akick-add", service: .chanServ, title: "AKICK Add", commandTemplate: "/cs akick {channel} add {mask} {reason}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "mask", label: "Mask", placeholder: "nick!user@host", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-akick-del", service: .chanServ, title: "AKICK Del", commandTemplate: "/cs akick {channel} del {mask}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "mask", label: "Mask", placeholder: "nick!user@host", secure: false)
        ]),
        AnopeMenuAction(id: "cs-akick-list", service: .chanServ, title: "AKICK List", commandTemplate: "/cs akick {channel} list", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-flags", service: .chanServ, title: "Flags", commandTemplate: "/cs flags {channel} {target} {flags}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true),
            AnopeInputField(id: "target", label: "Target", placeholder: "nickname/account", secure: false),
            AnopeInputField(id: "flags", label: "Flags", placeholder: "+VOP -AUTOOP", secure: false)
        ]),
        AnopeMenuAction(id: "cs-clear-users", service: .chanServ, title: "Clear Users", commandTemplate: "/cs clear users {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-clear-bans", service: .chanServ, title: "Clear Bans", commandTemplate: "/cs clear bans {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-clear-modes", service: .chanServ, title: "Clear Modes", commandTemplate: "/cs clear modes {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-clear-ops", service: .chanServ, title: "Clear Ops", commandTemplate: "/cs clear ops {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-clear-voices", service: .chanServ, title: "Clear Voices", commandTemplate: "/cs clear voices {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-invite", service: .chanServ, title: "Invite", commandTemplate: "/cs invite {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-unban-self", service: .chanServ, title: "Unban Self", commandTemplate: "/cs unban {channel}", windowTypes: [.channel, .server], inputFields: [
            AnopeInputField(id: "channel", label: "Channel", placeholder: "#channel", secure: false, isOptional: true)
        ]),
        AnopeMenuAction(id: "cs-status", service: .chanServ, title: "Status", commandTemplate: "/cs status {channel} {nick}", windowTypes: [.channel, .server], inputFields: [
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
        AnopeMenuAction(id: "os-custom", service: .operServ, title: "Custom OperServ Command", commandTemplate: "/os {command}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "command", label: "Command", placeholder: "command args...", secure: false)
        ]),

        // Oper entitlement and services operator management.
        AnopeMenuAction(id: "os-opertype-list", service: .operServ, title: "OperType List (Entitlements)", commandTemplate: "/os opertype list", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-opertype-info", service: .operServ, title: "OperType Info", commandTemplate: "/os opertype info {opertype}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "opertype", label: "OperType", placeholder: "Services-Admin", secure: false)
        ]),
        AnopeMenuAction(id: "os-oper-add", service: .operServ, title: "Add Oper", commandTemplate: "/os oper add {nickname} {opertype}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "nickname", label: "Nickname/Account", placeholder: "NickOrAccount", secure: false),
            AnopeInputField(id: "opertype", label: "OperType (Entitlement)", placeholder: "Services-Admin", secure: false)
        ]),
        AnopeMenuAction(id: "os-oper-del", service: .operServ, title: "Del Oper", commandTemplate: "/os oper del {nickname}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "nickname", label: "Nickname/Account", placeholder: "NickOrAccount", secure: false)
        ]),
        AnopeMenuAction(id: "os-oper-list", service: .operServ, title: "Oper List", commandTemplate: "/os oper list", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-oper-info", service: .operServ, title: "Oper Info", commandTemplate: "/os oper info {nickname}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "nickname", label: "Nickname/Account", placeholder: "NickOrAccount", secure: false)
        ]),

        AnopeMenuAction(id: "os-akill-add", service: .operServ, title: "AKILL Add", commandTemplate: "/os akill add {mask} {time} {reason}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "baduser@host", secure: false),
            AnopeInputField(id: "time", label: "Duration", placeholder: "+1d", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false)
        ]),
        AnopeMenuAction(id: "os-akill-del", service: .operServ, title: "AKILL Del", commandTemplate: "/os akill del {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "baduser@host", secure: false)
        ]),
        AnopeMenuAction(id: "os-akill-list", service: .operServ, title: "AKILL List", commandTemplate: "/os akill list", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-akill-view", service: .operServ, title: "AKILL View", commandTemplate: "/os akill view {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "baduser@host", secure: false)
        ]),

        AnopeMenuAction(id: "os-ignore-add", service: .operServ, title: "Ignore Add", commandTemplate: "/os ignore add {mask} {time} {reason}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "nick!user@host", secure: false),
            AnopeInputField(id: "time", label: "Duration", placeholder: "+1h", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false)
        ]),
        AnopeMenuAction(id: "os-ignore-del", service: .operServ, title: "Ignore Del", commandTemplate: "/os ignore del {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "nick!user@host", secure: false)
        ]),
        AnopeMenuAction(id: "os-ignore-list", service: .operServ, title: "Ignore List", commandTemplate: "/os ignore list", windowTypes: [.server], inputFields: []),

        AnopeMenuAction(id: "os-sqline-add", service: .operServ, title: "SQLINE Add", commandTemplate: "/os sqline add {mask} {time} {reason}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "badnick*", secure: false),
            AnopeInputField(id: "time", label: "Duration", placeholder: "+1d", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false)
        ]),
        AnopeMenuAction(id: "os-sqline-del", service: .operServ, title: "SQLINE Del", commandTemplate: "/os sqline del {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "badnick*", secure: false)
        ]),
        AnopeMenuAction(id: "os-sqline-list", service: .operServ, title: "SQLINE List", commandTemplate: "/os sqline list", windowTypes: [.server], inputFields: []),

        AnopeMenuAction(id: "os-szline-add", service: .operServ, title: "SZLINE Add", commandTemplate: "/os szline add {mask} {time} {reason}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "*@bad.host", secure: false),
            AnopeInputField(id: "time", label: "Duration", placeholder: "+1d", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false)
        ]),
        AnopeMenuAction(id: "os-szline-del", service: .operServ, title: "SZLINE Del", commandTemplate: "/os szline del {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "*@bad.host", secure: false)
        ]),
        AnopeMenuAction(id: "os-szline-list", service: .operServ, title: "SZLINE List", commandTemplate: "/os szline list", windowTypes: [.server], inputFields: []),

        AnopeMenuAction(id: "os-sgline-add", service: .operServ, title: "SGLINE Add", commandTemplate: "/os sgline add {mask} {time} {reason}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "badgecos*", secure: false),
            AnopeInputField(id: "time", label: "Duration", placeholder: "+1d", secure: false),
            AnopeInputField(id: "reason", label: "Reason", placeholder: "reason", secure: false)
        ]),
        AnopeMenuAction(id: "os-sgline-del", service: .operServ, title: "SGLINE Del", commandTemplate: "/os sgline del {mask}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "mask", label: "Mask", placeholder: "badgecos*", secure: false)
        ]),
        AnopeMenuAction(id: "os-sgline-list", service: .operServ, title: "SGLINE List", commandTemplate: "/os sgline list", windowTypes: [.server], inputFields: []),

        AnopeMenuAction(id: "os-session-list", service: .operServ, title: "Session List", commandTemplate: "/os session list", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-session-view", service: .operServ, title: "Session View", commandTemplate: "/os session view {host}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "host", label: "Host", placeholder: "example.com", secure: false)
        ]),
        AnopeMenuAction(id: "os-session-reset", service: .operServ, title: "Session Reset", commandTemplate: "/os session reset {host}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "host", label: "Host", placeholder: "example.com", secure: false)
        ]),

        AnopeMenuAction(id: "os-update", service: .operServ, title: "Update", commandTemplate: "/os update", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-reload", service: .operServ, title: "Reload", commandTemplate: "/os reload", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-restart", service: .operServ, title: "Restart", commandTemplate: "/os restart", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-modlist", service: .operServ, title: "Module List", commandTemplate: "/os modlist", windowTypes: [.server], inputFields: []),
        AnopeMenuAction(id: "os-modinfo", service: .operServ, title: "Module Info", commandTemplate: "/os modinfo {module}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "module", label: "Module", placeholder: "os_session", secure: false)
        ]),
        AnopeMenuAction(id: "os-modload", service: .operServ, title: "Module Load", commandTemplate: "/os modload {module}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "module", label: "Module", placeholder: "module_name", secure: false)
        ]),
        AnopeMenuAction(id: "os-modreload", service: .operServ, title: "Module Reload", commandTemplate: "/os modreload {module}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "module", label: "Module", placeholder: "module_name", secure: false)
        ]),
        AnopeMenuAction(id: "os-modunload", service: .operServ, title: "Module Unload", commandTemplate: "/os modunload {module}", windowTypes: [.server], inputFields: [
            AnopeInputField(id: "module", label: "Module", placeholder: "module_name", secure: false)
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
    var appearanceFontName: String? = nil
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
            title: "Refresh Topic",
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
