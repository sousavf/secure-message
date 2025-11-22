# Build stage
FROM eclipse-temurin:17-jdk-jammy AS builder

WORKDIR /app

COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN chmod +x ./mvnw && ./mvnw dependency:go-offline -B

COPY src ./src
RUN ./mvnw clean package -DskipTests -X

# Extract JAR to exploded form for smaller final image
RUN mkdir -p /app/target/extracted && \
    cd /app/target/extracted && \
    jar -xf ../*.jar

# Final runtime image using minimal base
FROM eclipse-temurin:17-jre-jammy

RUN apt-get update && apt-get install -y curl --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
    groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy extracted JAR layers from builder
COPY --from=builder --chown=appuser:appuser /app/target/extracted/BOOT-INF/lib ./lib
COPY --from=builder --chown=appuser:appuser /app/target/extracted/BOOT-INF/classes ./
COPY --from=builder --chown=appuser:appuser /app/target/extracted/META-INF ./META-INF

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-cp", ".:./lib/*", "pt.sousavf.securemessaging.SecureMessagingApplication"]