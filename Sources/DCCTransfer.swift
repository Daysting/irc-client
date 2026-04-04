import Foundation
import Network

// MARK: - Models

enum DCCTransferDirection {
    case sending
    case receiving
}

enum DCCTransferState: Equatable {
    case pending
    case connecting
    case active
    case completed
    case failed(String)
    case cancelled
}

@MainActor
final class DCCTransfer: Identifiable, ObservableObject {
    let id = UUID()
    let direction: DCCTransferDirection
    let peerNick: String
    let fileName: String
    let fileSize: Int64

    let localURL: URL?
    let offerHost: String?
    let offerPort: UInt16?

    @Published private(set) var bytesTransferred: Int64 = 0
    @Published private(set) var state: DCCTransferState = .pending

    var progress: Double {
        guard fileSize > 0 else { return 0 }
        return min(1.0, Double(bytesTransferred) / Double(fileSize))
    }
    var progressPercent: Int { Int(progress * 100) }
    var displaySize: String { Self.formatBytes(fileSize) }
    var displayTransferred: String { Self.formatBytes(bytesTransferred) }

    var onSendOffer: ((String) -> Void)?
    var onStateChanged: ((DCCTransferState) -> Void)?

    // Accessed only on the private dispatch queue after initial assignment.
    nonisolated(unsafe) private var _connection: NWConnection?
    nonisolated(unsafe) private var _listener: NWListener?
    nonisolated(unsafe) private var _fileHandle: FileHandle?
    nonisolated(unsafe) private var _ackBuffer = Data()

    private let queue = DispatchQueue(label: "DaystingIRC.DCC")

    init(
        direction: DCCTransferDirection,
        peerNick: String,
        fileName: String,
        fileSize: Int64,
        localURL: URL?,
        offerHost: String? = nil,
        offerPort: UInt16? = nil
    ) {
        self.direction = direction
        self.peerNick = peerNick
        self.fileName = fileName
        self.fileSize = fileSize
        self.localURL = localURL
        self.offerHost = offerHost
        self.offerPort = offerPort
    }

    // MARK: - Receiving

    func acceptReceive(saveTo url: URL) {
        guard direction == .receiving,
              let host = offerHost, let port = offerPort else { return }
        transition(to: .connecting)

        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let fh = FileHandle(forWritingAtPath: url.path) else {
            transition(to: .failed("Cannot open destination file"))
            return
        }
        _fileHandle = fh

        let endpoint = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            transition(to: .failed("Invalid port"))
            return
        }

        let conn = NWConnection(host: endpoint, port: nwPort, using: .tcp)
        _connection = conn

