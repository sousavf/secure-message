import Foundation

class APIService: ObservableObject {
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "https://whisper.stratholme.eu") {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        self.session = URLSession(configuration: config)
    }
    
    private func createRequest(for endpoint: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
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
        print("APIService: Making request to: \(urlRequest.url?.absoluteString ?? "unknown")")
        
        let (data, response) = try await session.data(for: urlRequest)
        print("APIService: Response received: \(response)")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("APIService: Invalid response type")
            throw NetworkError.unknownError
        }
        print("APIService: HTTP Status Code: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            // Debug: Print the raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString)")
            }
            
            do {
                let decoder = JSONDecoder()
                // Configure date decoding for Spring Boot LocalDateTime format
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Try multiple date formats that Spring Boot might use
                    let formatters = [
                        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                        "yyyy-MM-dd'T'HH:mm:ss.SSS",
                        "yyyy-MM-dd'T'HH:mm:ss",
                        "yyyy-MM-dd HH:mm:ss",
                        "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    ]
                    
                    for format in formatters {
                        let formatter = DateFormatter()
                        formatter.dateFormat = format
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                let messageResponse = try decoder.decode(MessageResponse.self, from: data)
                print("Successfully decoded MessageResponse: \(messageResponse)")
                
                guard let ciphertext = messageResponse.ciphertext,
                      let nonce = messageResponse.nonce,
                      let tag = messageResponse.tag else {
                    throw NetworkError.decodingError
                }
                
                return EncryptedMessage(ciphertext: ciphertext, nonce: nonce, tag: tag)
            } catch {
                print("Decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    print("DecodingError details: \(decodingError)")
                }
                throw NetworkError.decodingError
            }
            
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
