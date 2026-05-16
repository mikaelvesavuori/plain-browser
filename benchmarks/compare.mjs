#!/usr/bin/env node

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  buildEvidence,
  evaluateComparison,
  formatPercent,
  percentageReduction,
} from "./claim-policy.mjs";

const options = parseArgs(process.argv.slice(2));
const plainview = JSON.parse(await fs.readFile(options.plainview, "utf8"));
const browser = JSON.parse(await fs.readFile(options.browser, "utf8"));

const comparison = buildComparison(plainview, browser);

await fs.mkdir(path.dirname(options.output), { recursive: true });
await fs.writeFile(options.output, `${JSON.stringify(comparison, null, 2)}\n`);
await fs.writeFile(replaceExtension(options.output, ".md"), markdown(comparison));

console.log(`Wrote ${options.output}`);
console.log(`Wrote ${replaceExtension(options.output, ".md")}`);

function buildComparison(plainviewReport, browserReport) {
  const textPairs = pairedResults(plainviewReport.results, browserReport.results, "text-only");
  const imagePairs = pairedResults(plainviewReport.results, browserReport.results, "images");
  const browserResults = successful(browserReport.results);
  const evidence = buildEvidence(plainviewReport, browserReport);
  evidence.paired = {
    "text-only": textPairs.evidence,
    images: imagePairs.evidence,
  };

  const summary = {
    plainviewTextOnly: summarizePlainview(textPairs.plainview),
    browserForTextOnly: summarizeBrowser(textPairs.browser),
    plainviewImages: summarizePlainview(imagePairs.plainview),
    browserForImages: summarizeBrowser(imagePairs.browser),
    browser: summarizeBrowser(browserResults),
  };

  const comparison = {
    generatedAt: new Date().toISOString(),
    inputs: {
      plainview: options.plainview,
      browser: options.browser,
      browserName: browserReport.browser,
    },
    environment: collectEnvironment(browserReport),
    corpus: buildCorpus(plainviewReport, browserReport),
    evidence,
    summary,
    claims: claimCandidates(summary, evidence.paired),
  };

  comparison.validation = evaluateComparison(comparison, options.policy);
  return comparison;
}

function summarizePlainview(results) {
  const residentMemoryValues = optionalNumbers(
    results.map((result) => result.residentBytesAfter ?? result.peakResidentBytes),
  );

  return {
    runs: results.length,
    medianTimeMilliseconds: median(results.map((result) => result.totalMilliseconds)),
    medianTransferBytes: median(results.map((result) => result.htmlBytes + result.imageBytes)),
    medianRequestCount: median(results.map((result) => result.requestCount)),
    medianCPUTimeMilliseconds: median(
      results.map((result) => result.cpuUserMilliseconds + result.cpuSystemMilliseconds),
    ),
    medianScriptBytes: 0,
    medianResidentBytes: medianOrNull(residentMemoryValues),
  };
}

function summarizeBrowser(results) {
  const residentMemoryValues = optionalNumbers(
    results.map((result) => result.residentBytesAfter ?? result.peakResidentBytes),
  );

  return {
    runs: results.length,
    medianTimeMilliseconds: median(results.map((result) => result.loadMilliseconds)),
    medianTransferBytes: median(results.map((result) => result.transferBytes)),
    medianRequestCount: median(results.map((result) => result.requestCount)),
    medianScriptBytes: median(results.map((result) => result.scriptBytes)),
    medianThirdPartyHostCount: median(results.map((result) => result.thirdPartyRequestHostCount)),
    medianResidentBytes: medianOrNull(residentMemoryValues),
  };
}

