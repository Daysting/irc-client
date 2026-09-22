#if os(macOS)
import SwiftUI

/// A separate window sharing the same connection profile and session as the chat.
struct ConnectionView: View {
    @EnvironmentObject private var vm: IRCViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var host = ""
    @State private var port = "6697"

    private var validPort: UInt16? {
        guard let value = UInt16(port.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { return nil }
        return value
    }
    private var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canConnect: Bool {
        vm.canConnectWithCurrentProfile && !vm.isConnected && !vm.isConnecting
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Server") {
                    HStack {
                        Menu("Presets") {
                            ForEach(vm.serverPresets) { endpoint in
                                Button(endpoint.displayName) { select(endpoint) }
                            }
                        }
                        Menu("Favorites") {
                            if vm.favoriteCustomServers.isEmpty { Text("No favorite servers") }
                            ForEach(vm.favoriteCustomServers) { endpoint in
                                Button(endpoint.displayName) { select(endpoint) }
                            }
                        }
                        Menu("Recent") {
                            if vm.recentCustomServers.isEmpty { Text("No recent servers") }
                            ForEach(vm.recentCustomServers) { endpoint in
                                Button(endpoint.displayName) { select(endpoint) }
                            }
                        }
                    }
                    TextField("Server address", text: $host)
                    TextField("Port", text: $port)
                    if validPort == nil {
                        Text("Enter a port between 1 and 65535.").foregroundStyle(.red)
                    }
                    Button(isFavorite ? "Remove Favorite" : "Save as Favorite") {
                        guard let port = validPort else { return }
                        if isFavorite {
                            vm.removeFavoriteCustomServer(host: trimmedHost, port: port, useTLS: true)
                        } else {
                            vm.saveFavoriteCustomServer(host: trimmedHost, port: port, useTLS: true)
                        }
                    }
                    .disabled(trimmedHost.isEmpty || validPort == nil)
                    Text("Connections use TLS.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Identity & Channels") {
                    TextField("Nickname", text: $vm.config.nickname)
                    TextField("Alternate nicknames", text: $vm.config.alternateNicknamesCSV)
                    TextField("Channel", text: $vm.config.channel)
                    TextField("Auto join channels", text: $vm.config.autoJoinChannelsCSV)
                    Text("Separate additional nicknames and #channels with commas.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Authentication") {
                    Toggle("SASL", isOn: $vm.config.enableSASL)
                    Picker("Mechanism", selection: $vm.config.saslMechanism) {
                        ForEach(SASLMechanism.allCases) { mechanism in
                            Text(mechanism.title).tag(mechanism)
                        }
                    }.disabled(!vm.config.enableSASL)
                    TextField("SASL user (optional)", text: $vm.config.saslUsername)
                        .disabled(!vm.config.enableSASL || vm.config.saslMechanism == .external)
                    SecureField("SASL password", text: $vm.config.saslPassword)
                        .disabled(!vm.config.enableSASL || vm.config.saslMechanism == .external)
                    SecureField("NickServ password", text: $vm.config.nickServPassword)
                    Toggle("Delay joining until NickServ identifies", isOn: $vm.config.delayJoinUntilNickServIdentify)
                        .disabled(vm.config.nickServPassword.isEmpty)
                    Stepper("NickServ timeout: \(vm.config.nickServIdentifyTimeoutSeconds)s",
                            value: $vm.config.nickServIdentifyTimeoutSeconds, in: 3...30)
                        .disabled(vm.config.nickServPassword.isEmpty || !vm.config.delayJoinUntilNickServIdentify)
                    TextField("OPER name", text: $vm.config.operName)
                    SecureField("OPER password", text: $vm.config.operPassword)
                }
                if !vm.profileValidationErrors.isEmpty || !vm.profileValidationWarnings.isEmpty {
                    Section("Profile validation") {
                        ForEach(vm.profileValidationErrors, id: \.self) { Text($0).foregroundStyle(.red) }
                        ForEach(vm.profileValidationWarnings, id: \.self) { Text($0).foregroundStyle(.orange) }
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(vm.isConnected || vm.isConnecting)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                if !vm.connectionStatus.isEmpty {
                    Text(vm.connectionStatus).font(.callout).textSelection(.enabled)
                }
                HStack {
                    Button("Theme Controls…") { openWindow(id: "theme-controls") }
                    Spacer()
                    if vm.isConnecting {
                        ProgressView().controlSize(.small)
                        Button("Cancel") { vm.disconnect() }
                    } else if vm.isConnected {
                        Button("Show Chat") { openWindow(id: "chat"); dismiss() }
                    } else {
                        Button("Daysting Server") { vm.connectToDaysting() }
                            .disabled(!canConnect)
                        Button("Connect") {
                            guard let port = validPort else { return }
                            vm.connectToServer(host: trimmedHost, port: port, useTLS: true)
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canConnect || trimmedHost.isEmpty || validPort == nil)
                    }
                }
            }.padding(16)
        }
        .onAppear { host = vm.config.host; port = String(vm.config.port) }
        .onChange(of: vm.isConnected) { connected in
            if connected { openWindow(id: "chat"); dismiss() }
        }
    }

    private var isFavorite: Bool {
        guard let port = validPort else { return false }
        return vm.isFavoriteCustomServer(host: trimmedHost, port: port, useTLS: true)
    }
    private func select(_ endpoint: IRCServerEndpoint) {
        host = endpoint.host
        port = String(endpoint.port)
    }
}
#endif
