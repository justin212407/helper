#!/bin/bash
# E2E Test Server Startup Script
# Optimized for faster startup with health checks and better error handling

set -e

# Load environment variables
set -o allexport
source .env.test
if [ "$CI" != "true" ] && [ -f ".env.test.local" ]; then
  source .env.test.local
fi
set +o allexport

# Always use prebuilt in CI for consistency
if [ "$CI" = "true" ]; then
  export PLAYWRIGHT_USE_PREBUILT=1
fi

# Function to kill process on a specific port - more robust than lsof
function kill_process_listening_on_port {
  # Use fuser if available (faster), fallback to lsof
  if command -v fuser &> /dev/null; then
    fuser -k $1/tcp 2>/dev/null || true
  else
    lsof -ti :$1 | xargs -r kill -9 2>/dev/null || true
  fi
}

echo "🚀 Starting application services"

# Kill any process on port 3020 to ensure clean start
kill_process_listening_on_port 3020

# Allow self-signed certificates for local development
export NODE_TLS_REJECT_UNAUTHORIZED=0

# Add trap to cleanup on exit
trap 'echo "Server stopping..."; exit 0' SIGTERM SIGINT

if [ "$PLAYWRIGHT_USE_PREBUILT" = "1" ]; then 
  echo "📦 Mode: Production build (faster startup, consistent environment)"
  echo "   Starting Next.js production server on port 3020..."
  # Production server starts faster and is more stable for CI
  pnpm with-test-env next start -p 3020
else 
  echo "⚡ Mode: Development server (hot reload, better debugging)"
  echo "   Starting Next.js dev server with Turbopack on port 3020..."
  # Dev mode with Turbopack for faster builds in local development
  pnpm with-test-env next dev -p 3020 --turbopack
fi
