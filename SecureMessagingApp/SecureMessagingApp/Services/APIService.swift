import Foundation

class APIService: ObservableObject {
    static let shared = APIService()
    
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
    
    func createMessage(_ encryptedMessage: EncryptedMessage, deviceId: String? = nil) async throws -> UUID {
        let request = CreateMessageRequest(
            ciphertext: encryptedMessage.ciphertext,
            nonce: encryptedMessage.nonce,
            tag: encryptedMessage.tag
        )
        
        var urlRequest = try createRequest(for: "", method: "POST")
        
        // Add device ID header if provided
        if let deviceId = deviceId {
            urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }
        
        switch httpResponse.statusCode {
        case 201:
            let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: data)
            return messageResponse.id
        case 413: // Payload Too Large
            let errorMessage = httpResponse.value(forHTTPHeaderField: "X-Error-Message") ?? "Message too large. Upgrade to premium for 10MB messages."
            throw NetworkError.messageTooLarge(errorMessage)
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
    
    // MARK: - Subscription Methods
    
    func verifySubscription(deviceId: String, receiptData: String) async {
        do {
            let requestBody = [
                "deviceId": deviceId,
                "receiptData": receiptData
            ]
            
            var urlRequest = try createRequest(for: "/api/subscription/verify", method: "POST")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (_, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                print("Subscription verified successfully")
            } else {
                print("Subscription verification failed")
            }
        } catch {
            print("Error verifying subscription: \(error)")
        }
    }
    
    func checkSubscriptionStatus(deviceId: String) async {
        do {
            let urlRequest = try createRequest(for: "/api/subscription/status/\(deviceId)")
            
            let (data, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Handle subscription status response
                print("Subscription status checked successfully")
            }
        } catch {
            print("Error checking subscription status: \(error)")
        }
    }
    
    func getSubscriptionLimits(deviceId: String) async -> SubscriptionLimits? {
        do {
            let urlRequest = try createRequest(for: "/api/subscription/limits/\(deviceId)")
            
            let (data, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(SubscriptionLimits.self, from: data)
            }
        } catch {
            print("Error fetching subscription limits: \(error)")
        }
        return nil
    }
}

// MARK: - Subscription Models

struct SubscriptionLimits: Codable {
    let maxMessageSizeBytes: Int64
    let maxMessageSizeMB: Double
    let canSendLargeMessage: Bool
    let isPremium: Bool
}