function claimCandidates(summary, pairedEvidence) {
  const {
    plainviewTextOnly: textSummary,
    browserForTextOnly: browserTextSummary,
    plainviewImages: imageSummary,
    browserForImages: browserImageSummary,
  } = summary;
  const claims = [];

  if (textSummary.runs && browserTextSummary.runs) {
    const reductionPercent = percentageReduction(textSummary.medianTransferBytes, browserTextSummary.medianTransferBytes);
    claims.push({
      label: "text-only-bytes",
      kind: "comparative",
      plainviewMode: "text-only",
      metric: "transfer-bytes",
      pairedEvidence: pairedEvidence["text-only"],
      plainviewMedian: textSummary.medianTransferBytes,
      browserMedian: browserTextSummary.medianTransferBytes,
      reductionPercent,
      statement: `Across paired successful runs in this benchmark set, Plain text-only downloaded ${formatPercent(reductionPercent)} fewer bytes than the ${browserTextSummary.runs}-run Chromium baseline median.`,
      basis: "Median Plain text-only transfer bytes vs median Chromium transfer bytes on matched successful URL/iteration pairs.",
    });

    const requestReductionPercent = percentageReduction(textSummary.medianRequestCount, browserTextSummary.medianRequestCount);
    claims.push({
      label: "text-only-requests",
      kind: "comparative",
      plainviewMode: "text-only",
      metric: "request-count",
      pairedEvidence: pairedEvidence["text-only"],
      plainviewMedian: textSummary.medianRequestCount,
      browserMedian: browserTextSummary.medianRequestCount,
      reductionPercent: requestReductionPercent,
      statement: `Across paired successful runs in this benchmark set, Plain text-only made ${formatPercent(requestReductionPercent)} fewer requests than the Chromium baseline median.`,
      basis: "Median Plain text-only request count vs median Chromium request count on matched successful URL/iteration pairs.",
    });

    const timeReductionPercent = percentageReduction(
      textSummary.medianTimeMilliseconds,
      browserTextSummary.medianTimeMilliseconds,
    );
    claims.push({
      label: "text-only-time",
      kind: "comparative",
      plainviewMode: "text-only",
      metric: "load-render-time",
      pairedEvidence: pairedEvidence["text-only"],
      plainviewMedian: textSummary.medianTimeMilliseconds,
      browserMedian: browserTextSummary.medianTimeMilliseconds,
      reductionPercent: timeReductionPercent,
      statement: `Across paired successful runs in this benchmark set, Plain text-only reached a rendered native document ${formatPercent(timeReductionPercent)} sooner than Chromium full page load.`,
      basis: "Median Plain text-only load-to-native-document time vs median Chromium full page load time on matched successful URL/iteration pairs.",
    });

    if (Number.isFinite(textSummary.medianResidentBytes) && Number.isFinite(browserTextSummary.medianResidentBytes)) {
      const memoryReductionPercent = percentageReduction(
        textSummary.medianResidentBytes,
        browserTextSummary.medianResidentBytes,
      );
      claims.push({
        label: "text-only-memory",
        kind: "comparative",
        plainviewMode: "text-only",
        metric: "resident-memory",
        pairedEvidence: pairedEvidence["text-only"],
        plainviewMedian: textSummary.medianResidentBytes,
        browserMedian: browserTextSummary.medianResidentBytes,
        reductionPercent: memoryReductionPercent,
        statement: `Across paired successful runs in this benchmark set, Plain text-only used ${formatPercent(memoryReductionPercent)} less resident memory than Chromium after load.`,
        basis: "Median Plain text-only resident memory after load vs median Chromium browser process-tree resident memory after load on matched successful URL/iteration pairs.",
      });
    }
  }

  if (imageSummary.runs && browserImageSummary.runs) {
    const reductionPercent = percentageReduction(imageSummary.medianTransferBytes, browserImageSummary.medianTransferBytes);
    claims.push({
      label: "images-bytes",
      kind: "comparative",
      plainviewMode: "images",
      metric: "transfer-bytes",
      pairedEvidence: pairedEvidence.images,
      plainviewMedian: imageSummary.medianTransferBytes,
      browserMedian: browserImageSummary.medianTransferBytes,
      reductionPercent,
      statement: `Across paired successful runs in this benchmark set, Plain with images downloaded ${formatPercent(reductionPercent)} fewer bytes than the Chromium baseline median.`,
      basis: "Median Plain image-mode transfer bytes vs median Chromium transfer bytes on matched successful URL/iteration pairs.",
    });

    const timeReductionPercent = percentageReduction(
      imageSummary.medianTimeMilliseconds,
      browserImageSummary.medianTimeMilliseconds,
    );
    claims.push({
      label: "images-time",
      kind: "comparative",
      plainviewMode: "images",
      metric: "load-render-time",
      pairedEvidence: pairedEvidence.images,
      plainviewMedian: imageSummary.medianTimeMilliseconds,
      browserMedian: browserImageSummary.medianTimeMilliseconds,
      reductionPercent: timeReductionPercent,
      statement: `Across paired successful runs in this benchmark set, Plain with images reached a rendered native document ${formatPercent(timeReductionPercent)} sooner than Chromium full page load.`,
      basis: "Median Plain image-mode load-to-native-document time vs median Chromium full page load time on matched successful URL/iteration pairs.",
    });

    if (Number.isFinite(imageSummary.medianResidentBytes) && Number.isFinite(browserImageSummary.medianResidentBytes)) {
      const memoryReductionPercent = percentageReduction(
        imageSummary.medianResidentBytes,
        browserImageSummary.medianResidentBytes,
      );
      claims.push({
        label: "images-memory",
        kind: "comparative",
        plainviewMode: "images",
        metric: "resident-memory",
        pairedEvidence: pairedEvidence.images,
        plainviewMedian: imageSummary.medianResidentBytes,
        browserMedian: browserImageSummary.medianResidentBytes,
        reductionPercent: memoryReductionPercent,
        statement: `Across paired successful runs in this benchmark set, Plain with images used ${formatPercent(memoryReductionPercent)} less resident memory than Chromium after load.`,
        basis: "Median Plain image-mode resident memory after load vs median Chromium browser process-tree resident memory after load on matched successful URL/iteration pairs.",
      });
    }
  }

  claims.push({
    label: "javascript",
    kind: "architectural",
    metric: "page-javascript-execution",
    statement: "Plain executed 0 page JavaScript by design.",
    basis: "Plain fetches HTML and renders a native document model without WebView execution.",
  });

  return claims;
}

