#!/bin/bash
# Test script for Docker setup

set -e

echo "🐳 Testing 05-proc Docker setup..."
echo ""

# Check Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    echo "Please install Docker Desktop or Docker Engine"
    exit 1
fi

echo "✓ Docker found: $(docker --version)"

# Build the image
echo ""
echo "📦 Building Docker image..."
docker compose build

# Start the container
echo ""
echo "🚀 Starting container..."
docker compose up -d

# Wait a moment for container to be ready
sleep 2

# Check container is running
echo ""
echo "🔍 Checking container status..."
docker compose ps

# Test the ps script
echo ""
echo "🧪 Testing asdatarius_ps_ax.sh..."
docker compose exec -T proc bash -c "./asdatarius_ps_ax.sh" | head -20

# Test the lsof script
echo ""
echo "🧪 Testing asdatarius_lsof.sh..."
docker compose exec -T proc bash -c "./asdatarius_lsof.sh" | head -20

# Cleanup
echo ""
echo "🧹 Cleaning up..."
docker compose down

echo ""
echo "✅ All tests passed!"
echo ""
echo "To use interactively:"
echo "  docker compose up -d"
echo "  docker compose exec proc bash"
echo "  ./asdatarius_ps_ax.sh"
echo "  ./asdatarius_lsof.sh"
echo "  exit"
echo "  docker compose down"
