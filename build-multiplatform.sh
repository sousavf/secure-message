#!/bin/bash

# Build Multi-Platform Safe Whisper Backend for Docker Hub
# Supports both ARM64 (Apple Silicon) and AMD64 (Intel/AMD) architectures
# Usage: ./build-multiplatform.sh [version] [dockerhub-username]

set -e  # Exit on any error

# Configuration
VERSION=${1:-"latest"}
DOCKERHUB_USERNAME=${2:-"sousavfl"}
IMAGE_NAME="safe-whisper-backend"
FULL_IMAGE_TAG="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${VERSION}"

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
print_status "This will create a PRIVATE repository on Docker Hub"

# Check if user is logged in to Docker Hub
if ! docker info | grep -q "Username"; then
    print_warning "You need to log in to Docker Hub first."
    echo "Please run: docker login"
    echo "Enter your Docker Hub credentials when prompted."
    docker login
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
BUILDER_NAME="safe-whisper-builder"
print_status "Setting up multi-platform builder..."

# Remove existing builder if it exists (ignore errors)
docker buildx rm ${BUILDER_NAME} >/dev/null 2>&1 || true

# Create new builder
docker buildx create --name ${BUILDER_NAME} --driver docker-container --use

# Bootstrap the builder
print_status "Bootstrapping builder (this may take a moment)..."
docker buildx inspect --bootstrap

print_status "Building and pushing multi-platform image..."
print_status "This may take several minutes as it builds for both architectures..."

# Build and push for multiple platforms
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag "${FULL_IMAGE_TAG}" \
    --tag "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest" \
    --push \
    .

print_success "Multi-platform image built and pushed successfully!"

# Clean up builder
print_status "Cleaning up builder..."
docker buildx rm ${BUILDER_NAME}

# Switch back to default builder
docker buildx use default

print_success "🎉 Multi-platform deployment completed successfully!"
echo ""
print_status "Your Docker image is now available for both architectures:"
print_status "  📦 ${FULL_IMAGE_TAG}"
print_status "  🏗️  Platforms: linux/amd64, linux/arm64"
echo ""
print_status "You can verify the platforms with:"
print_status "  docker buildx imagetools inspect ${FULL_IMAGE_TAG}"
echo ""
print_status "To make the repository private on Docker Hub:"
print_status "  1. Go to https://hub.docker.com/repository/docker/${DOCKERHUB_USERNAME}/${IMAGE_NAME}"
print_status "  2. Click 'Settings' tab"
print_status "  3. Change visibility to 'Private'"
echo ""
print_success "Your image now works on both Apple Silicon Macs and Intel/AMD servers! 🚀"