function markdown(comparison) {
  const lines = [];
  lines.push("# Plain Benchmark Comparison");
  lines.push("");
  lines.push(`- Generated: ${comparison.generatedAt}`);
  lines.push(`- Browser baseline: ${comparison.inputs.browserName}`);
  lines.push(`- Claim policy: ${comparison.validation.policy.name}`);
  lines.push(`- Claim gate: ${comparison.validation.passed ? "passed" : "not ready"}`);
  lines.push(`- Environment: ${formatEnvironmentSummary(comparison.environment)}`);
  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push("| Metric | Plain Text-Only | Chromium Pair | Plain Images | Chromium Pair |");
  lines.push("| --- | ---: | ---: | ---: | ---: |");
  lines.push(`| Runs | ${comparison.summary.plainviewTextOnly.runs} | ${comparison.summary.browserForTextOnly.runs} | ${comparison.summary.plainviewImages.runs} | ${comparison.summary.browserForImages.runs} |`);
  lines.push(`| Median load/render time | ${formatMilliseconds(comparison.summary.plainviewTextOnly.medianTimeMilliseconds)} | ${formatMilliseconds(comparison.summary.browserForTextOnly.medianTimeMilliseconds)} | ${formatMilliseconds(comparison.summary.plainviewImages.medianTimeMilliseconds)} | ${formatMilliseconds(comparison.summary.browserForImages.medianTimeMilliseconds)} |`);
  lines.push(`| Median transfer bytes | ${formatBytes(comparison.summary.plainviewTextOnly.medianTransferBytes)} | ${formatBytes(comparison.summary.browserForTextOnly.medianTransferBytes)} | ${formatBytes(comparison.summary.plainviewImages.medianTransferBytes)} | ${formatBytes(comparison.summary.browserForImages.medianTransferBytes)} |`);
  lines.push(`| Median requests | ${comparison.summary.plainviewTextOnly.medianRequestCount.toFixed(1)} | ${comparison.summary.browserForTextOnly.medianRequestCount.toFixed(1)} | ${comparison.summary.plainviewImages.medianRequestCount.toFixed(1)} | ${comparison.summary.browserForImages.medianRequestCount.toFixed(1)} |`);
  lines.push(`| Median script bytes | 0 B | ${formatBytes(comparison.summary.browserForTextOnly.medianScriptBytes)} | 0 B | ${formatBytes(comparison.summary.browserForImages.medianScriptBytes)} |`);
  if (
    Number.isFinite(comparison.summary.plainviewTextOnly.medianResidentBytes) ||
    Number.isFinite(comparison.summary.browserForTextOnly.medianResidentBytes) ||
    Number.isFinite(comparison.summary.plainviewImages.medianResidentBytes) ||
    Number.isFinite(comparison.summary.browserForImages.medianResidentBytes)
  ) {
    lines.push(`| Median resident memory after load | ${formatOptionalBytes(comparison.summary.plainviewTextOnly.medianResidentBytes)} | ${formatOptionalBytes(comparison.summary.browserForTextOnly.medianResidentBytes)} | ${formatOptionalBytes(comparison.summary.plainviewImages.medianResidentBytes)} | ${formatOptionalBytes(comparison.summary.browserForImages.medianResidentBytes)} |`);
  }
  lines.push("");
  lines.push("## Evidence");
  lines.push("");
  lines.push(`- Required: ${comparison.validation.policy.minUniqueUrls}+ URLs, ${comparison.validation.policy.minIterations}+ iterations, ${formatPercent(comparison.validation.policy.minSuccessRate * 100)}+ success rate`);
  lines.push(`- Plain text-only: ${formatEvidence(comparison.evidence.plainview.modes["text-only"])}`);
  lines.push(`- Plain images: ${formatEvidence(comparison.evidence.plainview.modes.images)}`);
  lines.push(`- Browser: ${formatEvidence(comparison.evidence.browser)}`);
  lines.push(`- Paired text-only comparison: ${formatEvidence(comparison.evidence.paired["text-only"])}`);
  lines.push(`- Paired image comparison: ${formatEvidence(comparison.evidence.paired.images)}`);
  if (comparison.evidence.inputSkewHours != null) {
    lines.push(`- Plain/browser capture skew: ${comparison.evidence.inputSkewHours.toFixed(1)} hours`);
  }
  lines.push(`- Corpus: ${comparison.corpus.uniqueUrlCount} URL(s), SHA-256 ${comparison.corpus.sha256}`);
  lines.push("");
  lines.push("## Environment");
  lines.push("");
  lines.push(`- Host: ${formatEnvironmentSummary(comparison.environment)}`);
  lines.push(`- CPU: ${comparison.environment.host.cpuModel || "unknown"} (${comparison.environment.host.cpuCount || "unknown"} logical cores)`);
  lines.push(`- Memory: ${formatBytes(comparison.environment.host.totalMemoryBytes || 0)}`);
  lines.push(`- Node: ${comparison.environment.tooling.nodeVersion}`);
  lines.push(`- Swift: ${firstLine(comparison.environment.tooling.swiftVersion) || "unknown"}`);
  lines.push(`- Browser: ${comparison.environment.tooling.browserName || "unknown"} ${comparison.environment.tooling.browserVersion || "unknown"}`);
  lines.push(`- Active network interfaces: ${comparison.environment.network.activeInterfaceNames.join(", ") || "not captured"}`);
  lines.push(`- Power: ${firstLine(comparison.environment.power.batteryStatus) || "not captured"}`);
  lines.push("");
  lines.push("## Claim Readiness");
  lines.push("");

  if (comparison.validation.approvedClaims.length) {
    lines.push("Approved:");
    for (const claim of comparison.validation.approvedClaims) {
      lines.push(`- ${claim.statement}`);
    }
    lines.push("");
  }

  if (comparison.validation.rejectedClaims.length) {
    lines.push("Not ready:");
    for (const claim of comparison.validation.rejectedClaims) {
      lines.push(`- ${claim.statement}`);
      for (const reason of claim.reasons) {
        lines.push(`  - ${reason}`);
      }
    }
    lines.push("");
  }

  if (comparison.validation.warnings.length) {
    lines.push("Warnings:");
    for (const warning of comparison.validation.warnings) {
      lines.push(`- ${warning}`);
    }
    lines.push("");
  }

  lines.push('Avoid broad unqualified claims such as "green," "eco-friendly," or "always faster." Use only claims approved by the gate, and cite benchmark URL set, date, machine, network, browser, and median values.');
  return `${lines.join("\n")}\n`;
}

