import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

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
#if canImport(UIKit)
        UIPasteboard.general.string = example
#elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(example, forType: .string)
#endif
        didCopyExample = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyExample = false
        }
    }
}

#if os(macOS)
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
#endif

private extension View {
    @ViewBuilder
    func withMiddleClickCapture(_ onMiddleClick: @escaping () -> Void) -> some View {
#if os(macOS)
        background(MiddleClickCaptureView(onMiddleClick: onMiddleClick))
#else
        self
#endif
    }
}

private struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8)
        {
            text = decoded
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ContentView: View {
    private enum FocusField: Hashable {
        case messageInput
    }

    @EnvironmentObject private var vm: IRCViewModel
#if canImport(UIKit)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @State private var selectedUserNick: String?
    @State private var activeAnopeAction: AnopeMenuAction?
    @State private var anopeInputValues: [String: String] = [:]
    @State private var anopeAdvancedMode = false
    @FocusState private var focusedField: FocusField?
    @State private var isCustomConnectSheetPresented = false
    @State private var customServerHost = ""
    @State private var customServerPort = "6697"
    @State private var customServerErrorMessage = ""
    @State private var isThemeControlsPresented = false
    @State private var isUsersSheetPresented = false
    @State private var showLogExporter = false
    @State private var logExportDocument: TextFileDocument?
    @State private var showDCCFileImporter = false
    @State private var dccSendTargetNick: String?

    private var useCustomAppearance: Bool {
        vm.config.enableCustomAppearance
    }

    private var effectiveBackgroundColor: Color {
        if useCustomAppearance {
            return color(from: vm.config.appearanceBackgroundColor)
        }
    #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
    #else
        return Color(.systemBackground)
    #endif
    }

    private var effectiveBaseFont: Font {
        let size = CGFloat(max(10, min(24, vm.config.appearanceFontSize)))
        return themedFont(size: size)
    }

    var body: some View {
        ZStack {
            effectiveBackgroundColor
                .ignoresSafeArea()

            Group {
                #if os(iOS)
                if vm.isConnected {
                    connectedContent
                } else {
                    disconnectedIOSContent
                }
                #else
                connectedContent
                #endif
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .font(effectiveBaseFont)
        .sheet(item: $activeAnopeAction) { action in
            anopePromptSheet(for: action)
        }
        .sheet(isPresented: $isCustomConnectSheetPresented) {
            customConnectSheet
        }
        .sheet(isPresented: $isThemeControlsPresented) {
            ThemeControlsView()
                .environmentObject(vm)
        }
        .sheet(isPresented: $isUsersSheetPresented) {
            usersSheet
        }
        .fileExporter(
            isPresented: $showLogExporter,
            document: logExportDocument,
            contentType: .plainText,
            defaultFilename: "\(vm.activeWindowTitle.replacingOccurrences(of: " ", with: "-")).txt"
        ) { result in
            switch result {
            case .success:
                vm.setThemeStatus("Log exported", isError: false)
            case .failure(let error):
                vm.setThemeStatus("Log export failed: \(error.localizedDescription)", isError: true)
            }
            logExportDocument = nil
        }
        .fileImporter(isPresented: $showDCCFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            guard let nick = dccSendTargetNick else { return }
            defer { dccSendTargetNick = nil }

            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                vm.sendFile(url, to: nick)
            case .failure(let error):
                vm.setThemeStatus("DCC file selection failed: \(error.localizedDescription)", isError: true)
            }
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

    private var contentPadding: CGFloat {
#if os(iOS)
        return 10
#else
        return 16
#endif
    }

#if os(iOS)
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
#else
    private var isIPad: Bool {
        false
    }
#endif

    @ViewBuilder
    private var connectedContent: some View {
#if os(iOS)
        if isIPad {
            ipadConnectedContent
        } else {
            iphoneConnectedContent
        }
#else
        macosConnectedContent
#endif
    }

    private var iphoneConnectedContent: some View {
        VStack(spacing: 12) {
            if vm.isConnected {
                connectedTopBar
            } else {
                serverConfigPanel
            }
            paneTabsPanel
            chatContentPanel
                .frame(maxHeight: .infinity)
            if !vm.dccTransfers.isEmpty {
                dccTransfersPanel
            }
            inputPanel
        }
    }

    private var ipadConnectedContent: some View {
        VStack(spacing: 12) {
            if vm.isConnected {
                connectedTopBar
            } else {
                serverConfigPanel
            }
            paneTabsPanel
            HStack(spacing: 10) {
                VStack(spacing: 8) {
                    if vm.activeWindow.type == .channel {
                        channelTopicPanel
                    }
                    HStack(spacing: 10) {
                        logPanel
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                if vm.activeWindow.type == .channel {
                    userListPanel
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
                }
            }
            if !vm.dccTransfers.isEmpty {
                dccTransfersPanel
            }
            inputPanel
        }
    }

    private var macosConnectedContent: some View {
        VStack(spacing: 12) {
            if vm.isConnected {
                connectedTopBar
            } else {
                serverConfigPanel
            }
            paneTabsPanel
            chatContentPanel
            if !vm.dccTransfers.isEmpty {
                dccTransfersPanel
            }
            inputPanel
        }
    }

#if os(iOS)
    private var disconnectedIOSContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                serverConfigPanel
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
#endif

    private var serverConfigPanel: some View {
        GroupBox("Connection") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Quick Connect")
                        .font(themedFont(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)

                    Button("Daysting Server") {
                        vm.connectToDaysting()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("k", modifiers: [.command])
                    .disabled(!vm.canConnectWithCurrentProfile)

                    Button("Custom Server...") {
                        openCustomConnectSheet()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!vm.canConnectWithCurrentProfile)

                    Spacer()
                }

                HStack(spacing: 10) {
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
                    Button("Theme Controls") {
                        isThemeControlsPresented = true
                    }
                    .buttonStyle(.bordered)
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

    private var customConnectSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect to IRC Server")
                .font(.headline)

            HStack(spacing: 8) {
                Menu("Presets") {
                    ForEach(vm.serverPresets) { endpoint in
                        Button(endpoint.displayName) {
                            applyServerEndpoint(endpoint)
                        }
                    }
                }

                Menu("Favorites") {
                    if vm.favoriteCustomServers.isEmpty {
                        Text("No favorite servers")
                    } else {
                        ForEach(vm.favoriteCustomServers) { endpoint in
                            Button(endpoint.displayName) {
                                applyServerEndpoint(endpoint)
                            }
                        }
                        Divider()
                        Button("Clear Favorites") {
                            vm.clearFavoriteCustomServers()
                        }
                    }
                }

                Menu("Recent") {
                    if vm.recentCustomServers.isEmpty {
                        Text("No recent servers")
                    } else {
                        ForEach(vm.recentCustomServers) { endpoint in
                            Button(recentEndpointTitle(endpoint)) {
                                applyServerEndpoint(endpoint)
                            }
                        }
                        Divider()
                        Button("Clear Recent") {
                            vm.clearRecentCustomServers()
                        }
                    }
                }
            }

            TextField("Server Address", text: $customServerHost)
                .textFieldStyle(.roundedBorder)

            TextField("Port", text: $customServerPort)
                .textFieldStyle(.roundedBorder)

            Text("TLS is required. Non-TLS server connections are blocked.")
                .font(themedFont(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(isCurrentCustomServerFavorite ? "Remove Favorite" : "Save as Favorite") {
                    toggleCurrentServerFavorite()
                }
                .buttonStyle(.bordered)
                .disabled(currentSheetPort == nil || customServerHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }

            if !customServerErrorMessage.isEmpty {
                Text(customServerErrorMessage)
                    .font(themedFont(size: 12))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isCustomConnectSheetPresented = false
                    customServerErrorMessage = ""
                }
                Button("Connect") {
                    connectCustomServerFromSheet()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private var connectedTopBar: some View {
        HStack {
#if os(iOS)
            if vm.activeWindow.type == .channel && !isIPad {
                Button {
                    isUsersSheetPresented = true
                } label: {
                    Label("Users", systemImage: "person.2")
                }
                .buttonStyle(.bordered)
            }
#endif

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
                paneSelectionControl

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

    @ViewBuilder
    private var paneSelectionControl: some View {
#if os(iOS)
        GeometryReader { geo in
            if useCompactPanePicker(availableWidth: geo.size.width) {
                Menu {
                    ForEach(vm.windows) { pane in
                        Button {
                            vm.selectWindow(pane.id)
                        } label: {
                            HStack(spacing: 8) {
                                if vm.selectedWindowID == pane.id {
                                    Image(systemName: "checkmark")
                                }
                                Text(compactPaneTitle(for: pane))
                            }
                        }
                    }
                } label: {
                    Label("Pane: \(compactPaneTitle(for: vm.activeWindow))", systemImage: "rectangle.grid.1x2")
                }
                .buttonStyle(.bordered)
            } else {
                fullPaneTabsStrip
            }
        }
        .fixedSize(horizontal: false, vertical: true)
#else
        fullPaneTabsStrip
#endif
    }

    private var fullPaneTabsStrip: some View {
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
                        .withMiddleClickCapture {
                            if vm.canCloseWindow(pane.id) {
                                vm.closeWindow(pane.id)
                            }
                        }

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
    }

    private func compactPaneTitle(for pane: IRCWindowPane) -> String {
        if pane.unreadCount > 0 {
            return "\(pane.title) (\(pane.unreadCount))"
        }
        return pane.title
    }

    private func useCompactPanePicker(availableWidth: CGFloat) -> Bool {
#if os(iOS)
        guard horizontalSizeClass == .compact else { return false }
        // Estimate total tab strip width: ~10 pts per character + 24 pts padding per tab,
        // plus 8 pts spacing between tabs. Reserve ~160 pts for the Context Commands button.
        let reservedWidth: CGFloat = 160
        let usable = availableWidth - reservedWidth
        let estimatedTotal = vm.windows.reduce(CGFloat(0)) { acc, pane in
            let title = pane.title
            // +1 character if there is an unread badge
            let charCount = CGFloat(title.count + (pane.unreadCount > 0 ? 4 : 0))
            return acc + charCount * 10 + 24 + 8
        }
        return estimatedTotal > usable
#else
        return false
#endif
    }

    private var logPanel: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Text("\(vm.activeWindowTitle) Log")
                        .font(themedFont(size: 14, weight: .semibold))
                    Spacer()
                    Button("Save Log") {
                        saveActiveLog()
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.activeLogs.isEmpty)

#if os(macOS)
                    Button("Print Log") {
                        printActiveLog()
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.activeLogs.isEmpty)
#endif
                }

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

                        Divider()

                        Button("Save Log") {
                            saveActiveLog()
                        }
                        .disabled(vm.activeLogs.isEmpty)

#if os(macOS)
                        Button("Print Log") {
                            printActiveLog()
                        }
                        .disabled(vm.activeLogs.isEmpty)
#endif
                    }
                }
            }
        }
    }

    private var userListPanel: some View {
        GroupBox("Users") {
            usersList
        }
#if os(macOS)
        .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
#endif
    }

    private var usersList: some View {
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
                        Button("Send File via DCC...") {
                            selectedUserNick = user.nick
                            promptDCCSend(to: user.nick)
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

    private var usersSheet: some View {
#if os(iOS)
        NavigationStack {
            usersList
                .navigationTitle("Channel Users")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isUsersSheetPresented = false
                        }
                    }
                }
        }
#else
        userListPanel
#endif
    }

    private var chatContentPanel: some View {
        VStack(spacing: 8) {
            if vm.activeWindow.type == .channel {
                channelTopicPanel
            }

            HStack(spacing: 10) {
                logPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(macOS)
                if vm.activeWindow.type == .channel {
                    userListPanel
                }
#endif
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func saveActiveLog() {
        logExportDocument = TextFileDocument(text: vm.activeLogsText)
        showLogExporter = true
    }

#if os(macOS)
    private func printActiveLog() {
        let logText = vm.activeLogsText
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 960))
        textView.isEditable = false
        textView.isSelectable = true
        textView.string = logText
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.topMargin = 24
        printInfo.bottomMargin = 24
        printInfo.leftMargin = 24
        printInfo.rightMargin = 24

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
#endif

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

    // MARK: - DCC Panel

    private var dccTransfersPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DCC File Transfers")
                        .font(themedFont(size: 12, weight: .semibold))
                    Spacer()
                    Button("Clear Finished") {
                        vm.clearCompletedDCCTransfers()
                    }
                    .controlSize(.small)
                }

                ForEach(vm.dccTransfers) { transfer in
                    dccTransferRow(transfer)
                }
            }
        }
    }

    @ViewBuilder
    private func dccTransferRow(_ transfer: DCCTransfer) -> some View {
        HStack(spacing: 10) {
            Image(systemName: transfer.direction == .sending ? "arrow.up.circle" : "arrow.down.circle")
                .foregroundStyle(dccDirectionColor(transfer.direction))

            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.fileName)
                    .font(themedFont(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("\(transfer.direction == .sending ? "→" : "←") \(transfer.peerNick)  \(dccStateLabel(transfer))")
                    .font(themedFont(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if case .active = transfer.state, transfer.fileSize > 0 {
                ProgressView(value: transfer.progress)
                    .frame(width: 80)
                Text("\(transfer.progressPercent)%")
                    .font(themedFont(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            if case .pending = transfer.state, transfer.direction == .receiving {
                Button("Accept") {
                    vm.acceptDCCTransfer(id: transfer.id)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)

                Button("Decline") {
                    vm.cancelDCCTransfer(id: transfer.id)
                }
                .controlSize(.small)
            } else if case .active = transfer.state {
                Button("Cancel") {
                    vm.cancelDCCTransfer(id: transfer.id)
                }
                .controlSize(.small)
            } else if case .connecting = transfer.state {
                ProgressView()
                    .controlSize(.small)
                Button("Cancel") {
                    vm.cancelDCCTransfer(id: transfer.id)
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func dccStateLabel(_ transfer: DCCTransfer) -> String {
        switch transfer.state {
        case .pending:       return "Pending offer"
        case .connecting:    return "Connecting…"
        case .active:        return "\(transfer.displayTransferred) / \(transfer.displaySize)"
        case .completed:     return "Completed (\(transfer.displaySize))"
        case .cancelled:     return "Cancelled"
        case .failed(let r): return "Failed: \(r)"
        }
    }

    private func dccDirectionColor(_ direction: DCCTransferDirection) -> Color {
        direction == .sending ? .blue : .green
    }

    private func promptDCCSend(to nick: String) {
        dccSendTargetNick = nick
        showDCCFileImporter = true
    }

    private func openCustomConnectSheet() {
        customServerHost = vm.config.host
        customServerPort = String(vm.config.port)
        customServerErrorMessage = ""
        isCustomConnectSheetPresented = true
    }

    private func applyServerEndpoint(_ endpoint: IRCServerEndpoint) {
        customServerHost = endpoint.host
        customServerPort = String(endpoint.port)
        customServerErrorMessage = ""
    }

    private func connectCustomServerFromSheet() {
        let host = customServerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            customServerErrorMessage = "Server address is required."
            return
        }

        guard let port = UInt16(customServerPort.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            customServerErrorMessage = "Port must be a number between 0 and 65535."
            return
        }

        customServerErrorMessage = ""
        isCustomConnectSheetPresented = false
        vm.connectToServer(host: host, port: port, useTLS: true)
    }

    private var currentSheetPort: UInt16? {
        UInt16(customServerPort.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isCurrentCustomServerFavorite: Bool {
        let host = customServerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let port = currentSheetPort else { return false }
        return vm.isFavoriteCustomServer(host: host, port: port, useTLS: true)
    }

    private func toggleCurrentServerFavorite() {
        let host = customServerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let port = currentSheetPort else { return }

        if vm.isFavoriteCustomServer(host: host, port: port, useTLS: true) {
            vm.removeFavoriteCustomServer(host: host, port: port, useTLS: true)
        } else {
            vm.saveFavoriteCustomServer(host: host, port: port, useTLS: true)
        }
    }

    private func recentEndpointTitle(_ endpoint: IRCServerEndpoint) -> String {
        if vm.isFavoriteCustomServer(host: endpoint.host, port: endpoint.port, useTLS: endpoint.useTLS) {
            return "★ \(endpoint.displayName)"
        }
        return endpoint.displayName
    }

    private func themedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let clamped = max(10, min(32, size))
        guard useCustomAppearance else {
            return .system(size: clamped, weight: weight)
        }

        if let configuredName = vm.config.appearanceFontName?.trimmingCharacters(in: .whitespacesAndNewlines), !configuredName.isEmpty {
            return .custom(configuredName, size: clamped)
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
#if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBAColor(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
#elseif canImport(AppKit)
        let nsColor = NSColor(color)
        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? NSColor.white
        return RGBAColor(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
#else
        return RGBAColor.defaultText
#endif
    }

    private func focusMessageFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = .messageInput
        }
    }
}
