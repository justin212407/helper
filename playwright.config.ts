import { defineConfig, devices } from "@playwright/test";

/**
 * Optimized Playwright configuration for faster CI runs
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: "./tests/e2e",

  /* Run tests in files in parallel */
  fullyParallel: true,

  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,

  /* OPTIMIZATION: Reduced retries (2 → 1) for faster feedback */
  retries: process.env.CI ? 1 : 1,

  /* OPTIMIZATION: Max out workers for parallel execution */
  workers: process.env.CI ? "100%" : undefined,

  /* OPTIMIZATION: Minimal reporters on CI */
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }], ["github"]] : [["html", { open: "on-failure" }]],

  /* Shared settings for all the projects below. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: process.env.PLAYWRIGHT_BASE_URL || "https://helperai.dev",

    /* OPTIMIZATION: Only trace on failure */
    trace: "retain-on-failure",

    /* OPTIMIZATION: Only screenshot on failure */
    screenshot: "only-on-failure",

    /* OPTIMIZATION: Disable video in CI (saves ~20% time per test) */
    video: process.env.CI ? "off" : "retain-on-failure",

    /* Ignore HTTPS errors for local development */
    ignoreHTTPSErrors: true,

    /* OPTIMIZATION: Reduced timeouts (15s → 10s) */
    actionTimeout: 10000,
    navigationTimeout: process.env.CI ? 10000 : 45000,
  },

  /* OPTIMIZATION: Reduced global timeout (30s → 20s) */
  timeout: process.env.CI ? 20000 : 60000,

  /* Expect timeout */
  expect: {
    timeout: 5000,
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,
      timeout: 30000, // Keep higher for setup
    },

    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        /* OPTIMIZATION: Browser launch flags for speed */
        launchOptions: {
          args: [
            "--disable-dev-shm-usage",
            "--disable-blink-features=AutomationControlled",
            "--disable-background-timer-throttling",
            "--disable-backgrounding-occluded-windows",
            "--disable-renderer-backgrounding",
            "--disable-gpu", // Disable GPU for CI speed
            "--no-sandbox",
            "--disable-setuid-sandbox",
            "--disable-web-security", // Faster for test environments
            "--disable-features=IsolateOrigins,site-per-process",
          ],
        },
      },
      dependencies: ["setup"],
      timeout: 30000, // Reduced from 60000
    },
  ],

  /* Run your local server before starting the tests */
  webServer: {
    command: "scripts/e2e-test-server.sh",
    url: process.env.PLAYWRIGHT_BASE_URL || "http://localhost:3020",
    reuseExistingServer: !process.env.CI,
    ignoreHTTPSErrors: true,
    timeout: 90 * 1000, // Reduced from 120s
  },
});
