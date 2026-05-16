#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { performance } from "node:perf_hooks";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const options = parseArgs(process.argv.slice(2));
const urls = await loadUrls(options.urlsFile, options.urls);

if (!urls.length) {
  throw new Error("No benchmark URLs provided.");
}

let playwright;
try {
  playwright = await import("playwright");
} catch {
  console.error("Playwright is not installed. Run: make deps");
  process.exit(1);
}

const browserType = playwright[options.browser];
if (!browserType) {
  throw new Error(`Unsupported browser: ${options.browser}`);
}

const browserServer = await browserType.launchServer({ headless: true });
const browserRootPID = browserServer.process().pid;
const browser = await browserType.connect(browserServer.wsEndpoint());
const browserVersion = browser.version();
const results = [];
const generatedAt = new Date().toISOString();

try {
  for (const url of urls) {
    for (let iteration = 1; iteration <= options.iterations; iteration += 1) {
      results.push(await runBrowserLoad(browser, browserRootPID, url, options.browser, iteration));
    }
  }
} finally {
  await browser.close().catch(() => {});
  await browserServer.close().catch(() => {});
}

const report = {
  generatedAt,
  toolVersion: "0.1.0",
  browser: options.browser,
  browserVersion,
  iterations: options.iterations,
  results,
};

await fs.mkdir(path.dirname(options.output), { recursive: true });
await fs.writeFile(options.output, `${JSON.stringify(report, null, 2)}\n`);
await fs.writeFile(replaceExtension(options.output, ".md"), markdown(report));

console.log(`Wrote ${options.output}`);
console.log(`Wrote ${replaceExtension(options.output, ".md")}`);

async function runBrowserLoad(browser, browserRootPID, url, browserName, iteration) {
  const context = await browser.newContext({
    javaScriptEnabled: true,
    ignoreHTTPSErrors: false,
  });
  const page = await context.newPage();

  let requestCount = 0;
  let responseCount = 0;
  let responseHeaderBytes = 0;
  let failedRequests = 0;
  const thirdPartyHosts = new Set();

  const sourceHost = safeHostname(url);
  page.on("request", (request) => {
    requestCount += 1;
    const host = safeHostname(request.url());
    if (sourceHost && host && host !== sourceHost && !host.endsWith(`.${sourceHost}`)) {
      thirdPartyHosts.add(host);
    }
  });

  page.on("requestfailed", () => {
    failedRequests += 1;
  });

  page.on("response", async (response) => {
    responseCount += 1;
    const contentLength = Number.parseInt(response.headers()["content-length"] || "0", 10);
    if (Number.isFinite(contentLength) && contentLength > 0) {
      responseHeaderBytes += contentLength;
    }
  });

  const memoryBefore = await processTreeMemory(browserRootPID);
  const startedAt = performance.now();

  try {
    const response = await page.goto(url, {
      waitUntil: "load",
      timeout: options.timeout,
    });

    await page.waitForLoadState("networkidle", { timeout: options.networkIdleTimeout }).catch(() => {});

    const endedAt = performance.now();
    const memoryAfter = await processTreeMemory(browserRootPID);
    const metrics = await page.evaluate(() => {
      const navigation = performance.getEntriesByType("navigation")[0]?.toJSON?.() || {};
      const resources = performance.getEntriesByType("resource").map((entry) => ({
        name: entry.name,
        initiatorType: entry.initiatorType,
        transferSize: entry.transferSize || 0,
        encodedBodySize: entry.encodedBodySize || 0,
        decodedBodySize: entry.decodedBodySize || 0,
      }));
      const paints = Object.fromEntries(
        performance.getEntriesByType("paint").map((entry) => [entry.name, entry.startTime]),
      );

      return { navigation, resources, paints };
    });

    const resourceTransferBytes = metrics.resources.reduce(
      (total, resource) => total + Math.max(resource.transferSize || 0, resource.encodedBodySize || 0),
      0,
    );
    const navigationTransferBytes = Math.max(
      metrics.navigation.transferSize || 0,
      metrics.navigation.encodedBodySize || 0,
    );
    const scriptBytes = metrics.resources
      .filter((resource) => resource.initiatorType === "script" || /\.m?js($|\?)/i.test(resource.name))
      .reduce((total, resource) => total + Math.max(resource.transferSize || 0, resource.encodedBodySize || 0), 0);

    return {
      url,
      finalURL: page.url(),
      browser: browserName,
      iteration,
      success: true,
      statusCode: response?.status() || null,
      error: null,
      loadMilliseconds: endedAt - startedAt,
      domContentLoadedMilliseconds: metrics.navigation.domContentLoadedEventEnd || null,
      firstPaintMilliseconds: metrics.paints["first-paint"] || null,
      firstContentfulPaintMilliseconds: metrics.paints["first-contentful-paint"] || null,
      requestCount,
      responseCount,
      failedRequests,
      thirdPartyRequestHosts: [...thirdPartyHosts].sort(),
      thirdPartyRequestHostCount: thirdPartyHosts.size,
      transferBytes: Math.max(responseHeaderBytes, navigationTransferBytes + resourceTransferBytes),
      scriptBytes,
      resourceTimingBytes: navigationTransferBytes + resourceTransferBytes,
      responseHeaderBytes,
      browserRootPID,
      residentBytesBefore: memoryBefore.residentBytes,
      residentBytesAfter: memoryAfter.residentBytes,
      peakResidentBytes: maxFinite(memoryBefore.residentBytes, memoryAfter.residentBytes),
      processCountAfter: memoryAfter.processCount,
    };
  } catch (error) {
    const memoryAfter = await processTreeMemory(browserRootPID);

    return {
      url,
      finalURL: page.url(),
      browser: browserName,
      iteration,
      success: false,
      statusCode: null,
      error: error instanceof Error ? error.message : String(error),
      loadMilliseconds: performance.now() - startedAt,
      domContentLoadedMilliseconds: null,
      firstPaintMilliseconds: null,
      firstContentfulPaintMilliseconds: null,
      requestCount,
      responseCount,
      failedRequests,
      thirdPartyRequestHosts: [...thirdPartyHosts].sort(),
      thirdPartyRequestHostCount: thirdPartyHosts.size,
      transferBytes: responseHeaderBytes,
      scriptBytes: 0,
      resourceTimingBytes: 0,
      responseHeaderBytes,
      browserRootPID,
      residentBytesBefore: memoryBefore.residentBytes,
      residentBytesAfter: memoryAfter.residentBytes,
      peakResidentBytes: maxFinite(memoryBefore.residentBytes, memoryAfter.residentBytes),
      processCountAfter: memoryAfter.processCount,
    };
  } finally {
    await context.close();
  }
}

