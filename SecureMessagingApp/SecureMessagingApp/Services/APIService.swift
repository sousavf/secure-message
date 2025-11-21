import Foundation

class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL: String
    private let session: URLSession
    
    init(baseURL: String = "https://privileged.stratholme.eu") {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        self.session = URLSession(configuration: config)
    }

    private func addDeviceIdHeader(to request: inout URLRequest, deviceId: String?) {
        if let deviceId = deviceId {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
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

    // MARK: - Conversation Methods

    func createConversation(ttlHours: Int, deviceId: String) async throws -> Conversation {
        let request = CreateConversationRequest(ttlHours: ttlHours)

        var urlRequest = try createRequest(for: "/api/conversations", method: "POST")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            print("[DEBUG] createConversation - Request body encoded successfully")
            print("[DEBUG] createConversation - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")
            print("[DEBUG] createConversation - Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        } catch {
            print("[ERROR] createConversation - Failed to encode request: \(error)")
            throw error
        }

        let (data, response): (Data, URLResponse)
        do {
            print("[DEBUG] createConversation - Making HTTP request...")
            (data, response) = try await session.data(for: urlRequest)
            print("[DEBUG] createConversation - HTTP request completed successfully")
        } catch {
            print("[ERROR] createConversation - URLSession error: \(error)")
            print("[ERROR] createConversation - Error type: \(type(of: error))")
            if let urlError = error as? URLError {
                print("[ERROR] createConversation - URLError code: \(urlError.code)")
                print("[ERROR] createConversation - URLError localizedDescription: \(urlError.localizedDescription)")
            }
            throw error
        }

        print("[DEBUG] createConversation - Response received: \(response)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ERROR] createConversation - Invalid response type")
            throw NetworkError.unknownError
        }

        print("[DEBUG] createConversation - HTTP Status Code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] createConversation - Response body: \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let decoder = JSONDecoder()
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
            do {
                let conversation = try decoder.decode(Conversation.self, from: data)
                print("[DEBUG] createConversation - Successfully decoded conversation: \(conversation.id)")
                return conversation
            } catch {
                print("[ERROR] createConversation - Failed to decode response: \(error)")
                throw error
            }
        case 400...499:
            print("[ERROR] createConversation - Client error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            print("[ERROR] createConversation - Server error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            print("[ERROR] createConversation - Unknown status code: \(httpResponse.statusCode)")
            throw NetworkError.unknownError
        }
    }

    func listConversations(deviceId: String) async throws -> [Conversation] {
        var urlRequest = try createRequest(for: "/api/conversations")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        print("[DEBUG] listConversations - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")
        print("[DEBUG] listConversations - Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])")

        let (data, response): (Data, URLResponse)
        do {
            print("[DEBUG] listConversations - Making HTTP request...")
            (data, response) = try await session.data(for: urlRequest)
            print("[DEBUG] listConversations - HTTP request completed successfully")
        } catch {
            print("[ERROR] listConversations - URLSession error: \(error)")
            print("[ERROR] listConversations - Error type: \(type(of: error))")
            if let urlError = error as? URLError {
                print("[ERROR] listConversations - URLError code: \(urlError.code)")
                print("[ERROR] listConversations - URLError localizedDescription: \(urlError.localizedDescription)")
            }
            throw error
        }

        print("[DEBUG] listConversations - Response received: \(response)")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ERROR] listConversations - Invalid response type")
            throw NetworkError.unknownError
        }

        print("[DEBUG] listConversations - HTTP Status Code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] listConversations - Response body: \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
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
            // API returns list wrapped in response object or direct array
            do {
                if let conversations = try? decoder.decode([Conversation].self, from: data) {
                    print("[DEBUG] listConversations - Successfully decoded \(conversations.count) conversations")
                    return conversations
                }
                // If that fails, try to decode from wrapped response
                print("[DEBUG] listConversations - Could not decode array, returning empty list")
                return []
            } catch {
                print("[ERROR] listConversations - Failed to decode response: \(error)")
                throw error
            }
        case 400...499:
            print("[ERROR] listConversations - Client error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            print("[ERROR] listConversations - Server error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            print("[ERROR] listConversations - Unknown status code: \(httpResponse.statusCode)")
            throw NetworkError.unknownError
        }
    }

    func getConversation(id: UUID) async throws -> Conversation {
        let urlRequest = try createRequest(for: "/api/conversations/\(id.uuidString)")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
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
            return try decoder.decode(Conversation.self, from: data)
        case 404:
            throw NetworkError.conversationNotFound
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }

    func deleteConversation(id: UUID, deviceId: String) async throws {
        var urlRequest = try createRequest(for: "/api/conversations/\(id.uuidString)", method: "DELETE")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        switch httpResponse.statusCode {
        case 200, 204:
            return
        case 404:
            throw NetworkError.conversationNotFound
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }

    func leaveConversation(id: UUID, deviceId: String) async throws {
        var urlRequest = try createRequest(for: "/api/conversations/\(id.uuidString)/leave", method: "POST")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        switch httpResponse.statusCode {
        case 200, 204:
            return
        case 404:
            throw NetworkError.conversationNotFound
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }

    func generateConversationShareLink(conversationId: UUID, deviceId: String) async throws -> String {
        var urlRequest = try createRequest(for: "/api/conversations/\(conversationId.uuidString)/share", method: "POST")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        print("[DEBUG] generateConversationShareLink - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")
        print("[DEBUG] generateConversationShareLink - Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])")

        let (data, response) = try await session.data(for: urlRequest)

        print("[DEBUG] generateConversationShareLink - Response received: \(response)")

        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] generateConversationShareLink - Response body: \(responseString)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ERROR] generateConversationShareLink - Invalid response type")
            throw NetworkError.unknownError
        }

        print("[DEBUG] generateConversationShareLink - HTTP Status Code: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            // The backend returns a JSON object with "shareUrl", "conversationId", and "expiresAt"
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Try different field names the backend might use
                    if let shareUrl = dict["shareUrl"] as? String {
                        print("[DEBUG] generateConversationShareLink - Extracted shareUrl: \(shareUrl)")
                        return shareUrl
                    } else if let shareLink = dict["shareLink"] as? String {
                        print("[DEBUG] generateConversationShareLink - Extracted shareLink: \(shareLink)")
                        return shareLink
                    } else if let link = dict["link"] as? String {
                        print("[DEBUG] generateConversationShareLink - Extracted link: \(link)")
                        return link
                    } else {
                        print("[ERROR] generateConversationShareLink - No shareUrl/shareLink/link field found in response")
                        print("[DEBUG] generateConversationShareLink - Available keys: \(dict.keys.joined(separator: ", "))")
                        throw NetworkError.decodingError
                    }
                }

                // Fallback: try direct string
                if let directLink = String(data: data, encoding: .utf8), !directLink.isEmpty {
                    print("[DEBUG] generateConversationShareLink - Using raw response as link: \(directLink)")
                    return directLink
                }

                throw NetworkError.decodingError
            } catch {
                print("[ERROR] generateConversationShareLink - Failed to parse response: \(error)")
                throw NetworkError.decodingError
            }
        case 404:
            print("[ERROR] generateConversationShareLink - Conversation not found")
            throw NetworkError.conversationNotFound
        case 400...499:
            print("[ERROR] generateConversationShareLink - Client error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            print("[ERROR] generateConversationShareLink - Server error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            print("[ERROR] generateConversationShareLink - Unknown status code: \(httpResponse.statusCode)")
            throw NetworkError.unknownError
        }
    }

    func getConversationMessages(conversationId: UUID) async throws -> [ConversationMessage] {
        let urlRequest = try createRequest(for: "/api/conversations/\(conversationId.uuidString)/messages")

        print("[DEBUG] getConversationMessages - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        print("[DEBUG] getConversationMessages - HTTP Status Code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] getConversationMessages - Response body: \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
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
            do {
                let messages = try decoder.decode([ConversationMessage].self, from: data)
                print("[DEBUG] getConversationMessages - Successfully decoded \(messages.count) messages")
                return messages
            } catch {
                print("[ERROR] getConversationMessages - Failed to decode response: \(error)")
                throw error
            }
        case 404:
            throw NetworkError.conversationNotFound
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }

    func getConversationMessagesSince(conversationId: UUID, since: Date) async throws -> [ConversationMessage] {
        // Format the date as LocalDateTime string for the API (Spring Boot expects: yyyy-MM-dd'T'HH:mm:ss)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let sinceString = formatter.string(from: since)

        // URL encode the since parameter
        let encodedSince = sinceString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sinceString

        var urlRequest = try createRequest(for: "/api/conversations/\(conversationId.uuidString)/messages?since=\(encodedSince)")
        print("[DEBUG] getConversationMessagesSince - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        print("[DEBUG] getConversationMessagesSince - HTTP Status Code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] getConversationMessagesSince - Response body: \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
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
            do {
                let messages = try decoder.decode([ConversationMessage].self, from: data)
                print("[DEBUG] getConversationMessagesSince - Successfully decoded \(messages.count) new messages")
                return messages
            } catch {
                print("[ERROR] getConversationMessagesSince - Failed to decode response: \(error)")
                throw error
            }
        case 404:
            throw NetworkError.conversationNotFound
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }

    func addConversationMessage(conversationId: UUID, encryptedMessage: EncryptedMessage, deviceId: String? = nil) async throws -> ConversationMessage {
        print("[DEBUG] addConversationMessage - Creating request with encrypted message")
        let request = CreateMessageRequest(
            ciphertext: encryptedMessage.ciphertext,
            nonce: encryptedMessage.nonce,
            tag: encryptedMessage.tag
        )

        var urlRequest = try createRequest(for: "/api/conversations/\(conversationId.uuidString)/messages", method: "POST")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            print("[DEBUG] addConversationMessage - Request body encoded successfully")
            print("[DEBUG] addConversationMessage - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")
            print("[DEBUG] addConversationMessage - Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        } catch {
            print("[ERROR] addConversationMessage - Failed to encode request: \(error)")
            throw error
        }

        let (data, response): (Data, URLResponse)
        do {
            print("[DEBUG] addConversationMessage - Making HTTP request...")
            (data, response) = try await session.data(for: urlRequest)
            print("[DEBUG] addConversationMessage - HTTP request completed successfully")
        } catch {
            print("[ERROR] addConversationMessage - URLSession error: \(error)")
            if let urlError = error as? URLError {
                print("[ERROR] addConversationMessage - URLError code: \(urlError.code)")
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ERROR] addConversationMessage - Invalid response type")
            throw NetworkError.unknownError
        }

        print("[DEBUG] addConversationMessage - HTTP Status Code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] addConversationMessage - Response body: \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200, 201:
            do {
                let decoder = JSONDecoder()
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
                let message = try decoder.decode(ConversationMessage.self, from: data)
                print("[DEBUG] addConversationMessage - Successfully decoded message: \(message.id)")
                return message
            } catch {
                print("[ERROR] addConversationMessage - Failed to decode response: \(error)")
                throw error
            }
        case 404:
            print("[ERROR] addConversationMessage - Conversation not found")
            throw NetworkError.conversationNotFound
        case 413:
            print("[ERROR] addConversationMessage - Message too large")
            let errorMessage = httpResponse.value(forHTTPHeaderField: "X-Error-Message") ?? "Message too large."
            throw NetworkError.messageTooLarge(errorMessage)
        case 400...499:
            print("[ERROR] addConversationMessage - Client error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            print("[ERROR] addConversationMessage - Server error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            print("[ERROR] addConversationMessage - Unknown status code: \(httpResponse.statusCode)")
            throw NetworkError.unknownError
        }
    }

    func addConversationMessageWithType(conversationId: UUID, encryptedMessage: EncryptedMessage, deviceId: String? = nil, messageType: MessageType = .text) async throws -> ConversationMessage {
        print("[DEBUG] addConversationMessageWithType - Creating request with encrypted message, type: \(messageType)")
        var request = CreateMessageRequest(
            ciphertext: encryptedMessage.ciphertext,
            nonce: encryptedMessage.nonce,
            tag: encryptedMessage.tag
        )
        request.messageType = messageType

        var urlRequest = try createRequest(for: "/api/conversations/\(conversationId.uuidString)/messages", method: "POST")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            print("[DEBUG] addConversationMessageWithType - Request body encoded successfully")
            print("[DEBUG] addConversationMessageWithType - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")
        } catch {
            print("[ERROR] addConversationMessageWithType - Failed to encode request: \(error)")
            throw error
        }

        let (data, response): (Data, URLResponse)
        do {
            print("[DEBUG] addConversationMessageWithType - Making HTTP request...")
            (data, response) = try await session.data(for: urlRequest)
            print("[DEBUG] addConversationMessageWithType - HTTP request completed successfully")
        } catch {
            print("[ERROR] addConversationMessageWithType - URLSession error: \(error)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[ERROR] addConversationMessageWithType - Invalid response type")
            throw NetworkError.unknownError
        }

        print("[DEBUG] addConversationMessageWithType - HTTP Status Code: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200, 201:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

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
                let message = try decoder.decode(ConversationMessage.self, from: data)
                print("[DEBUG] addConversationMessageWithType - Successfully decoded message: \(message.id)")
                return message
            } catch {
                print("[ERROR] addConversationMessageWithType - Failed to decode response: \(error)")
                throw error
            }
        case 404:
            print("[ERROR] addConversationMessageWithType - Conversation not found")
            throw NetworkError.conversationNotFound
        case 413:
            print("[ERROR] addConversationMessageWithType - Message too large")
            let errorMessage = httpResponse.value(forHTTPHeaderField: "X-Error-Message") ?? "Message too large."
            throw NetworkError.messageTooLarge(errorMessage)
        case 400...499:
            print("[ERROR] addConversationMessageWithType - Client error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            print("[ERROR] addConversationMessageWithType - Server error: \(httpResponse.statusCode)")
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            print("[ERROR] addConversationMessageWithType - Unknown status code: \(httpResponse.statusCode)")
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

    func joinConversation(conversationId: UUID, deviceId: String) async throws {
        var urlRequest = try createRequest(for: "/api/conversations/\(conversationId.uuidString)/join", method: "POST")
        addDeviceIdHeader(to: &urlRequest, deviceId: deviceId)

        print("[DEBUG] joinConversation - Request URL: \(urlRequest.url?.absoluteString ?? "unknown")")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError
        }

        print("[DEBUG] joinConversation - HTTP Status Code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] joinConversation - Response body: \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200:
            print("[DEBUG] joinConversation - Successfully joined conversation: \(conversationId)")
        case 404:
            throw NetworkError.conversationNotFound
        case 409:
            // Conflict: Link already consumed or conversation not active
            let errorMessage = extractErrorMessage(from: data) ?? "This conversation link has already been used"
            print("[ERROR] joinConversation - Conflict: \(errorMessage)")
            throw NetworkError.linkAlreadyConsumed(errorMessage)
        case 400...499:
            throw NetworkError.serverError(httpResponse.statusCode)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.unknownError
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        // Try to parse JSON response and extract error message
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Try common error field names
            if let message = json["message"] as? String {
                return message
            }
            if let error = json["error"] as? String {
                return error
            }
            if let detail = json["detail"] as? String {
                return detail
            }
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
