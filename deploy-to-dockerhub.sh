#!/bin/bash

# Deploy Safe Whisper Backend to Private Docker Registry
# Usage: ./deploy-to-dockerhub.sh [version] [username]

set -e  # Exit on any error

# Configuration
VERSION=${1:-"latest"}
USERNAME=${2:-"admin"}
REGISTRY_URL="registry.vascosousa.com"
IMAGE_NAME="safe-whisper-backend"
FULL_IMAGE_TAG="${REGISTRY_URL}/${USERNAME}/${IMAGE_NAME}:${VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_status "Starting deployment process..."
print_status "Image: ${FULL_IMAGE_TAG}"
print_status "This will push to your private registry at ${REGISTRY_URL}"

# Check if user is logged in to the private registry
print_status "Checking registry authentication..."
if ! docker system info | grep -q "${REGISTRY_URL}" 2>/dev/null; then
    print_warning "You need to log in to your private registry first."
    echo "Please run: docker login ${REGISTRY_URL}"
    echo "Enter your registry credentials when prompted."
    docker login "${REGISTRY_URL}"
fi

# Navigate to the backend directory
SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}"

# Check if we need to navigate to the backend directory
if [ -d "backend" ] && [ -f "backend/pom.xml" ] && [ -f "backend/Dockerfile" ]; then
    print_status "Navigating to backend directory..."
    cd backend
elif [ ! -f "pom.xml" ] || [ ! -f "Dockerfile" ]; then
    print_error "Could not find Java project files (pom.xml) or Dockerfile"
    print_error "Make sure you're running this script from the correct directory"
    exit 1
fi

print_status "Building Docker image..."

# Build the Docker image
docker build -t "${FULL_IMAGE_TAG}" . --no-cache

print_success "Docker image built successfully!"

# Tag the image as latest if not already
if [ "${VERSION}" != "latest" ]; then
    print_status "Creating 'latest' tag..."
    docker tag "${FULL_IMAGE_TAG}" "${REGISTRY_URL}/${USERNAME}/${IMAGE_NAME}:latest"
fi

print_status "Pushing image to private registry (this may take a few minutes)..."

# Push to private registry
docker push "${FULL_IMAGE_TAG}"

# Push latest tag if created
if [ "${VERSION}" != "latest" ]; then
    docker push "${REGISTRY_URL}/${USERNAME}/${IMAGE_NAME}:latest"
fi

print_success "Image pushed to private registry successfully!"

# Create production docker-compose file
print_status "Creating production docker-compose file..."

cat > docker-compose.prod.yml << EOF
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: safe-whisper-db-prod
    environment:
      POSTGRES_DB: \${DB_NAME:-safe_whisper}
      POSTGRES_USER: \${DB_USER:-safe_user}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-\$(openssl rand -base64 32)}
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data
    networks:
      - safe-whisper-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USER:-safe_user} -d \${DB_NAME:-safe_whisper}"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: unless-stopped

  # Backend Application (from Docker Hub)
  backend:
    image: ${FULL_IMAGE_TAG}
    container_name: safe-whisper-backend-prod
    environment:
      # Database connection
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/\${DB_NAME:-safe_whisper}
      DB_USERNAME: \${DB_USER:-safe_user}
      DB_PASSWORD: \${DB_PASSWORD}
      
      # JPA/Hibernate settings
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
      SPRING_JPA_SHOW_SQL: false
      
      # Server settings
      SERVER_PORT: 8080
      
      # Security settings (enable SSL in production)
      SPRING_SECURITY_REQUIRE_SSL: \${REQUIRE_SSL:-false}
      
      # CORS settings (update for production)
      APP_SECURITY_CORS_ALLOWED_ORIGINS_0: \${CORS_ORIGIN_1:-http://localhost:3000}
      APP_SECURITY_CORS_ALLOWED_ORIGINS_1: \${CORS_ORIGIN_2:-https://localhost:3000}
      
      # Logging
      LOGGING_LEVEL_ROOT: WARN
      LOGGING_LEVEL_COM_EXAMPLE_SECUREMESSAGING: INFO
    ports:
      - "\${BACKEND_PORT:-8080}:8080"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - safe-whisper-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: unless-stopped

networks:
  safe-whisper-network:
    driver: bridge

volumes:
  postgres_prod_data:
    driver: local
EOF

# Create .env.example file for production
cat > .env.prod.example << EOF
# Production Environment Variables
# Copy this to .env.prod and update the values

# Database Configuration
DB_NAME=safe_whisper
DB_USER=safe_user
DB_PASSWORD=your_secure_database_password_here

# Server Configuration
BACKEND_PORT=8080
REQUIRE_SSL=true

# CORS Configuration (update with your actual domains)
CORS_ORIGIN_1=https://yourdomain.com
CORS_ORIGIN_2=https://www.yourdomain.com

# Optional: Custom image version
IMAGE_VERSION=latest
EOF

print_success "Production files created!"
print_status "Files created:"
print_status "  - docker-compose.prod.yml (production docker-compose)"
print_status "  - .env.prod.example (environment variables template)"

echo ""
print_success "🎉 Deployment completed successfully!"
echo ""
print_status "Your private Docker image is now available at:"
print_status "  📦 ${FULL_IMAGE_TAG}"
echo ""
print_status "To deploy on a production server:"
print_status "  1. Copy docker-compose.prod.yml and .env.prod.example to your server"
print_status "  2. Create .env.prod from .env.prod.example with your actual values"
print_status "  3. Run: docker login ${REGISTRY_URL} (on the production server)"
print_status "  4. Run: docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d"
echo ""
print_status "Your image is stored in your private registry at:"
print_status "  🏠 ${REGISTRY_URL}/${USERNAME}/${IMAGE_NAME}"
echo ""
print_warning "Remember to update your production environment variables!"

# Clean up local images if desired
read -p "Do you want to remove the local Docker images to save space? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleaning up local images..."
    docker rmi "${FULL_IMAGE_TAG}" || true
    if [ "${VERSION}" != "latest" ]; then
        docker rmi "${REGISTRY_URL}/${USERNAME}/${IMAGE_NAME}:latest" || true
    fi
    print_success "Local images cleaned up!"
fi

print_success "All done! 🚀"