        conn.stateUpdateHandler = { [weak self] connState in
            guard let self else { return }
            switch connState {
            case .ready:
                Task { @MainActor in self.transition(to: .active) }
                self.recvLoop(conn: conn, fh: fh)
            case .failed(let err):
                Task { @MainActor in self.transition(to: .failed(err.localizedDescription)) }
                self.closeHandle()
            case .cancelled:
                Task { @MainActor in
                    if case .active = self.state { self.transition(to: .cancelled) }
                }
                self.closeHandle()
            default: break
            }
        }
        conn.start(queue: queue)
    }

    nonisolated private func recvLoop(conn: NWConnection, fh: FileHandle) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                do {
                    try fh.write(contentsOf: data)
                    let count = Int64(data.count)
                    Task { @MainActor in
                        self.bytesTransferred += count
                        let ack = Self.buildAck(self.bytesTransferred)
                        conn.send(content: ack, completion: .contentProcessed { _ in })
                    }
                } catch {
                    Task { @MainActor in self.transition(to: .failed("Write error: \(error.localizedDescription)")) }
                    conn.cancel()
                    self.closeHandle()
                    return
                }
            }
            if isComplete || error != nil {
                self.closeHandle()
                Task { @MainActor in
                    if case .active = self.state { self.transition(to: .completed) }
                }
                return
            }
            self.recvLoop(conn: conn, fh: fh)
        }
    }

    // MARK: - Sending

    func startSend(localIP: String) {
        guard direction == .sending, let url = localURL else { return }
        transition(to: .connecting)

        guard let fh = try? FileHandle(forReadingFrom: url) else {
            transition(to: .failed("Cannot read file"))
            return
        }
        _fileHandle = fh

        guard let listener = try? NWListener(using: .tcp) else {
            transition(to: .failed("Cannot create listener"))
            return
        }
        _listener = listener

        let escapedName = fileName.replacingOccurrences(of: " ", with: "_")
        let ipInt = Self.ipToInt32(localIP)
        let size = fileSize

        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            self._listener?.cancel()
            self._listener = nil
            self._connection = conn
            conn.stateUpdateHandler = { [weak self] connState in
                guard let self else { return }
                switch connState {
                case .ready:
                    Task { @MainActor in self.transition(to: .active) }
                    self.sendLoop(conn: conn, fh: fh)
                case .failed(let err):
                    Task { @MainActor in self.transition(to: .failed(err.localizedDescription)) }
                    self.closeHandle()
                case .cancelled:
                    Task { @MainActor in
                        if case .active = self.state { self.transition(to: .cancelled) }
                    }
                    self.closeHandle()
                default: break
                }
            }
            conn.start(queue: self.queue)
        }

        listener.stateUpdateHandler = { [weak self] listenerState in
            guard let self else { return }
            switch listenerState {
            case .ready:
                guard let port = listener.port?.rawValue else { return }
                let ctcp = "\u{1}DCC SEND \(escapedName) \(ipInt) \(port) \(size)\u{1}"
                Task { @MainActor in self.onSendOffer?(ctcp) }
            case .failed(let err):
                Task { @MainActor in self.transition(to: .failed(err.localizedDescription)) }
                self.closeHandle()
            default: break
            }
        }
        listener.start(queue: queue)
    }

    nonisolated private func sendLoop(conn: NWConnection, fh: FileHandle) {
        guard let chunk = try? fh.read(upToCount: 65536), !chunk.isEmpty else {
            ackWait(conn: conn)
            return
        }
        conn.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                Task { @MainActor in self.transition(to: .failed(error.localizedDescription)) }
                self.closeHandle()
                return
            }
            let count = Int64(chunk.count)
            Task { @MainActor in self.bytesTransferred += count }
            self.sendLoop(conn: conn, fh: fh)
        })
    }

    nonisolated private func ackWait(conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4) { [weak self] data, _, isComplete, _ in
            guard let self else { return }
            if let data { self._ackBuffer.append(data) }
            if isComplete || self._ackBuffer.count >= 4 {
                conn.cancel()
                self.closeHandle()
                Task { @MainActor in self.transition(to: .completed) }
                return
            }
            self.ackWait(conn: conn)
        }
    }

    // MARK: - Cancel

    func cancel() {
        _connection?.cancel()
        _connection = nil
        _listener?.cancel()
        _listener = nil
        closeHandle()
        transition(to: .cancelled)
    }

    // MARK: - Helpers

    private func transition(to newState: DCCTransferState) {
        state = newState
        onStateChanged?(newState)
    }

    nonisolated private func closeHandle() {
        try? _fileHandle?.close()
        _fileHandle = nil
    }

    nonisolated static func buildAck(_ bytes: Int64) -> Data {
        let value = UInt32(bytes & 0xFFFFFFFF).bigEndian
        return withUnsafeBytes(of: value) { Data($0) }
    }

    nonisolated static func ipToInt32(_ ip: String) -> UInt32 {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return 0 }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }

    nonisolated static func int32ToIP(_ value: UInt32) -> String {
        let a = (value >> 24) & 0xFF
        let b = (value >> 16) & 0xFF
        let c = (value >> 8) & 0xFF
        let d = value & 0xFF
        return "\(a).\(b).\(c).\(d)"
    }

    nonisolated static func formatBytes(_ count: Int64) -> String {
        if count <= 0 { return "?" }
        let kb = Double(count) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        return String(format: "%.1f GB", mb / 1024)
    }
}

// MARK: - Parser

struct DCCSendOffer {
    let senderNick: String
    let fileName: String
    let host: String
    let port: UInt16
    let fileSize: Int64
}

func parseDCCSendOffer(from line: String) -> DCCSendOffer? {
    guard line.hasPrefix(":"), line.contains(" PRIVMSG ") else { return nil }

    let prefixEnd = line.firstIndex(of: " ") ?? line.endIndex
    let prefix = String(line[line.index(after: line.startIndex)..<prefixEnd])
    let senderNick = prefix.split(separator: "!", maxSplits: 1).first.map(String.init) ?? ""
    guard !senderNick.isEmpty else { return nil }

    guard let ctcpRange = line.range(of: "\u{1}DCC SEND ") else { return nil }
    var payload = String(line[ctcpRange.upperBound...])
    if payload.hasSuffix("\u{1}") { payload = String(payload.dropLast()) }

    let parts = payload.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard parts.count >= 3 else { return nil }

    let fileName = parts[0]
    guard let ipInt = UInt32(parts[1]) else { return nil }
    guard let port = UInt16(parts[2]) else { return nil }
    let fileSize = parts.count >= 4 ? Int64(parts[3]) ?? 0 : Int64(0)

    let host = DCCTransfer.int32ToIP(ipInt)
    return DCCSendOffer(senderNick: senderNick, fileName: fileName, host: host, port: port, fileSize: fileSize)
}
