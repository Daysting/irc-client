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
    let example: String

    @State private var showPopover = false
    @State private var didCopyExample = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel("Validation hint")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tooltip)
                Text("Fix example")
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text(example)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button {
                        copyExampleToClipboard()
                    } label: {
                        Label(didCopyExample ? "Copied" : "Copy", systemImage: didCopyExample ? "checkmark.circle.fill" : "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(minWidth: 260, maxWidth: 340, alignment: .leading)
            .padding(12)
        }
    }

    private func copyExampleToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(example, forType: .string)
        didCopyExample = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyExample = false
        }
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
    private enum FocusField: Hashable {
        case messageInput
    }

    @EnvironmentObject private var vm: IRCViewModel
    @State private var selectedUserNick: String?
    @State private var activeAnopeAction: AnopeMenuAction?
    @State private var anopeInputValues: [String: String] = [:]
    @State private var anopeAdvancedMode = false
    @FocusState private var focusedField: FocusField?

    private var useCustomAppearance: Bool {
        vm.config.enableCustomAppearance
    }

    private var effectiveBackgroundColor: Color {
        useCustomAppearance ? color(from: vm.config.appearanceBackgroundColor) : Color(nsColor: .windowBackgroundColor)
    }

    private var effectiveBaseFont: Font {
        let size = CGFloat(max(10, min(24, vm.config.appearanceFontSize)))
        return themedFont(size: size)
    }

    var body: some View {
        ZStack {
            effectiveBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if vm.isConnected {
                    connectedTopBar
                } else {
                    serverConfigPanel
                }
                paneTabsPanel
                chatContentPanel
                inputPanel
            }
            .padding(16)
        }
        .font(effectiveBaseFont)
        .sheet(item: $activeAnopeAction) { action in
            anopePromptSheet(for: action)
        }
        .onAppear {
            focusMessageFieldSoon()
        }
        .onChange(of: vm.selectedWindowID) { _ in
            focusMessageFieldSoon()
        }
        .onChange(of: vm.isConnected) { _ in
            focusMessageFieldSoon()
        }
    }

    private var serverConfigPanel: some View {
        GroupBox("Connection") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Server: \(IRCViewModel.lockedHost):\(IRCViewModel.lockedPort) (TLS)")
                        .font(themedFont(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 320, alignment: .leading)

                    TextField("Nick", text: $vm.config.nickname)
                        .textFieldStyle(.roundedBorder)
                    TextField("Channel", text: $vm.config.channel)
                        .textFieldStyle(.roundedBorder)
                        .validationBorder(color: vm.isPrimaryChannelInvalid ? .red : nil)
                    if vm.isPrimaryChannelInvalid {
                        ValidationHintIcon(
                            color: .red,
                            tooltip: "Primary channel must start with #, for example #lobby.",
                            example: "#lobby"
                        )
                    }
                    Button("Connect") {
                        vm.connect()
                    }
                    .keyboardShortcut("k", modifiers: [.command])
                    .disabled(!vm.canConnectWithCurrentProfile)
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
                            tooltip: "Only #channels are accepted. Separate entries with commas, for example #chat,#help.",
                            example: "#chat,#help,#ops"
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
                            tooltip: "SASL PLAIN needs a password. Enter SASL Password or switch mechanism to EXTERNAL.",
                            example: "SASL=ON, Mechanism=PLAIN, Password=<your account password>"
                        )
                    }
                    SecureField("NickServ Password (/NS IDENTIFY)", text: $vm.config.nickServPassword)
                        .textFieldStyle(.roundedBorder)
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
                            tooltip: "OPER automation requires both fields. Fill OPER Name and OPER Password, or clear both.",
                            example: "OPER Name=netadmin, OPER Password=********"
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

                HStack(spacing: 10) {
                    Text("Theme controls are available from the menu bar: Theme > Theme Controls")
                        .font(themedFont(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if !vm.themeStatusMessage.isEmpty {
                    Text(vm.themeStatusMessage)
                        .font(themedFont(size: 12))
                        .foregroundStyle(vm.themeStatusIsError ? .red : .green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !vm.profileValidationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.profileValidationErrors, id: \.self) { item in
                            Text("Error: \(item)")
                                .font(themedFont(size: 12))
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !vm.profileValidationWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(vm.profileValidationWarnings, id: \.self) { item in
                            Text("Warning: \(item)")
                                .font(themedFont(size: 12))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var connectedTopBar: some View {
        HStack {
            Spacer()
            Button("Disconnect") {
                vm.disconnect()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("k", modifiers: [.command])
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
                                                .font(themedFont(size: 11, weight: .semibold))
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

                    if !anopeActionsForActiveWindow.isEmpty {
                        Divider()
                        anopeServicesMenu
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
                    .font(themedFont(size: 12))
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
                            .font(windowLogFont(for: vm.activeWindow.type, size: max(11, CGFloat(vm.config.appearanceFontSize))))
                            .foregroundStyle(useCustomAppearance ? color(from: vm.config.appearanceTextColor) : .primary)
                            .textSelection(.enabled)
                            .id(idx)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(
                    useCustomAppearance
                        ? color(from: vm.config.appearanceBackgroundColor).opacity(0.82)
                        : Color.clear
                )
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

                    if !anopeActionsForActiveWindow.isEmpty {
                        Divider()
                        anopeServicesMenu
                    }
                }
            }
        }
    }

    private var userListPanel: some View {
        GroupBox("Users") {
            List {
                if vm.activeUserList.isEmpty {
                    Text("No users to display")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.activeUserList, id: \.id) { user in
                        HStack(spacing: 8) {
                            Text(user.displayName)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(user.statusLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(statusForegroundColor(for: user.prefix))
                                .background(statusBackgroundColor(for: user.prefix))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedUserNick == user.nick ? Color.accentColor.opacity(0.22) : .clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUserNick = user.nick
                        }
                        .onTapGesture(count: 2) {
                            selectedUserNick = user.nick
                            vm.openPrivateConversation(with: user.nick)
                        }
                        .contextMenu {
                            Button("Open Private Chat") {
                                selectedUserNick = user.nick
                                vm.openPrivateConversation(with: user.nick)
                            }
                            Button("WHOIS") {
                                selectedUserNick = user.nick
                                vm.prefillWhois(for: user.nick)
                            }
                            Button("Mention") {
                                selectedUserNick = user.nick
                                vm.prefillMention(for: user.nick)
                            }

                            Divider()

                            Button("Op") {
                                selectedUserNick = user.nick
                                vm.performChannelUserMode(.op, for: user.nick)
                            }

                            Button("Deop") {
                                selectedUserNick = user.nick
                                vm.performChannelUserMode(.deop, for: user.nick)
                            }

                            Button("Voice") {
                                selectedUserNick = user.nick
                                vm.performChannelUserMode(.voice, for: user.nick)
                            }

                            Button("Devoice") {
                                selectedUserNick = user.nick
                                vm.performChannelUserMode(.devoice, for: user.nick)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                useCustomAppearance
                    ? color(from: vm.config.appearanceBackgroundColor).opacity(0.82)
                    : Color.clear
            )
        }
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
    }

    private var chatContentPanel: some View {
        VStack(spacing: 8) {
            if vm.activeWindow.type == .channel {
                channelTopicPanel
            }

            HStack(spacing: 10) {
                logPanel
                    .frame(maxWidth: .infinity)
                if vm.activeWindow.type == .channel {
                    userListPanel
                }
            }
        }
    }

    private var channelTopicPanel: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Topic:")
                .font(themedFont(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(vm.activeChannelTopic)
                .font(themedFont(size: 12))
                .foregroundStyle(useCustomAppearance ? color(from: vm.config.appearanceTextColor) : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var inputPanel: some View {
        HStack(spacing: 10) {
            TextField("Message \(vm.activeWindowTitle) or use command (/ms HELP, /os HELP, /join #chan)", text: $vm.input)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.primary)
                .focused($focusedField, equals: .messageInput)
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

            if !anopeActionsForActiveWindow.isEmpty {
                Divider()
                anopeServicesMenu
            }
        }
    }

    @ViewBuilder
    private var anopeServicesMenu: some View {
        Menu("Anope Services") {
            ForEach(AnopeService.allCases) { service in
                let actions = anopeActionsForActiveWindow.filter { $0.service == service }
                if !actions.isEmpty {
                    Menu(service.title) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                startAnopeAction(action)
                            }
                        }
                    }
                }
            }
        }
    }

    private var anopeActionsForActiveWindow: [AnopeMenuAction] {
        AnopeCommandCatalog.actions.filter { $0.windowTypes.contains(vm.activeWindow.type) }
    }

    @ViewBuilder
    private func anopePromptSheet(for action: AnopeMenuAction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(action.service.title) > \(action.title)")
                .font(.headline)

            Toggle("Advanced Mode", isOn: $anopeAdvancedMode)
                .toggleStyle(.switch)

            ForEach(action.inputFields) { field in
                if field.secure {
                    SecureField(field.label, text: Binding(
                        get: { anopeInputValues[field.id] ?? "" },
                        set: { anopeInputValues[field.id] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                } else {
                    TextField(field.label, text: Binding(
                        get: { anopeInputValues[field.id] ?? "" },
                        set: { anopeInputValues[field.id] = $0 }
                    ), prompt: Text(field.placeholder))
                    .textFieldStyle(.roundedBorder)
                }

                if anopeAdvancedMode && field.isOptional {
                    Text("Optional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if anopeAdvancedMode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(buildAnopeCommand(action, forPreview: true))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    activeAnopeAction = nil
                }
                Button("Run") {
                    runAnopeAction(action)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(action.inputFields.contains {
                    !$0.isOptional && (anopeInputValues[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                })
            }
        }
        .padding(16)
        .frame(minWidth: 420)
    }

    private func startAnopeAction(_ action: AnopeMenuAction) {
        guard !action.inputFields.isEmpty else {
            vm.executeAnopeCommand(action.commandTemplate)
            return
        }

        anopeInputValues = [:]
        if action.inputFields.contains(where: { $0.id == "channel" }), vm.activeWindow.type == .channel {
            anopeInputValues["channel"] = vm.activeWindow.target
        }
        if action.inputFields.contains(where: { $0.id == "nick" }), vm.activeWindow.type == .privateMessage {
            anopeInputValues["nick"] = vm.activeWindow.target
        }
        activeAnopeAction = action
    }

    private func runAnopeAction(_ action: AnopeMenuAction) {
        let command = buildAnopeCommand(action, forPreview: false)
        vm.executeAnopeCommand(command)
        activeAnopeAction = nil
    }

    private func buildAnopeCommand(_ action: AnopeMenuAction, forPreview: Bool) -> String {
        var command = action.commandTemplate
        for field in action.inputFields {
            let token = "{\(field.id)}"
            let value = (anopeInputValues[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if value.isEmpty {
                if forPreview {
                    command = command.replacingOccurrences(of: token, with: field.isOptional ? "<optional>" : "<\(field.id)>")
                } else {
                    command = command.replacingOccurrences(of: token, with: "")
                }
            } else {
                command = command.replacingOccurrences(of: token, with: value)
            }
        }

        if forPreview {
            return command.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }

        return command
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func themedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let clamped = max(10, min(32, size))
        guard useCustomAppearance else {
            return .system(size: clamped, weight: weight)
        }

        switch vm.config.appearanceFontFamily {
        case .system:
            return .system(size: clamped, weight: weight)
        case .rounded:
            return .system(size: clamped, weight: weight, design: .rounded)
        case .monospaced:
            return .system(size: clamped, weight: weight, design: .monospaced)
        case .serif:
            return .system(size: clamped, weight: weight, design: .serif)
        }
    }

    private func windowLogFont(for windowType: IRCWindowType, size: CGFloat) -> Font {
        if windowType == .server {
            return .system(size: max(11, min(32, size)), weight: .regular, design: .monospaced)
        }
        return themedFont(size: size)
    }

    private func statusBackgroundColor(for prefix: String) -> Color {
        switch prefix {
        case "~":
            return Color.red.opacity(0.24)
        case "&":
            return Color.orange.opacity(0.24)
        case "@":
            return Color.blue.opacity(0.24)
        case "%":
            return Color.green.opacity(0.24)
        case "+":
            return Color.cyan.opacity(0.24)
        default:
            return Color.secondary.opacity(0.18)
        }
    }

    private func statusForegroundColor(for prefix: String) -> Color {
        switch prefix {
        case "~", "&", "@", "%", "+":
            return .primary
        default:
            return .secondary
        }
    }

    private func color(from rgba: RGBAColor) -> Color {
        Color(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    private func rgba(from color: Color) -> RGBAColor {
        let nsColor = NSColor(color)
        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? NSColor.white
        return RGBAColor(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
    }

    private func focusMessageFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = .messageInput
        }
    }
}
