#!/bin/bash

# Build Multi-Platform Safe Whisper Backend for Custom Registry
# Supports both ARM64 (Apple Silicon) and AMD64 (Intel/AMD) architectures
# Usage: ./build-multiplatform-custom-registry.sh [version] [registry-url] [image-path]
# Example: ./build-multiplatform-custom-registry.sh 2.0-build9 registry.vascosousa.com admin/safe-whisper-backend

set -e  # Exit on any error

# Configuration
VERSION=${1:-"latest"}
REGISTRY_URL=${2:-"registry.vascosousa.com"}
IMAGE_PATH=${3:-"admin/safe-whisper-backend"}
FULL_IMAGE_TAG="${REGISTRY_URL}/${IMAGE_PATH}:${VERSION}"

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

print_status "Starting multi-platform build process..."
print_status "Image: ${FULL_IMAGE_TAG}"
print_status "Platforms: linux/amd64, linux/arm64"

# Check if user is logged in to the registry
print_status "Checking registry authentication..."
if ! docker info | grep -q "Username"; then
    print_warning "You need to log in to your registry first."
    echo "Please run: docker login ${REGISTRY_URL}"
    echo "Enter your registry credentials when prompted."
    docker login ${REGISTRY_URL}
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

# Check if buildx is available
if ! docker buildx version >/dev/null 2>&1; then
    print_error "Docker Buildx is not available. Please update Docker Desktop to the latest version."
    exit 1
fi

# Create a new builder instance for multi-platform builds
BUILDER_NAME="safe-whisper-builder-${RANDOM}"
print_status "Setting up multi-platform builder..."

# Create new builder (don't remove, just create/use)
docker buildx create --name ${BUILDER_NAME} --driver docker-container --use || docker buildx use ${BUILDER_NAME}

# Bootstrap the builder
print_status "Bootstrapping builder (this may take a moment)..."
docker buildx inspect --bootstrap

print_status "Building and pushing multi-platform image..."
print_status "This may take several minutes as it builds for both architectures..."

# Build and push for multiple platforms
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag "${FULL_IMAGE_TAG}" \
    --push \
    .

if [ $? -eq 0 ]; then
    print_success "Multi-platform image built and pushed successfully!"
else
    print_error "Build or push failed. Please check the error above."
    exit 1
fi

# Clean up builder
print_status "Cleaning up builder..."
docker buildx rm ${BUILDER_NAME} || true

# Switch back to default builder
docker buildx use default || true

print_success "🎉 Multi-platform deployment completed successfully!"
echo ""
print_status "Your Docker image is now available for both architectures:"
print_status "  📦 ${FULL_IMAGE_TAG}"
print_status "  🏗️  Platforms: linux/amd64, linux/arm64"
echo ""
print_status "You can verify the platforms with:"
print_status "  docker buildx imagetools inspect ${FULL_IMAGE_TAG}"
echo ""
print_success "Your image now works on both Apple Silicon Macs and Intel/AMD servers! 🚀"
