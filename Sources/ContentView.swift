import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @State private var showDeleteThemeConfirmation = false
    @State private var showImportStrategyConfirmation = false
    @State private var pendingImportData: Data?
    @State private var pendingImportFileName: String = ""
    @State private var selectedUserNick: String?
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

    private var appearanceTextColorBinding: Binding<Color> {
        Binding(
            get: { color(from: vm.config.appearanceTextColor) },
            set: { vm.config.appearanceTextColor = rgba(from: $0) }
        )
    }

    private var appearanceBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { color(from: vm.config.appearanceBackgroundColor) },
            set: { vm.config.appearanceBackgroundColor = rgba(from: $0) }
        )
    }

    var body: some View {
        ZStack {
            effectiveBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 12) {
                serverConfigPanel
                paneTabsPanel
                serviceShortcuts
                chatContentPanel
                inputPanel
            }
            .padding(16)
        }
        .font(effectiveBaseFont)
        .confirmationDialog("Delete selected theme?", isPresented: $showDeleteThemeConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                vm.deleteSelectedTheme()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the currently selected theme preset.")
        }
        .confirmationDialog("Import Themes", isPresented: $showImportStrategyConfirmation, titleVisibility: .visible) {
            Button("Replace Existing Names") {
                runThemeImport(strategy: .replaceExistingNames)
            }
            Button("Keep Both") {
                runThemeImport(strategy: .keepBoth)
            }
            Button("Cancel", role: .cancel) {
                vm.setThemeStatus("Import canceled", isError: true)
                pendingImportData = nil
                pendingImportFileName = ""
            }
        } message: {
            Text("Choose how to handle imported themes that have the same name as existing themes.")
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
                    Toggle("Custom Theme", isOn: $vm.config.enableCustomAppearance)
                        .toggleStyle(.switch)
                        .frame(width: 130)
                    Picker("Font", selection: $vm.config.appearanceFontFamily) {
                        ForEach(AppearanceFontFamily.allCases) { family in
                            Text(family.title).tag(family)
                        }
                    }
                    .frame(width: 220)
                    Stepper(
                        "Font Size: \(Int(vm.config.appearanceFontSize))",
                        value: $vm.config.appearanceFontSize,
                        in: 10...24,
                        step: 1
                    )
                    .frame(width: 180)
                    ColorPicker("Text", selection: appearanceTextColorBinding, supportsOpacity: true)
                        .frame(width: 150)
                    ColorPicker("Background", selection: appearanceBackgroundColorBinding, supportsOpacity: true)
                        .frame(width: 180)
                    Spacer()
                }

                HStack(spacing: 10) {
                    TextField("Theme Name", text: $vm.themeDraftName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)

                    Button("Save Theme") {
                        vm.saveCurrentTheme()
                    }
                    .disabled(vm.themeDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Picker("Saved Themes", selection: $vm.selectedThemeID) {
                        Text("Select Theme").tag("")
                        ForEach(vm.savedThemes) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .frame(width: 240)

                    Button("Apply Theme") {
                        vm.applySelectedTheme()
                    }
                    .disabled(!vm.hasSelectedSavedTheme)

                    Button("Delete Theme") {
                        showDeleteThemeConfirmation = true
                    }
                    .disabled(!vm.hasSelectedSavedTheme)

                    Button("Reset Theme") {
                        vm.resetAppearanceToDefaults()
                    }

                    Button("Export Themes") {
                        exportThemesToJSONFile()
                    }

                    Button("Import Themes") {
                        importThemesFromJSONFile()
                    }

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
        HStack(spacing: 10) {
            logPanel
                .frame(maxWidth: .infinity)
            if vm.activeWindow.type == .channel {
                userListPanel
            }
        }
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
        }
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

    private func exportThemesToJSONFile() {
        guard let data = vm.exportThemesData() else {
            vm.setThemeStatus("Export failed: unable to encode themes", isError: true)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Theme Presets"
        panel.nameFieldStringValue = "daysting-themes.json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            vm.setThemeStatus("Export canceled", isError: true)
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            vm.setThemeStatus("Exported themes to \(url.lastPathComponent)", isError: false)
        } catch {
            vm.setThemeStatus("Export failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func importThemesFromJSONFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Theme Presets"
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            vm.setThemeStatus("Import canceled", isError: true)
            return
        }

        do {
            let data = try Data(contentsOf: url)
            pendingImportData = data
            pendingImportFileName = url.lastPathComponent
            showImportStrategyConfirmation = true
        } catch {
            vm.setThemeStatus("Import failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func runThemeImport(strategy: IRCViewModel.ThemeImportStrategy) {
        guard let data = pendingImportData else {
            vm.setThemeStatus("Import failed: no file data loaded", isError: true)
            return
        }
        let imported = vm.importThemesData(data, strategy: strategy)
        if imported > 0 {
            vm.setThemeStatus("Imported \(imported) theme(s) from \(pendingImportFileName)", isError: false)
        }
        pendingImportData = nil
        pendingImportFileName = ""
    }

    private func focusMessageFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = .messageInput
        }
    }
}
