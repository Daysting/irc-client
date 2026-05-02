import SwiftUI

#if os(tvOS)

// MARK: - Reusable tvOS Components

private struct TVSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
            }
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.15))
        )
    }
}

private struct TVTextInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.2))
            )
    }
}

// MARK: - Main tvOS View

struct TVOSContentView: View {
    private enum FocusField: Hashable {
        case messageInput
    }

    @EnvironmentObject private var vm: IRCViewModel
    @FocusState private var focusedField: FocusField?
    @State private var customServerHost = ""
    @State private var customServerPort = "6697"
    @State private var customServerErrorMessage = ""
    @State private var isCustomConnectSheetPresented = false

    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.10, green: 0.10, blue: 0.12, opacity: 1)
                .ignoresSafeArea()
            if vm.isConnected {
                connectedView
            } else {
                disconnectedView
            }
        }
        .onAppear { focusMessageFieldSoon() }
        .onChange(of: vm.selectedWindowID) { _ in focusMessageFieldSoon() }
        .onChange(of: vm.isConnected) { _ in focusMessageFieldSoon() }
    }

    // MARK: - Connected Layout (iPad template)

    private var connectedView: some View {
        VStack(spacing: 16) {
            topBar
            windowTabsBar
            HStack(alignment: .top, spacing: 16) {
                mainChatArea
                if vm.activeWindow.type == .channel {
                    userListSidebar
                        .frame(width: 260)
                }
            }
            .frame(maxHeight: .infinity)
            inputArea
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
    }

    private var topBar: some View {
        HStack {
            Text(vm.activeWindowTitle)
                .font(.title3.bold())
            if let topic = vm.channelTopicsByPaneID[vm.activeWindow.id], !topic.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
                Text(topic)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
            Button("Disconnect") {
                vm.disconnect()
            }
        }
    }

    private var windowTabsBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(vm.windows) { pane in
                    Button {
                        vm.selectWindow(pane.id)
                    } label: {
                        HStack(spacing: 6) {
                            Text(pane.title)
                                .font(.callout)
                            if pane.unreadCount > 0 {
                                Text("\(pane.unreadCount)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(vm.selectedWindowID == pane.id
                                      ? Color.accentColor
                                      : Color.secondary.opacity(0.2))
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable()
                }
            }
        }
    }

    private var mainChatArea: some View {
        TVSection {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(vm.activeLogs.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.callout, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: vm.activeLogs.count) { _ in
                    guard !vm.activeLogs.isEmpty else { return }
                    proxy.scrollTo(vm.activeLogs.count - 1, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var userListSidebar: some View {
        TVSection(title: "Users (\(vm.activeUserList.count))") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(vm.activeUserList) { user in
                        Button {
                            vm.openPrivateConversation(with: user.nick)
                        } label: {
                            HStack(spacing: 8) {
                                if !user.prefix.isEmpty {
                                    Text(user.prefix)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 14)
                                }
                                Text(user.nick)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Message \(vm.activeWindowTitle) or use /command…", text: $vm.input)
                .modifier(TVTextInputStyle())
                .focused($focusedField, equals: .messageInput)
                .onSubmit { vm.sendCurrentInput() }
                .frame(maxWidth: .infinity)

            Button("Send") {
                vm.sendCurrentInput()
            }
            .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Disconnected Layout

    private var disconnectedView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("DaystingIRC")
                    .font(.largeTitle.bold())
                    .padding(.top, 20)

                TVSection(title: "Connection Profile") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nickname").font(.callout).foregroundStyle(.secondary)
                                TextField("Your nickname", text: $vm.config.nickname)
                                    .modifier(TVTextInputStyle())
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Channel").font(.callout).foregroundStyle(.secondary)
                                TextField("#channel", text: $vm.config.channel)
                                    .modifier(TVTextInputStyle())
                            }
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NickServ Password (optional)").font(.callout).foregroundStyle(.secondary)
                                SecureField("NickServ password", text: $vm.config.nickServPassword)
                                    .modifier(TVTextInputStyle())
                            }
                            Spacer()
                        }

                        HStack(spacing: 16) {
                            Button("Connect to Daysting") {
                                vm.connectToDaysting()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!vm.canConnectWithCurrentProfile)

                            Button("Custom Server…") {
                                isCustomConnectSheetPresented = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(!vm.canConnectWithCurrentProfile)
                        }

                        if !vm.profileValidationErrors.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(vm.profileValidationErrors, id: \.self) { err in
                                    Text("⚠️ \(err)")
                                        .foregroundStyle(.red)
                                        .font(.callout)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: 900)
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $isCustomConnectSheetPresented) {
            customConnectSheet
        }
    }

    private var customConnectSheet: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Connect to Custom Server")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Server Address").font(.callout).foregroundStyle(.secondary)
                TextField("irc.example.com", text: $customServerHost)
                    .modifier(TVTextInputStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Port").font(.callout).foregroundStyle(.secondary)
                TextField("6697", text: $customServerPort)
                    .modifier(TVTextInputStyle())
            }

            Text("TLS is required.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !customServerErrorMessage.isEmpty {
                Text(customServerErrorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    isCustomConnectSheetPresented = false
                    customServerErrorMessage = ""
                }

                Button("Connect") {
                    connectCustomServer()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(48)
        .frame(width: 700)
    }

    // MARK: - Helpers

    private func connectCustomServer() {
        let host = customServerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            customServerErrorMessage = "Server address is required."
            return
        }
        guard let port = UInt16(customServerPort), port > 0 else {
            customServerErrorMessage = "Port must be a valid number (1–65535)."
            return
        }
        isCustomConnectSheetPresented = false
        customServerErrorMessage = ""
        vm.connectToServer(host: host, port: port, useTLS: true)
    }

    private func focusMessageFieldSoon() {
        guard vm.isConnected else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .messageInput
        }
    }
}

#endif