function successful(results) {
  return results.filter((result) => result.success);
}

function pairedResults(plainviewResults, browserResults, mode) {
  const modeResults = plainviewResults.filter((result) => result.mode === mode);
  const browserSuccessByKey = new Map(successful(browserResults).map((result) => [resultKey(result), result]));
  const expectedKeys = new Set([
    ...modeResults.map(resultKey),
    ...browserResults.map(resultKey),
  ]);
  const pairs = [];

  for (const plainviewResult of modeResults) {
    if (!plainviewResult.success) continue;

    const browserResult = browserSuccessByKey.get(resultKey(plainviewResult));
    if (browserResult) {
      pairs.push({ plainview: plainviewResult, browser: browserResult });
    }
  }

  return {
    plainview: pairs.map((pair) => pair.plainview),
    browser: pairs.map((pair) => pair.browser),
    evidence: {
      uniqueUrlCount: new Set(pairs.map((pair) => pair.plainview.url).filter(Boolean)).size,
      iterations: iterationCount(pairs.map((pair) => pair.plainview)),
      totalRuns: expectedKeys.size,
      successfulRuns: pairs.length,
      successRate: expectedKeys.size ? pairs.length / expectedKeys.size : 0,
    },
  };
}

function resultKey(result) {
  return `${result.url}#${result.iteration}`;
}

