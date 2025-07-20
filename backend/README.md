# Secure Messaging Backend

A zero-knowledge, one-time encrypted messaging system built with Spring Boot 3.x that provides secure message storage and retrieval with automatic expiration.

## Features

- **Zero-knowledge encryption**: Server never stores or processes encryption keys
- **One-time access**: Messages are consumed after single retrieval (HTTP 410 for subsequent attempts)
- **Automatic expiration**: 24-hour TTL with scheduled cleanup
- **Rate limiting**: 60 requests per minute per IP address
- **CORS support**: Configured for web and mobile clients
- **Metrics tracking**: Daily message creation and read statistics
- **Secure by design**: No sensitive data logging, proper error handling

## API Endpoints

### Message Operations

#### Create Message
```
POST /api/messages
Content-Type: application/json

{
  "ciphertext": "encrypted_message_content",
  "nonce": "cryptographic_nonce", 
  "tag": "optional_metadata"
}

Response: 201 Created
{
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### Retrieve Message (One-time only)
```
GET /api/messages/{id}

Response: 200 OK (first access)
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "ciphertext": "encrypted_message_content",
  "nonce": "cryptographic_nonce",
  "tag": "optional_metadata",
  "createdAt": "2024-01-01T12:00:00",
  "expiresAt": "2024-01-02T12:00:00",
  "readAt": "2024-01-01T15:30:00",
  "consumed": true
}

Response: 410 Gone (subsequent access or expired)
```

### Statistics

#### Get Today's Stats
```
GET /api/stats

Response: 200 OK
{
  "date": "2024-01-01",
  "messagesCreated": 150,
  "messagesRead": 142,
  "activeMessages": 8,
  "totalConsumedMessages": 1250
}
```

#### Get Stats for Specific Date
```
GET /api/stats/2024-01-01

Response: 200 OK
{
  "date": "2024-01-01", 
  "messagesCreated": 150,
  "messagesRead": 142,
  "activeMessages": 8,
  "totalConsumedMessages": 1250
}
```

### Health Check
```
GET /actuator/health

Response: 200 OK
{
  "status": "UP"
}
```

## Setup Instructions

### Prerequisites
- Java 17+
- Maven 3.6+
- PostgreSQL 12+

### Database Setup
1. Create PostgreSQL database:
```sql
CREATE DATABASE secure_messaging;
CREATE USER secure_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE secure_messaging TO secure_user;
```

2. Update `application.yml` with your database credentials:
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/secure_messaging
    username: your_username
    password: your_password
```

### Running the Application

1. Clone and build:
```bash
mvn clean install
```

2. Run the application:
```bash
mvn spring-boot:run
```

The server will start on `http://localhost:8080`

### Configuration

Key configuration properties in `application.yml`:

```yaml
app:
  message:
    default-ttl-hours: 24          # Message expiration time
    cleanup-interval-minutes: 60   # Cleanup job frequency
  security:
    cors:
      allowed-origins: ["http://localhost:3000"]
    rate-limit:
      requests-per-minute: 60      # Rate limiting threshold
```

### Environment Variables

- `DB_USERNAME`: Database username (default: secure_user)
- `DB_PASSWORD`: Database password (default: secure_password)

## Security Features

- **CORS Protection**: Configurable allowed origins
- **Rate Limiting**: IP-based request throttling
- **Input Validation**: Request payload validation
- **No Sensitive Logging**: Encryption keys and content never logged
- **Automatic Cleanup**: Expired and consumed messages removed
- **HTTPS Ready**: SSL configuration supported

## Architecture

- **Entity Layer**: JPA entities with proper indexing
- **Repository Layer**: Custom queries for performance
- **Service Layer**: Business logic and transaction management
- **Controller Layer**: REST API endpoints with validation
- **Configuration Layer**: Security, CORS, and rate limiting

## Development

### Running Tests
```bash
mvn test
```

### Building for Production
```bash
mvn clean package -Pprod
java -jar target/secure-messaging-1.0.0-SNAPSHOT.jar
```

## Integration with Swift App

This backend is designed to work with iOS/Swift applications through REST API calls. The Swift app should:

1. Encrypt messages client-side before sending to `POST /api/messages`
2. Store the returned message ID for sharing
3. Retrieve messages using `GET /api/messages/{id}`
4. Handle 410 Gone responses for consumed/expired messages
5. Decrypt messages client-side after retrieval

The zero-knowledge design ensures the server never has access to unencrypted message content or encryption keys.