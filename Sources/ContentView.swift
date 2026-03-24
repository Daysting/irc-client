import SwiftUI
import AppKit

private extension View {
    func validationBorder(color: Color?) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color ?? .clear, lineWidth: color == nil ? 0 : 1)
        )
    }
}

private struct ValidationHintIcon: View {
    let color: Color
    let tooltip: String

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(color)
            .help(tooltip)
            .accessibilityLabel("Validation hint")
    }
}

private struct MiddleClickCaptureView: NSViewRepresentable {
    let onMiddleClick: () -> Void

    final class Coordinator: NSObject {
        let onMiddleClick: () -> Void

        init(onMiddleClick: @escaping () -> Void) {
            self.onMiddleClick = onMiddleClick
        }

        @objc
        func handleMiddleClick(_: NSClickGestureRecognizer) {
            onMiddleClick()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMiddleClick: onMiddleClick)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        let recognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMiddleClick(_:)))
        recognizer.buttonMask = 0x4
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}

struct ContentView: View {
    @EnvironmentObject private var vm: IRCViewModel

    var body: some View {
        VStack(spacing: 12) {
            serverConfigPanel
            paneTabsPanel
            serviceShortcuts
            logPanel
            inputPanel
        }
        .padding(16)
    }

    private var serverConfigPanel: some View {
        GroupBox("Connection") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Host", text: $vm.config.host)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isHostInvalid ? .red : nil)
                    if vm.isHostInvalid {
                        ValidationHintIcon(
                            color: .red,
                            tooltip: "Host is required. Enter a server hostname, for example irc.daysting.com."
                        )
                    }
                    TextField("Port", value: $vm.config.port, formatter: NumberFormatter())
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                    Toggle("TLS", isOn: $vm.config.useTLS)
                        .toggleStyle(.switch)
                        .frame(width: 90)
                    TextField("Nick", text: $vm.config.nickname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Channel", text: $vm.config.channel)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isPrimaryChannelInvalid ? .red : nil)
                    if vm.isPrimaryChannelInvalid {
                        ValidationHintIcon(
                            color: .red,
                            tooltip: "Primary channel must start with #, for example #lobby."
                        )
                    }
                    Button(vm.isConnected ? "Disconnect" : "Connect") {
                        vm.isConnected ? vm.disconnect() : vm.connect()
                    }
                    .keyboardShortcut("k", modifiers: [.command])
                    .disabled(!vm.isConnected && !vm.canConnectWithCurrentProfile)
                }

                HStack(spacing: 10) {
                    TextField("Alt Nicks (comma-separated)", text: $vm.config.alternateNicknamesCSV)
                        .textFieldStyle(.roundedBorder)
                    TextField("Auto Join Channels (comma-separated #channels)", text: $vm.config.autoJoinChannelsCSV)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.hasInvalidAutoJoinEntries ? .orange : nil)
                    if vm.hasInvalidAutoJoinEntries {
                        ValidationHintIcon(
                            color: .orange,
                            tooltip: "Only #channels are accepted. Separate entries with commas, for example #chat,#help."
                        )
                    }
                }

