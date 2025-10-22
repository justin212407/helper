import { defineConfig, devices } from "@playwright/test";

/**
 * @see https://playwright.dev/docs/test-configuration
 * Optimized for CI performance with sharding support and faster timeouts
 */
export default defineConfig({
  testDir: "./tests/e2e",
  /* Run tests in files in parallel - key for performance */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only - balance reliability vs speed */
  retries: process.env.CI ? 2 : 1,
  /* Use all available CPU cores in CI, auto-detect locally */
  workers: process.env.CI ? "100%" : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [
    ["html", { open: process.env.CI ? "never" : "on-failure" }],
    // Add line reporter for CI to show progress
    ...(process.env.CI ? [["line"] as ["line"]] : []),
  ],
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: process.env.PLAYWRIGHT_BASE_URL || "https://helperai.dev",

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: "on-first-retry",

    /* Take screenshot on failure - essential for debugging */
    screenshot: "only-on-failure",

    /* Record video on failure - reduces storage but captures issues */
    video: "retain-on-failure",

    /* Ignore HTTPS errors for local development */
    ignoreHTTPSErrors: true,

    /* Optimized timeouts - faster in CI for quicker feedback */
    actionTimeout: process.env.CI ? 10000 : 15000,
    navigationTimeout: process.env.CI ? 15000 : 45000,
  },
  /* Reduced timeout for CI - faster failure detection */
  timeout: process.env.CI ? 30000 : 60000,

  /* Configure projects for major browsers */
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,
      // Setup can be slower, especially in CI with fresh build
      timeout: 60000,
    },

    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
      dependencies: ["setup"],
      timeout: 60000,
    },
  ],

  /* Run your local server before starting the tests */
  // Make sure your port matches the one in your `.env.test.local` file
  webServer: {
    command: "scripts/e2e-test-server.sh",
    url: process.env.PLAYWRIGHT_BASE_URL || "http://localhost:3020",
    // Reuse existing server to avoid restart overhead
    reuseExistingServer: !process.env.CI,
    ignoreHTTPSErrors: true,
    // Optimized timeout with better health check in server script
    timeout: 120 * 1000, // 2 minutes for server startup
    // Add stdout/stderr to help debug server startup issues
    stdout: process.env.CI ? "pipe" : "ignore",
    stderr: process.env.CI ? "pipe" : "ignore",
  },
});