function buildCorpus(plainviewReport, browserReport) {
  const urls = [
    ...extractUrls(plainviewReport),
    ...extractUrls(browserReport),
  ];
  const uniqueUrls = [...new Set(urls)].sort();
  return {
    uniqueUrlCount: uniqueUrls.length,
    urls: uniqueUrls,
    sha256: sha256(uniqueUrls.join("\n")),
  };
}

function extractUrls(report) {
  return (Array.isArray(report?.results) ? report.results : [])
    .map((result) => result.url)
    .filter(Boolean);
}

function collectEnvironment(browserReport) {
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
      browserName: browserReport?.browser || null,
      browserVersion: browserReport?.browserVersion || null,
    },
    network: {
      activeInterfaceNames: activeNetworkInterfaceNames(),
    },
    power: {
      batteryStatus: safeExec("pmset", ["-g", "batt"]) || null,
    },
  };
}

function activeNetworkInterfaceNames() {
  const interfaces = os.networkInterfaces();
  return Object.entries(interfaces)
    .filter(([name, addresses]) => !/^(awdl|llw|utun|lo)/.test(name) && addresses?.some((address) => !address.internal))
    .map(([name]) => name)
    .sort();
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

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function parseArgs(args) {
  const options = {
    plainview: "benchmarks/results/plainview.json",
    browser: "benchmarks/results/browser-chromium.json",
    output: "benchmarks/results/comparison.json",
    policy: "marketing",
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--plainview") options.plainview = next();
    else if (arg === "--browser") options.browser = next();
    else if (arg === "--out") options.output = next();
    else if (arg === "--policy") options.policy = next();
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node benchmarks/compare.mjs --plainview benchmarks/results/plainview.json --browser benchmarks/results/browser-chromium.json --policy marketing");
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

function replaceExtension(filePath, extension) {
  return path.join(path.dirname(filePath), `${path.basename(filePath, path.extname(filePath))}${extension}`);
}

function median(values) {
  if (!values.length) return 0;
  const sorted = values.slice().sort((a, b) => a - b);
  const midpoint = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) return (sorted[midpoint - 1] + sorted[midpoint]) / 2;
  return sorted[midpoint];
}

function medianOrNull(values) {
  if (!values.length) return null;
  return median(values);
}

function optionalNumbers(values) {
  return values.filter((value) => Number.isFinite(value));
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

function formatEvidence(evidence) {
  return `${evidence.uniqueUrlCount} URL(s), ${evidence.iterations} iteration(s), ${evidence.successfulRuns}/${evidence.totalRuns} successful (${formatPercent(evidence.successRate * 100)})`;
}

function iterationCount(results) {
  return new Set(results.map((result) => result.iteration).filter((iteration) => Number.isInteger(iteration))).size;
}

function formatEnvironmentSummary(environment) {
  const host = environment?.host || {};
  return `${host.os || host.platform || "unknown OS"} ${host.osVersion || host.osBuild || ""}, ${host.arch || "unknown arch"}, ${host.machineModel || "unknown machine"}`.trim();
}

function firstLine(value) {
  return String(value || "").split("\n").map((line) => line.trim()).find(Boolean) || "";
}
