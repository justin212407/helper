#!/bin/bash

# Helper - E2E Testing Environment Setup Script
# Optimized for CI performance while maintaining local dev experience
# This script sets up everything needed for E2E testing including Supabase, database migrations, and Playwright

set -e

echo "🎭 Setting up E2E Testing Environment for Helper"
echo "================================================"

# Validate we're in the correct directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the root of the Helper project"
    exit 1
fi

echo "Current directory: $(pwd)"

# Check for required .env.test file
if [ ! -f ".env.test" ]; then
    echo "⚠️ .env.test not found. Please create it from .env.local.sample."
    echo "📁 Files in current directory:"
    ls -la .env* 2>/dev/null || echo "No .env files found"
    exit 1
fi

echo "✅ .env.test found"

# Create .env.test.local for local development (not needed in CI)
if [ "$CI" != "true" ]; then
    if [ ! -f ".env.test.local" ]; then
        echo "📝 Creating .env.test.local from .env.test..."
        cp .env.test .env.test.local
        echo "✅ Created .env.test.local - you can customize it with local values if needed"
    else
        echo "✅ .env.test.local already exists"
    fi
fi

# Load environment variables
echo "🔧 Loading environment variables..."
set -o allexport
source .env.test
if [ "$CI" != "true" ] && [ -f ".env.test.local" ]; then
  source .env.test.local
fi
set +o allexport

CI="${CI:-false}"
echo "CI is set to $CI"

# Clean up any existing Supabase services
echo "🛑 Ensuring no Supabase services are running..."
pnpm run with-test-env pnpm supabase stop --no-backup 2>/dev/null || true

# Check for and clean up existing containers
echo "🔍 Checking for existing Supabase containers for project ${SUPABASE_PROJECT_ID}..."
EXISTING_CONTAINERS=$(docker ps -a -q --filter "name=${SUPABASE_PROJECT_ID}" 2>/dev/null || true)
if [ ! -z "$EXISTING_CONTAINERS" ]; then
    echo "🧹 Found existing Supabase containers for project ${SUPABASE_PROJECT_ID}, cleaning up..."
    echo "🛑 Stopping containers..."
    docker stop $EXISTING_CONTAINERS 2>/dev/null || true
    echo "🗑️ Removing containers..."
    docker rm $EXISTING_CONTAINERS 2>/dev/null || true
    echo "✅ Existing containers cleaned up"
else
    echo "✅ No existing Supabase containers found for project ${SUPABASE_PROJECT_ID}"
fi

# Start Supabase services with appropriate config
echo "🎉 Starting Supabase services..."
if [ "$CI" = "true" ]; then
  echo "🪄 Using slim Supabase config for CI"
  export SUPABASE_CONFIG_PATH="./supabase/config.ci.toml"
fi
pnpm run with-test-env pnpm supabase start

# Brief wait for services to initialize
echo "⏳ Waiting for services to initialize..."
sleep 5

# OPTIMIZATION: Run database operations in PARALLEL (saves ~30-60 seconds)
echo "🔄 Resetting database and applying migrations in parallel..."
(
  echo "  └─ Resetting database..."
  pnpm run with-test-env pnpm supabase db reset
  echo "  └─ ✅ Database reset complete"
) &
DB_RESET_PID=$!

(
  echo "  └─ Applying Drizzle migrations..."
  pnpm run with-test-env drizzle-kit migrate --config ./db/drizzle.config.ts
  echo "  └─ ✅ Migrations applied"
) &
MIGRATE_PID=$!

# Wait for both database operations to complete
wait $DB_RESET_PID
DB_RESET_EXIT=$?
wait $MIGRATE_PID
MIGRATE_EXIT=$?

# Check if either operation failed
if [ $DB_RESET_EXIT -ne 0 ] || [ $MIGRATE_EXIT -ne 0 ]; then
    echo "❌ Database setup failed"
    exit 1
fi

echo "✅ Database reset and migrations complete"

# OPTIMIZATION: Skip package builds in CI (already handled by workflow)
if [ "$CI" != "true" ]; then
  echo "📦 Building packages with concurrency=4..."
  pnpm -r --workspace-concurrency=4 --if-present run build
else
  echo "⏭️  Skipping package builds in CI (already built in workflow)"
fi

# OPTIMIZATION: Skip database seeding in CI (saves ~1-2 minutes)
# Tests should use factories or setup their own data for better isolation
if [ "$CI" != "true" ]; then
  echo "🌱 Seeding the database (local dev only)..."
  pnpm run with-test-env pnpm tsx --conditions=react-server ./db/seeds/seedDatabase.ts
else
  echo "⏭️  Skipping database seeding in CI (tests use factories for better isolation)"
fi

# OPTIMIZATION: Skip installations in CI (handled by workflow)
if [ "$CI" != "true" ]; then
  echo "📦 Installing Playwright and dependencies..."
  pnpm install

  echo "🎭 Installing Playwright browsers..."
  export PLAYWRIGHT_BROWSERS_PATH=~/.cache/ms-playwright
  pnpm run with-test-env playwright install --with-deps chromium
else
  echo "⏭️  Skipping pnpm install and Playwright browser install in CI (handled by workflow)"
fi

echo ""
echo "🎉 E2E Testing Environment Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "   (optional) set PLAYWRIGHT_USE_PREBUILT=1 in .env.test.local to run e2e on production build"
echo ""
echo "   1. Run your tests using:"
echo "      ./scripts/e2e.sh                   # Run all tests"
echo "      ./scripts/e2e.sh playwright test tests/e2e/widget/widget-screenshot.spec.ts  # Specific test"
echo ""
echo "   2. Or use pnpm commands directly:"
echo "      pnpm test:e2e                      # Run all tests"
echo "      pnpm test:e2e:debug                # Debug mode"
echo "      pnpm test:e2e:headed               # Headed mode"
echo ""
echo "📖 Documentation:"
echo "   • Test documentation: tests/e2e/README.md"
echo "   • Playwright docs: https://playwright.dev/"
echo ""
echo "🐛 Troubleshooting:"
echo "   • Verify Supabase services: pnpm with-test-env pnpm supabase status"
echo "   • Check test credentials in .env.test.local"
echo "   • Ensure Docker is running for Supabase"
echo "   • Check logs: docker logs supabase_db_${SUPABASE_PROJECT_ID}"
echo ""
echo "Happy testing! 🚀"