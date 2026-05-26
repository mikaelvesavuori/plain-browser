#!/usr/bin/env node

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { evaluatePowerReport, percentageReduction } from "./power-policy.mjs";
import { parsePowermetricsText, summarizePowerSamples } from "./powermetrics-parser.mjs";

const POWERMETRICS_CAVEAT = "powermetrics average power values are estimated and may be inaccurate; use them to help optimize app energy efficiency, not for broad cross-device comparisons.";

const options = parseArgs(process.argv.slice(2));

if (typeof process.getuid === "function" && process.getuid() !== 0) {
  console.error("Power measurement requires macOS powermetrics, which must be run as superuser.");
  console.error("Run: sudo make bench-power-measure");
  console.error("Then run: make bench-power-postprocess");
  process.exit(1);
}

await fs.mkdir(path.dirname(options.output), { recursive: true });
await fs.mkdir(options.rawDir, { recursive: true });

const urls = await loadUrls(options.urls);
if (!urls.length) throw new Error("No benchmark URLs provided.");

const browserVersion = await getBrowserVersion(options.browser);
const environment = collectEnvironment({ browserName: options.browser, browserVersion });
const corpus = {
  uniqueUrlCount: urls.length,
  iterations: options.iterations,
  urls,
  sha256: sha256(urls.join("\n")),
};

console.log("Building PlainBench release binary...");
await runCommand("swift", ["build", "-c", "release", "--product", "PlainBench"], { cwd: process.cwd() });
const releaseBinPath = execFileSync("swift", ["build", "-c", "release", "--show-bin-path"], {
  encoding: "utf8",
}).trim();
const plainBench = path.join(releaseBinPath, "PlainBench");

console.log("Measuring idle baseline...");
const idle = await measureIdle();

console.log("Measuring Plain workload...");
const plain = await measureWorkload("plain", plainBench, [
  "--urls",
  options.urls,
  "--iterations",
  String(options.iterations),
  "--mode",
  "both",
  "--out",
  options.plainOutput,
], idle.averageEstimatedSocPowerMilliwatts);

console.log("Measuring Chromium workload...");
const browser = await measureWorkload("browser", "node", [
  "benchmarks/browser-baseline.mjs",
  "--urls",
  options.urls,
  "--iterations",
  String(options.iterations),
  "--browser",
  options.browser,
  "--out",
  options.browserOutput,
], idle.averageEstimatedSocPowerMilliwatts);

const report = {
  generatedAt: new Date().toISOString(),
  toolVersion: "0.1.0",
  method: {
    tool: "powermetrics",
    samplers: options.samplers,
    sampleIntervalMilliseconds: options.sampleIntervalMilliseconds,
    idleSamples: options.idleSamples,
    toolCaveat: POWERMETRICS_CAVEAT,
    workloadNote: "Measures benchmark harness workloads, not only the GUI app process. Compare only on the same machine, power mode, network, corpus, and date.",
  },
  environment,
  corpus,
  measurements: {
    idle,
    plain,
    browser,
  },
  comparison: {
    plainIdleAdjustedJoules: plain.idleAdjustedEstimatedSocEnergyJoules,
    browserIdleAdjustedJoules: browser.idleAdjustedEstimatedSocEnergyJoules,
    idleAdjustedEnergyReductionPercent: percentageReduction(
      plain.idleAdjustedEstimatedSocEnergyJoules,
      browser.idleAdjustedEstimatedSocEnergyJoules,
    ),
    plainGrossJoules: plain.grossEstimatedSocEnergyJoules,
    browserGrossJoules: browser.grossEstimatedSocEnergyJoules,
    grossEnergyReductionPercent: percentageReduction(
      plain.grossEstimatedSocEnergyJoules,
      browser.grossEstimatedSocEnergyJoules,
    ),
  },
};

report.validation = evaluatePowerReport(report, options.policy);

await fs.writeFile(options.output, `${JSON.stringify(report, null, 2)}\n`);
await fs.writeFile(replaceExtension(options.output, ".md"), markdown(report));

console.log(`Wrote ${options.output}`);
console.log(`Wrote ${replaceExtension(options.output, ".md")}`);

if (!report.validation.passed) process.exit(1);

async function measureIdle() {
  const outputPath = path.join(options.rawDir, "powermetrics-idle.txt");
  await runCommand("powermetrics", [
    "--samplers",
    options.samplers,
    "--sample-rate",
    String(options.sampleIntervalMilliseconds),
    "--sample-count",
    String(options.idleSamples),
    "--output-file",
    outputPath,
  ]);

  const text = await fs.readFile(outputPath, "utf8");
  const samples = parsePowermetricsText(text);
  return {
    ...summarizePowerSamples(samples, options.idleSamples * options.sampleIntervalMilliseconds, 0),
    rawOutput: outputPath,
  };
}