function markdown(report) {
  const lines = [];
  const successes = report.results.filter((result) => result.success);

  lines.push("# Browser Baseline Report");
  lines.push("");
  lines.push(`- Generated: ${report.generatedAt}`);
  lines.push(`- Browser: ${report.browser}`);
  lines.push(`- Browser version: ${report.browserVersion || "unknown"}`);
  lines.push(`- Iterations: ${report.iterations}`);
  lines.push(`- Successful runs: ${successes.length}/${report.results.length}`);
  lines.push("");
  lines.push("This is a full browser baseline with JavaScript enabled. Compare against Plain only when both reports were captured on the same machine and network.");
  lines.push("");

  if (successes.length) {
    lines.push("## Summary");
    lines.push("");
    lines.push(`- Median full load time: ${formatMilliseconds(median(successes.map((result) => result.loadMilliseconds)))}`);
    lines.push(`- Median transfer bytes: ${formatBytes(median(successes.map((result) => result.transferBytes)))}`);
    lines.push(`- Median request count: ${median(successes.map((result) => result.requestCount)).toFixed(1)}`);
    lines.push(`- Median script bytes: ${formatBytes(median(successes.map((result) => result.scriptBytes)))}`);
    lines.push(`- Median third-party host count: ${median(successes.map((result) => result.thirdPartyRequestHostCount)).toFixed(1)}`);
    const memoryValues = successes.map((result) => result.residentBytesAfter).filter(Number.isFinite);
    if (memoryValues.length) {
      lines.push(`- Median resident memory after load: ${formatBytes(median(memoryValues))}`);
    }
    lines.push("");
  }

  lines.push("## Runs");
  lines.push("");
  lines.push("| URL | Browser | Iteration | Success | Load | Requests | Transfer | Script Bytes | Resident Memory | Processes | Third-party Hosts |");
  lines.push("| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |");

  for (const result of report.results) {
    lines.push(
      `| ${escapePipe(result.url)} | ${result.browser} | ${result.iteration} | ${result.success ? "yes" : "no"} | ${formatMilliseconds(result.loadMilliseconds)} | ${result.requestCount} | ${formatBytes(result.transferBytes)} | ${formatBytes(result.scriptBytes)} | ${formatOptionalBytes(result.residentBytesAfter)} | ${result.processCountAfter ?? ""} | ${result.thirdPartyRequestHostCount} |`,
    );
  }

  return `${lines.join("\n")}\n`;
}

