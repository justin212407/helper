#!/bin/bash
# This script runs the E2E tests using Playwright
# Optimized for CI with faster validation and better error messages

set -e

# Check if .env.test exists before attempting to source it
if [ ! -f ".env.test" ]; then
    echo "❌ .env.test not found. Please run ./scripts/setup-e2e-tests.sh first."
    exit 1
fi

# Load environment variables to get SUPABASE_PROJECT_ID and other config
set -o allexport
source .env.test
if [ "$CI" != "true" ] && [ -f ".env.test.local" ]; then
  source .env.test.local
fi
set +o allexport

# Always use prebuilt in CI for consistency and speed
if [ "$CI" = "true" ]; then
  export PLAYWRIGHT_USE_PREBUILT=1
fi

echo "🔍 Checking Supabase test environment setup..."

# Validate SUPABASE_PROJECT_ID is set
if [ -z "$SUPABASE_PROJECT_ID" ]; then
    echo "❌ SUPABASE_PROJECT_ID not found in environment variables."
    echo "   Please run ./scripts/setup-e2e-tests.sh first."
    exit 1
fi

# Quick check if Supabase containers are running - only check one critical service
RUNNING_CONTAINERS=$(docker ps -q --filter "name=${SUPABASE_PROJECT_ID}-db" 2>/dev/null || true)
if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "❌ Supabase test containers are not running for project: ${SUPABASE_PROJECT_ID}"
    echo "   Please run ./scripts/setup-e2e-tests.sh or pnpm test:e2e:setup first to start the test environment."
    exit 1
fi

echo "✅ Found running Supabase containers for project: ${SUPABASE_PROJECT_ID}"
echo "✅ Test environment is ready."
echo "===================="

# Parse command line arguments
PLAYWRIGHT_COMMAND=""

# Collect all arguments to pass to playwright
while [[ $# -gt 0 ]]; do
    PLAYWRIGHT_COMMAND="$PLAYWRIGHT_COMMAND $1"
    shift
done

# If no arguments provided, default to basic playwright test
if [ -z "$PLAYWRIGHT_COMMAND" ]; then
    PLAYWRIGHT_COMMAND="pnpm playwright test"
fi

# Ensure direct 'playwright' invocations go through the pnpm script wrapper
# which sets necessary Node conditions (e.g., react-server)
if [[ "$PLAYWRIGHT_COMMAND" =~ ^[[:space:]]*playwright[[:space:]] ]]; then
    PLAYWRIGHT_COMMAND="pnpm $PLAYWRIGHT_COMMAND"
fi

# Add sharding support for CI - splits tests across parallel jobs
if [ "$CI" = "true" ] && [ ! -z "$PLAYWRIGHT_SHARD" ] && [ ! -z "$PLAYWRIGHT_TOTAL_SHARDS" ]; then
    PLAYWRIGHT_COMMAND="$PLAYWRIGHT_COMMAND --shard=$PLAYWRIGHT_SHARD/$PLAYWRIGHT_TOTAL_SHARDS"
    echo "🚀 Starting E2E test run (Shard $PLAYWRIGHT_SHARD/$PLAYWRIGHT_TOTAL_SHARDS)..."
else
    echo "🚀 Starting E2E test run..."
fi

if [ "$PLAYWRIGHT_USE_PREBUILT" = "1" ]; then 
  echo "📦 Mode: Production build (pnpm with-test-env next start -p 3020)"
else 
  echo "⚡ Mode: Development server (pnpm with-test-env next dev -p 3020 --turbopack)"
fi

# Run the e2e tests
echo "🧪 Running Playwright e2e tests..."
pnpm run with-test-env $PLAYWRIGHT_COMMAND

echo "✅ All tests completed successfully!"
echo "🎉 Test run complete!"