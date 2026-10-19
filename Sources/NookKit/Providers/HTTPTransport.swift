import Foundation

public enum HTTPTransportError: Error, Equatable {
    case invalidResponse
    case transport(String)
}

public protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    static let shared = NoRedirectDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            self.session = URLSession(
                configuration: configuration,
                delegate: NoRedirectDelegate.shared,
                delegateQueue: nil
            )
        }
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HTTPTransportError.invalidResponse
            }
            return (data, http)
        } catch let error as HTTPTransportError {
            throw error
        } catch let error as URLError {
            throw error
        } catch {
            throw HTTPTransportError.transport(error.localizedDescription)
        }
    }
}
