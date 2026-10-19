import CryptoKit
import Foundation

public enum CameraMediaError: LocalizedError {
    case invalidRequest, unavailable, invalidImage, tooLarge, interrupted
    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return L10n.text("Esta câmera não está disponível nesta conexão.")
        case .unavailable: return L10n.text("Não foi possível obter a imagem. Confira a câmera no Home Assistant e tente novamente.")
        case .invalidImage: return L10n.text("Esta câmera não forneceu uma imagem compatível.")
        case .tooLarge: return L10n.text("A imagem da câmera é grande demais. Reduza a resolução no Home Assistant.")
        case .interrupted: return L10n.text("A transmissão parou. Tente conectar novamente.")
        }
    }
}

/// Camera access is host-only. Never use entity_picture, which can contain a token.
public enum CameraMedia {
    public static let maximumBytes = 8 * 1024 * 1024
    public static func request(server: String, token: String, entityID: String, streaming: Bool = false) throws -> URLRequest {
        guard entityID.range(of: #"^camera\.[a-z0-9_]+$"#, options: .regularExpression) != nil,
              !token.isEmpty, !token.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw CameraMediaError.invalidRequest }
        let base = try ServerAddress.normalize(server)
        var url = URLComponents(url: base.appendingPathComponent(streaming ? "api/camera_proxy_stream" : "api/camera_proxy").appendingPathComponent(entityID), resolvingAgainstBaseURL: false)!
        if !streaming { url.queryItems = [URLQueryItem(name: "width", value: "720"), URLQueryItem(name: "height", value: "480")] }
        var request = URLRequest(url: url.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(streaming ? "multipart/x-mixed-replace" : "image/*", forHTTPHeaderField: "Accept")
        return request
    }

    public static func image(for request: URLRequest) async throws -> Data {
        let session = URLSession(configuration: configuration(), delegate: CameraRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") == true else { throw CameraMediaError.unavailable }
        guard response.expectedContentLength <= maximumBytes else { throw CameraMediaError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw CameraMediaError.tooLarge }
            data.append(byte)
        }
        guard !data.isEmpty else { throw CameraMediaError.invalidImage }
        return data
        } catch is CancellationError { throw CancellationError() }
        catch let error as CameraMediaError { throw error }
        catch { throw CameraMediaError.unavailable }
    }

    public static func stream(for request: URLRequest) -> CameraTransmission {
        let pair = AsyncThrowingStream<Data, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let receiver = CameraStreamReceiver(continuation: pair.continuation)
        let session = URLSession(configuration: configuration(), delegate: receiver, delegateQueue: nil)
        pair.continuation.onTermination = { _ in session.invalidateAndCancel() }
        session.dataTask(with: request).resume()
        return CameraTransmission(frames: pair.stream, cancelRequest: { session.invalidateAndCancel() })
    }

    private static func configuration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        config.timeoutIntervalForResource = 3600
        return config
    }
}

public struct CameraTransmission: Sendable {
    public let frames: AsyncThrowingStream<Data, Error>
    fileprivate let cancelRequest: @Sendable () -> Void
    public func cancel() { cancelRequest() }
}

private class CameraRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // The configured HA URL must be final; never forward a bearer token to a redirect.
        completionHandler(nil)
    }
}

/// Multipart parsing honors Content-Length and also supports streams without it.
/// Incomplete frames and headers are bounded even if the server never sends a boundary.
public struct CameraMultipartDecoder {
    private let delimiter: Data
    private var buffer = Data()
    public init(boundary: String) throws {
        guard !boundary.isEmpty, boundary.utf8.count <= 200, !boundary.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw CameraMediaError.invalidImage }
        delimiter = Data(("--" + boundary).utf8)
    }
    public mutating func append(_ data: Data) throws -> [Data] {
        guard buffer.count + data.count <= CameraMedia.maximumBytes + 65536 else { throw CameraMediaError.tooLarge }
        buffer.append(data)
        var result: [Data] = []
        while let start = buffer.range(of: delimiter) {
            if start.lowerBound > buffer.startIndex { buffer.removeSubrange(buffer.startIndex..<start.lowerBound) }
            let headerStart = buffer.startIndex + delimiter.count
            guard let headersEnd = buffer.range(of: Data("\r\n\r\n".utf8), in: headerStart..<buffer.endIndex) else {
                guard buffer.count < 32768 else { throw CameraMediaError.invalidImage }; break
            }
            let headers = String(decoding: buffer[headerStart..<headersEnd.lowerBound], as: UTF8.self)
            let lengthLine = headers.components(separatedBy: "\r\n").first { $0.lowercased().hasPrefix("content-length:") }
            let bodyStart = headersEnd.upperBound
            let bodyEnd: Data.Index
            if let lengthLine {
                guard let length = Int(lengthLine.split(separator: ":", maxSplits: 1).last!.trimmingCharacters(in: .whitespaces)), length > 0 else { throw CameraMediaError.invalidImage }
                guard length <= CameraMedia.maximumBytes else { throw CameraMediaError.tooLarge }
                guard buffer.endIndex - bodyStart >= length else { break }
                bodyEnd = bodyStart + length
            } else {
                guard let next = buffer.range(of: Data("\r\n".utf8) + delimiter, in: bodyStart..<buffer.endIndex) else { break }
                bodyEnd = next.lowerBound
            }
            guard bodyEnd > bodyStart else { throw CameraMediaError.invalidImage }
            result.append(Data(buffer[bodyStart..<bodyEnd]))
            buffer.removeSubrange(buffer.startIndex..<bodyEnd)
        }
        return result
    }
}

