import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@playwright/test";

const CONFIG_DIR = path.dirname(fileURLToPath(import.meta.url));
const SYSTEM_CHROME_PATH =
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
const hasSystemChrome = fs.existsSync(SYSTEM_CHROME_PATH);

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 45_000,
  expect: {
    timeout: 8_000,
  },
  use: {
    baseURL: "http://127.0.0.1:5174",
    trace: "retain-on-failure",
    ...(hasSystemChrome
      ? {
          launchOptions: {
            executablePath: SYSTEM_CHROME_PATH,
          },
        }
      : {}),
  },
  webServer: {
    command: "npx vite --host 127.0.0.1 --port 5174 --strictPort",
    cwd: CONFIG_DIR,
    url: "http://127.0.0.1:5174",
    reuseExistingServer: false,
    timeout: 30_000,
  },
});
