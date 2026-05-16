#!/usr/bin/env node

import fs from "node:fs/promises";
import { formatPercent, percentageReduction } from "./claim-policy.mjs";
import { evaluatePowerReport } from "./power-policy.mjs";

const START = "<!-- plain-claims:start -->";
const END = "<!-- plain-claims:end -->";

const options = parseArgs(process.argv.slice(2));
const comparison = JSON.parse(await fs.readFile(options.comparison, "utf8"));
const power = await readOptionalPowerReport(options.power);
const readme = await fs.readFile(options.readme, "utf8");
const nextSection = renderClaims(comparison, options.report, power);
const updated = replaceMarkedSection(readme, nextSection);

await fs.writeFile(options.readme, updated);
console.log(`Updated ${options.readme}`);

function renderClaims(comparison, reportPath, power) {
  const textSummary = comparison.summary.plainviewTextOnly;
  const browserTextSummary = comparison.summary.browserForTextOnly;
  const imageSummary = comparison.summary.plainviewImages;
  const browserImageSummary = comparison.summary.browserForImages;
  const pairedText = comparison.evidence.paired["text-only"];
  const approvedLabels = new Set(comparison.validation.approvedClaims.map((claim) => claim.label));
  const lines = [];

  lines.push(START);
  lines.push(`Plain's current marketing claim gate passes against Chromium on a ${pairedText.uniqueUrlCount}-URL corpus with ${pairedText.iterations} iterations per URL, using ${pairedText.successfulRuns}/${pairedText.totalRuns} paired successful URL/iteration comparisons. Full report: [${reportPath}](${reportPath}).`);
  lines.push("");
  lines.push("Approved claims from the latest run:");
  lines.push("");

  if (approvedLabels.has("text-only-bytes")) {
    lines.push(`- Plain text-only downloaded ${formatPercent(percentageReduction(textSummary.medianTransferBytes, browserTextSummary.medianTransferBytes))} fewer bytes than Chromium: ${formatBytes(textSummary.medianTransferBytes)} vs ${formatBytes(browserTextSummary.medianTransferBytes)} median transfer.`);
  }

  if (approvedLabels.has("text-only-requests")) {
    lines.push(`- Plain text-only made ${formatPercent(percentageReduction(textSummary.medianRequestCount, browserTextSummary.medianRequestCount))} fewer network requests than Chromium: ${textSummary.medianRequestCount.toFixed(0)} vs ${browserTextSummary.medianRequestCount.toFixed(0)} median requests.`);
  }

  if (approvedLabels.has("text-only-time")) {
    lines.push(`- Plain text-only reached a rendered native document ${formatPercent(percentageReduction(textSummary.medianTimeMilliseconds, browserTextSummary.medianTimeMilliseconds))} sooner than Chromium full page load: ${formatMilliseconds(textSummary.medianTimeMilliseconds)} vs ${formatMilliseconds(browserTextSummary.medianTimeMilliseconds)} median.`);
  }

  if (approvedLabels.has("text-only-memory")) {
    lines.push(`- Plain text-only used ${formatPercent(percentageReduction(textSummary.medianResidentBytes, browserTextSummary.medianResidentBytes))} less resident memory than Chromium after load: ${formatBytes(textSummary.medianResidentBytes)} vs ${formatBytes(browserTextSummary.medianResidentBytes)} median.`);
  }

  if (approvedLabels.has("images-bytes")) {
    lines.push(`- Plain with images enabled downloaded ${formatPercent(percentageReduction(imageSummary.medianTransferBytes, browserImageSummary.medianTransferBytes))} fewer bytes than Chromium: ${formatBytes(imageSummary.medianTransferBytes)} vs ${formatBytes(browserImageSummary.medianTransferBytes)} median transfer.`);
  }

  if (approvedLabels.has("images-time")) {
    lines.push(`- Plain with images enabled reached a rendered native document ${formatPercent(percentageReduction(imageSummary.medianTimeMilliseconds, browserImageSummary.medianTimeMilliseconds))} sooner than Chromium full page load: ${formatMilliseconds(imageSummary.medianTimeMilliseconds)} vs ${formatMilliseconds(browserImageSummary.medianTimeMilliseconds)} median.`);
  }

  if (approvedLabels.has("images-memory")) {
    lines.push(`- Plain with images enabled used ${formatPercent(percentageReduction(imageSummary.medianResidentBytes, browserImageSummary.medianResidentBytes))} less resident memory than Chromium after load: ${formatBytes(imageSummary.medianResidentBytes)} vs ${formatBytes(browserImageSummary.medianResidentBytes)} median.`);
  }

  if (approvedLabels.has("javascript")) {
    lines.push("- Plain executed 0 page JavaScript by design.");
  }

  if (power?.validation?.passed) {
    const powerClaim = power.validation.approvedClaims.find((claim) => claim.label === "idle-adjusted-estimated-soc-energy");
    if (powerClaim) {
      lines.push(`- Plain used ${formatPercent(powerClaim.reductionPercent)} less idle-adjusted estimated SoC energy than Chromium in the measured power run: ${formatJoules(powerClaim.plainviewValue)} vs ${formatJoules(powerClaim.browserValue)}. Power report: [benchmarks/approved/latest/power-marketing.md](benchmarks/approved/latest/power-marketing.md).`);
    }
  }

  lines.push("");
  lines.push(`Evidence captured ${comparison.generatedAt} on ${environmentSummary(comparison.environment)}. These claims are generated from local benchmark evidence, not hand-written assumptions.`);
  lines.push(END);

  return lines.join("\n");
}

async function readOptionalPowerReport(filePath) {
  if (!filePath) return null;

  try {
    const report = JSON.parse(await fs.readFile(filePath, "utf8"));
    const validation = evaluatePowerReport(report, "marketing");
    return { ...report, validation };
  } catch (error) {
    if (error && error.code === "ENOENT") return null;
    throw error;
  }
}

function replaceMarkedSection(readme, nextSection) {
  const start = readme.indexOf(START);
  const end = readme.indexOf(END);

  if (start === -1 || end === -1 || end < start) {
    throw new Error(`README is missing ${START}/${END} markers.`);
  }

  return `${readme.slice(0, start)}${nextSection}${readme.slice(end + END.length)}`;
}

function parseArgs(args) {
  const options = {
    comparison: "benchmarks/approved/latest/comparison-marketing.json",
    power: "benchmarks/approved/latest/power-marketing.json",
    readme: "README.md",
    report: "benchmarks/approved/latest/comparison-marketing.md",
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--comparison") options.comparison = next();
    else if (arg === "--power") options.power = next();
    else if (arg === "--readme") options.readme = next();
    else if (arg === "--report") options.report = next();
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node benchmarks/update-readme-claims.mjs --comparison benchmarks/approved/latest/comparison-marketing.json --readme README.md");
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
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

function formatJoules(value) {
  return `${value.toFixed(2)} J`;
}

function environmentSummary(environment) {
  const host = environment?.host || {};
  return `${host.os || host.platform || "unknown OS"} ${host.osVersion || ""}, ${host.arch || "unknown arch"}, ${host.machineModel || "unknown machine"}`.trim();
}