private final class CameraStreamReceiver: CameraRedirectGuard, URLSessionDataDelegate, @unchecked Sendable {
    let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var decoder: CameraMultipartDecoder?
    private var finished = false
    private var nativeFrame: Data?
    private var nativeLength: Int64 = -1
    init(continuation: AsyncThrowingStream<Data, Error>.Continuation) { self.continuation = continuation }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            completionHandler(.cancel); finish(CameraMediaError.unavailable, session: session); return
        }
        // Foundation can decode multipart streams itself and deliver a response per image.
        // On other servers it delivers the raw multipart body; support both paths.
        if http.mimeType?.hasPrefix("image/") == true {
            if let nativeFrame, !nativeFrame.isEmpty { continuation.yield(nativeFrame) }
            guard response.expectedContentLength <= CameraMedia.maximumBytes else {
                completionHandler(.cancel); finish(CameraMediaError.tooLarge, session: session); return
            }
            nativeFrame = Data(); nativeLength = response.expectedContentLength; decoder = nil
            completionHandler(.allow); return
        }
        guard let contentType = http.value(forHTTPHeaderField: "Content-Type"),
              contentType.lowercased().hasPrefix("multipart/x-mixed-replace"),
              let value = contentType.components(separatedBy: ";").dropFirst().first(where: { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("boundary=") }),
              let boundary = value.split(separator: "=", maxSplits: 1).last else {
            completionHandler(.cancel); finish(CameraMediaError.unavailable, session: session); return
        }
        do {
            decoder = try CameraMultipartDecoder(boundary: String(boundary).trimmingCharacters(in: CharacterSet(charactersIn: " \"")))
            completionHandler(.allow)
        } catch { completionHandler(.cancel); finish(error, session: session) }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if nativeFrame != nil {
            guard nativeFrame!.count + data.count <= CameraMedia.maximumBytes else { finish(CameraMediaError.tooLarge, session: session); return }
            nativeFrame!.append(data)
            if nativeLength > 0, nativeFrame!.count >= nativeLength {
                continuation.yield(nativeFrame!); nativeFrame = Data()
            }
            return
        }
        do { for frame in try decoder?.append(data) ?? [] { continuation.yield(frame) } }
        catch { finish(error, session: session) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil, let nativeFrame, !nativeFrame.isEmpty { continuation.yield(nativeFrame) }
        finish(error ?? CameraMediaError.interrupted, session: session)
    }
    private func finish(_ error: Error, session: URLSession) {
        guard !finished else { return }; finished = true
        continuation.finish(throwing: error)
        session.invalidateAndCancel()
    }
}

public struct CameraSnapshot: Codable, Equatable, Sendable {
    public let data: Data
    public let capturedAt: Date
    public init(data: Data, capturedAt: Date = Date()) { self.data = data; self.capturedAt = capturedAt }
}

/// Private local image cache. Hashed, account-scoped IDs never become path components.
public struct CameraSnapshotStore {
    public static let maximumBytes = 1024 * 1024
    private let directory: URL
    public init(directory: URL) { self.directory = directory.appendingPathComponent("CameraImages", isDirectory: true) }
    public static func configured(bundle: Bundle = .main) -> Self? {
        ControlSharedStore.configuredDirectory(bundle: bundle).map(Self.init)
    }
    private func filename(_ id: String) -> String { SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined() + ".plist" }
    public func read(id: String) throws -> CameraSnapshot {
        let url = directory.appendingPathComponent(filename(id))
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= Self.maximumBytes + 1024 else { throw CameraMediaError.tooLarge }
        let value = try PropertyListDecoder().decode(CameraSnapshot.self, from: Data(contentsOf: url))
        guard value.data.count <= Self.maximumBytes else { throw CameraMediaError.tooLarge }
        return value
    }
    public func write(_ snapshot: CameraSnapshot, id: String) throws {
        guard !snapshot.data.isEmpty, snapshot.data.count <= Self.maximumBytes else { throw CameraMediaError.tooLarge }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let data = try encoder.encode(snapshot)
        let url = directory.appendingPathComponent(filename(id))
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public func retain(only ids: Set<String>) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let allowed = Set(ids.map(filename))
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where !allowed.contains(file.lastPathComponent) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