async function measureWorkload(label, command, args, idleAverageMilliwatts) {
  const outputPath = path.join(options.rawDir, `powermetrics-${label}.txt`);
  const power = spawn("powermetrics", [
    "--samplers",
    options.samplers,
    "--sample-rate",
    String(options.sampleIntervalMilliseconds),
    "--sample-count",
    "-1",
    "--buffer-size",
    "1",
    "--output-file",
    outputPath,
  ], { stdio: "ignore" });

  await delay(options.sampleIntervalMilliseconds);

  const startedAt = Date.now();
  try {
    await runCommand(command, args, { cwd: process.cwd() });
  } finally {
    power.kill("SIGTERM");
    await waitForExit(power).catch(() => {});
  }
  const durationMilliseconds = Date.now() - startedAt;

  const text = await fs.readFile(outputPath, "utf8");
  const samples = parsePowermetricsText(text);
  return {
    ...summarizePowerSamples(samples, durationMilliseconds, idleAverageMilliwatts),
    rawOutput: outputPath,
    command: [command, ...args].join(" "),
  };
}

async function runCommand(command, args, options = {}) {
  const child = spawn(command, args, {
    cwd: options.cwd,
    stdio: "inherit",
  });
  await waitForExit(child);
}

function waitForExit(child) {
  return new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (code === 0 || signal === "SIGTERM") resolve();
      else reject(new Error(`Process exited with ${code ?? signal}`));
    });
  });
}

async function getBrowserVersion(browserName) {
  const script = `const p=await import('playwright'); const b=await p.${browserName}.launch({headless:true}); console.log(b.version()); await b.close();`;
  const output = execFileSync("node", ["--input-type=module", "-e", script], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  });
  return output.trim();
}

function collectEnvironment({ browserName, browserVersion }) {
  return {
    capturedAt: new Date().toISOString(),
    host: {
      os: safeExec("sw_vers", ["-productName"]) || os.type(),
      osVersion: safeExec("sw_vers", ["-productVersion"]) || os.release(),
      osBuild: safeExec("sw_vers", ["-buildVersion"]) || null,
      platform: os.platform(),
      arch: os.arch(),
      machineModel: safeExec("sysctl", ["-n", "hw.model"]) || null,
      cpuModel: os.cpus()[0]?.model || safeExec("sysctl", ["-n", "machdep.cpu.brand_string"]) || null,
      cpuCount: os.cpus().length,
      totalMemoryBytes: os.totalmem(),
    },
    tooling: {
      nodeVersion: process.version,
      swiftVersion: safeExec("swift", ["--version"]) || null,
      browserName,
      browserVersion,
    },
    network: {
      activeInterfaceNames: activeNetworkInterfaceNames(),
    },
    power: {
      batteryStatus: safeExec("pmset", ["-g", "batt"]) || null,
    },
  };
}