                HStack(spacing: 10) {
                    Toggle("SASL", isOn: $vm.config.enableSASL)
                        .toggleStyle(.switch)
                        .frame(width: 90)
                    Picker("Mechanism", selection: $vm.config.saslMechanism) {
                        ForEach(SASLMechanism.allCases) { mechanism in
                            Text(mechanism.title).tag(mechanism)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    TextField("SASL User (optional)", text: $vm.config.saslUsername)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!vm.config.enableSASL || vm.config.saslMechanism == .external)
                    SecureField("SASL Password", text: $vm.config.saslPassword)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!vm.config.enableSASL || vm.config.saslMechanism == .external)
                        .validationBorder(color: vm.isSASLPlainConfigurationIncomplete ? .orange : nil)
                    if vm.isSASLPlainConfigurationIncomplete {
                        ValidationHintIcon(
                            color: .orange,
                            tooltip: "SASL PLAIN needs a password. Enter SASL Password or switch mechanism to EXTERNAL."
                        )
                    }
                    TextField("NickServ Account", text: $vm.config.nickServAccount)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isNickServConfigurationIncomplete ? .orange : nil)
                    SecureField("NickServ Password (fallback)", text: $vm.config.nickServPassword)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isNickServConfigurationIncomplete ? .orange : nil)
                    if vm.isNickServConfigurationIncomplete {
                        ValidationHintIcon(
                            color: .orange,
                            tooltip: "NickServ Account is set but password is missing. Add NickServ Password for IDENTIFY fallback."
                        )
                    }
                }

                HStack(spacing: 10) {
                    TextField("OPER Name", text: $vm.config.operName)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isOperConfigurationIncomplete ? .orange : nil)
                    SecureField("OPER Password", text: $vm.config.operPassword)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isOperConfigurationIncomplete ? .orange : nil)
                    if vm.isOperConfigurationIncomplete {
                        ValidationHintIcon(
                            color: .orange,
                            tooltip: "OPER automation requires both fields. Fill OPER Name and OPER Password, or clear both."
                        )
                    }
                }

                HStack(spacing: 10) {
                    Toggle("Delay Join", isOn: $vm.config.delayJoinUntilNickServIdentify)
                        .toggleStyle(.switch)
                        .frame(width: 120)
                        .disabled(vm.config.nickServPassword.isEmpty)
                    Stepper("NickServ Timeout: \(vm.config.nickServIdentifyTimeoutSeconds)s", value: $vm.config.nickServIdentifyTimeoutSeconds, in: 3...30)
                        .frame(maxWidth: 320, alignment: .leading)
                        .disabled(vm.config.nickServPassword.isEmpty || !vm.config.delayJoinUntilNickServIdentify)
                    Spacer()
                }

                if !vm.profileValidationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.profileValidationErrors, id: \.self) { item in
                            Text("Error: \(item)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !vm.profileValidationWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.profileValidationWarnings, id: \.self) { item in
                            Text("Warning: \(item)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var serviceShortcuts: some View {
        GroupBox("Anope Shortcuts") {
            HStack {
                ForEach(ServiceShortcut.allCases) { shortcut in
                    Button(shortcut.title) {
                        vm.send(shortcut: shortcut)
                    }
                }
            }
        }
    }

    private var paneTabsPanel: some View {
        GroupBox("Windows") {
            HStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(vm.windows) { pane in
                            HStack(spacing: 6) {
                                Button {
                                    vm.selectWindow(pane.id)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(pane.title)
                                        if pane.unreadCount > 0 {
                                            Text("\(pane.unreadCount)")
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.2))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(vm.selectedWindowID == pane.id ? .accentColor : .gray)
                                .background(
                                    MiddleClickCaptureView {
                                        if vm.canCloseWindow(pane.id) {
                                            vm.closeWindow(pane.id)
                                        }
                                    }
                                )

                                if vm.canCloseWindow(pane.id) {
                                    Button {
                                        vm.closeWindow(pane.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Menu("Context Commands") {
                    ForEach(vm.contextualCommands) { command in
                        Button(command.title) {
                            vm.executeContextCommand(command)
                        }
                        .disabled(command.requiresOperator && !vm.isOperator)
                    }

                    Divider()

                    Button("Close All Private Tabs") {
                        vm.closeAllPrivateWindows()
                    }

                    Button("Close Other Private Tabs") {
                        vm.closeOtherPrivateWindows(keeping: vm.selectedWindowID)
                    }

                    Button("Reopen Last Closed Private Tab") {
                        vm.reopenLastClosedPrivateWindow()
                    }
                    .disabled(!vm.canReopenLastPrivateWindow)

                    Menu("Recently Closed Private Tabs") {
                        if vm.recentClosedPrivateWindows.isEmpty {
                            Text("No recently closed private tabs")
                        } else {
                            ForEach(vm.recentClosedPrivateWindows) { pane in
                                Button(pane.title) {
                                    vm.reopenClosedPrivateWindow(windowID: pane.id)
                                }
                            }
                        }
                    }
                }

                Text(vm.isOperator ? "Operator: yes" : "Operator: no")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(vm.isOperator ? .green : .secondary)
            }
        }
    }

    private var logPanel: some View {
        GroupBox("\(vm.activeWindowTitle) Log") {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(vm.activeLogs.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .id(idx)
                    }
                }
                .onChange(of: vm.activeLogs.count) { _ in
                    guard !vm.activeLogs.isEmpty else { return }
                    proxy.scrollTo(vm.activeLogs.count - 1, anchor: .bottom)
                }
                .contextMenu {
                    ForEach(vm.contextualCommands) { command in
                        Button(command.title) {
                            vm.executeContextCommand(command)
                        }
                        .disabled(command.requiresOperator && !vm.isOperator)
                    }
                }
            }
        }
    }

    private var inputPanel: some View {
        HStack(spacing: 10) {
            TextField("Message \(vm.activeWindowTitle) or use command (/ms HELP, /os HELP, /join #chan)", text: $vm.input)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    vm.sendCurrentInput()
                }

            Button("Send") {
                vm.sendCurrentInput()
            }
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .contextMenu {
            ForEach(vm.contextualCommands) { command in
                Button(command.title) {
                    vm.executeContextCommand(command)
                }
                .disabled(command.requiresOperator && !vm.isOperator)
            }
        }
    }
}
