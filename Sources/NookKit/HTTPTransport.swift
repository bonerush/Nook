import Foundation

public enum HTTPTransportError: Error, Equatable {
    case invalidResponse
    case transport(String)
}

public protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public final class URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
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