function markdown(report) {
  const lines = [];
  lines.push("# Plain Power Measurement");
  lines.push("");
  lines.push(`- Generated: ${report.generatedAt}`);
  lines.push(`- Claim gate: ${report.validation.passed ? "passed" : "not ready"}`);
  lines.push(`- Tool: ${report.method.tool}`);
  lines.push(`- Caveat: ${report.method.toolCaveat}`);
  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push("| Metric | Plain | Chromium | Reduction |");
  lines.push("| --- | ---: | ---: | ---: |");
  lines.push(`| Idle-adjusted estimated SoC energy | ${formatJoules(report.comparison.plainIdleAdjustedJoules)} | ${formatJoules(report.comparison.browserIdleAdjustedJoules)} | ${formatPercent(report.comparison.idleAdjustedEnergyReductionPercent)} |`);
  lines.push(`| Gross estimated SoC energy | ${formatJoules(report.comparison.plainGrossJoules)} | ${formatJoules(report.comparison.browserGrossJoules)} | ${formatPercent(report.comparison.grossEnergyReductionPercent)} |`);
  lines.push(`| Average estimated SoC power | ${formatMilliwatts(report.measurements.plain.averageEstimatedSocPowerMilliwatts)} | ${formatMilliwatts(report.measurements.browser.averageEstimatedSocPowerMilliwatts)} | - |`);
  lines.push(`| Duration | ${formatMilliseconds(report.measurements.plain.durationMilliseconds)} | ${formatMilliseconds(report.measurements.browser.durationMilliseconds)} | - |`);
  lines.push(`| Samples | ${report.measurements.plain.sampleCount} | ${report.measurements.browser.sampleCount} | - |`);
  lines.push("");
  lines.push("## Evidence");
  lines.push("");
  lines.push(`- Corpus: ${report.corpus.uniqueUrlCount} URL(s), ${report.corpus.iterations} iteration(s), SHA-256 ${report.corpus.sha256}`);
  lines.push(`- Idle baseline: ${report.measurements.idle.sampleCount} samples, ${formatMilliwatts(report.measurements.idle.averageEstimatedSocPowerMilliwatts)}`);
  lines.push(`- Browser: ${report.environment.tooling.browserName} ${report.environment.tooling.browserVersion}`);
  lines.push(`- Host: ${report.environment.host.os} ${report.environment.host.osVersion}, ${report.environment.host.arch}, ${report.environment.host.machineModel}`);
  lines.push(`- Power: ${firstLine(report.environment.power.batteryStatus) || "not captured"}`);
  lines.push("");
  lines.push("## Claim Readiness");
  lines.push("");
  if (report.validation.approvedClaims.length) {
    lines.push("Approved:");
    for (const claim of report.validation.approvedClaims) lines.push(`- ${claim.statement}`);
    lines.push("");
  }
  if (report.validation.rejectedClaims.length || report.validation.errors.length) {
    lines.push("Not ready:");
    for (const error of report.validation.errors) lines.push(`- ${error}`);
    for (const claim of report.validation.rejectedClaims) {
      lines.push(`- ${claim.statement}`);
      for (const reason of claim.reasons) lines.push(`  - ${reason}`);
    }
    lines.push("");
  }
  lines.push('Do not convert this into an unqualified "green" or "eco-friendly" claim. Use only the qualified estimated-energy language above.');
  return `${lines.join("\n")}\n`;
}

async function loadUrls(file) {
  const contents = await fs.readFile(file, "utf8");
  return contents
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}

function parseArgs(args) {
  const options = {
    urls: "benchmarks/urls-marketing.txt",
    iterations: 3,
    browser: "chromium",
    output: "benchmarks/results/power-marketing.json",
    plainOutput: "benchmarks/results/plain-power.json",
    browserOutput: "benchmarks/results/browser-power.json",
    rawDir: "benchmarks/results/power-raw",
    sampleIntervalMilliseconds: 1000,
    idleSamples: 15,
    samplers: "cpu_power,gpu_power,ane_power",
    policy: "marketing",
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--urls") options.urls = next();
    else if (arg === "--iterations") options.iterations = Number.parseInt(next(), 10);
    else if (arg === "--browser") options.browser = next();
    else if (arg === "--out") options.output = next();
    else if (arg === "--plain-out") options.plainOutput = next();
    else if (arg === "--browser-out") options.browserOutput = next();
    else if (arg === "--raw-dir") options.rawDir = next();
    else if (arg === "--sample-interval") options.sampleIntervalMilliseconds = Number.parseInt(next(), 10);
    else if (arg === "--idle-samples") options.idleSamples = Number.parseInt(next(), 10);
    else if (arg === "--policy") options.policy = next();
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: sudo node benchmarks/power-runner.mjs --urls benchmarks/urls-marketing.txt --iterations 3 --out benchmarks/results/power-marketing.json");
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

function safeExec(command, args) {
  try {
    return execFileSync(command, args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "";
  }
}

function activeNetworkInterfaceNames() {
  const interfaces = os.networkInterfaces();
  return Object.entries(interfaces)
    .filter(([name, addresses]) => !/^(awdl|llw|utun|lo)/.test(name) && addresses?.some((address) => !address.internal))
    .map(([name]) => name)
    .sort();
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function replaceExtension(filePath, extension) {
  return path.join(path.dirname(filePath), `${path.basename(filePath, path.extname(filePath))}${extension}`);
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function formatPercent(value) {
  return `${Math.round(value)}%`;
}

function formatJoules(value) {
  return `${value.toFixed(2)} J`;
}

function formatMilliwatts(value) {
  if (value >= 1000) return `${(value / 1000).toFixed(2)} W`;
  return `${Math.round(value)} mW`;
}

function formatMilliseconds(value) {
  if (value >= 1000) return `${(value / 1000).toFixed(2)}s`;
  return `${Math.round(value)}ms`;
}

function firstLine(value) {
  return String(value || "").split("\n").map((line) => line.trim()).find(Boolean) || "";
}