function parseArgs(args) {
  const options = {
    urlsFile: null,
    urls: [],
    iterations: 1,
    browser: "chromium",
    output: "benchmarks/results/browser-chromium.json",
    timeout: 30_000,
    networkIdleTimeout: 5_000,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--urls") options.urlsFile = next();
    else if (arg === "--url") options.urls.push(next());
    else if (arg === "--iterations") options.iterations = Number.parseInt(next(), 10);
    else if (arg === "--browser") {
      options.browser = next();
      options.output = `benchmarks/results/browser-${options.browser}.json`;
    } else if (arg === "--out") options.output = next();
    else if (arg === "--timeout") options.timeout = Number.parseInt(next(), 10);
    else if (arg === "--help" || arg === "-h") {
      console.log(`Usage: node benchmarks/browser-baseline.mjs --urls benchmarks/urls.txt --iterations 3 --browser chromium`);
      process.exit(0);
    } else if (arg.startsWith("-")) throw new Error(`Unknown option: ${arg}`);
    else options.urls.push(arg);
  }

  if (!Number.isInteger(options.iterations) || options.iterations < 1) {
    throw new Error("--iterations must be a positive integer");
  }

  return options;
}

async function loadUrls(file, fallback) {
  if (!file) return fallback;
  const contents = await fs.readFile(file, "utf8");
  return contents
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}

function replaceExtension(filePath, extension) {
  return path.join(path.dirname(filePath), `${path.basename(filePath, path.extname(filePath))}${extension}`);
}

function safeHostname(value) {
  try {
    return new URL(value).hostname.toLowerCase();
  } catch {
    return "";
  }
}

function median(values) {
  if (!values.length) return 0;
  const sorted = values.slice().sort((a, b) => a - b);
  const midpoint = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) return (sorted[midpoint - 1] + sorted[midpoint]) / 2;
  return sorted[midpoint];
}

async function processTreeMemory(rootPID) {
  if (!Number.isInteger(rootPID) || rootPID <= 0) {
    return { residentBytes: null, processCount: 0 };
  }

  try {
    const { stdout } = await execFileAsync("ps", ["-axo", "pid=,ppid=,rss="], {
      maxBuffer: 2 * 1024 * 1024,
    });
    const rows = stdout
      .trim()
      .split("\n")
      .map((line) => line.trim().split(/\s+/).map((value) => Number.parseInt(value, 10)))
      .filter(([pid, ppid, rssKB]) => Number.isInteger(pid) && Number.isInteger(ppid) && Number.isInteger(rssKB));

    const childrenByParent = new Map();
    const rssByPID = new Map();

    for (const [pid, ppid, rssKB] of rows) {
      rssByPID.set(pid, rssKB * 1024);
      const children = childrenByParent.get(ppid) || [];
      children.push(pid);
      childrenByParent.set(ppid, children);
    }

    const seen = new Set();
    const stack = [rootPID];
    let residentBytes = 0;

    while (stack.length) {
      const pid = stack.pop();
      if (seen.has(pid)) continue;
      seen.add(pid);
      residentBytes += rssByPID.get(pid) || 0;

      for (const childPID of childrenByParent.get(pid) || []) {
        stack.push(childPID);
      }
    }

    return {
      residentBytes: seen.size ? residentBytes : null,
      processCount: seen.size,
    };
  } catch {
    return { residentBytes: null, processCount: 0 };
  }
}

function maxFinite(...values) {
  const finiteValues = values.filter(Number.isFinite);
  if (!finiteValues.length) return null;
  return Math.max(...finiteValues);
}

function formatMilliseconds(value) {
  if (value >= 1000) return `${(value / 1000).toFixed(2)}s`;
  return `${Math.round(value)}ms`;
}

function formatBytes(value) {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(2)} MB`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)} KB`;
  return `${Math.round(value)} B`;
}

function formatOptionalBytes(value) {
  if (!Number.isFinite(value)) return "";
  return formatBytes(value);
}

function escapePipe(value) {
  return String(value).replaceAll("|", "\\|");
}
