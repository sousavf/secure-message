import Foundation

class APIService: ObservableObject {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "http://localhost:8080") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        self.session = URLSession(configuration: config)
    }
    
    private func createRequest(for endpoint: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/messages\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    func createMessage(_ encryptedMessage: EncryptedMessage) async throws -> UUID {
        let request = CreateMessageRequest(
            ciphertext: encryptedMessage.ciphertext,
            nonce: encryptedMessage.nonce,
            tag: encryptedMessage.tag
        )
        
        var urlRequest = try createRequest(for: "", method: "POST")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }
        
        switch httpResponse.statusCode {
        case 201:
            let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: data)
            return messageResponse.id
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }
    
    func retrieveMessage(id: UUID) async throws -> EncryptedMessage {
        let urlRequest = try createRequest(for: "/\(id.uuidString)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }
        
        switch httpResponse.statusCode {
        case 200:
            let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: data)
            
            guard let ciphertext = messageResponse.ciphertext,
                  let nonce = messageResponse.nonce,
                  let tag = messageResponse.tag else {
                throw NetworkError.decodingError
            }
            
            return EncryptedMessage(ciphertext: ciphertext, nonce: nonce, tag: tag)
            
        case 410:
            throw NetworkError.messageConsumed
        case 404:
            throw NetworkError.messageExpired
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }
}