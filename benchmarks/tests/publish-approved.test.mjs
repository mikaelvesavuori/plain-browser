import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

import { percentageReduction } from "../claim-policy.mjs";

const execFileAsync = promisify(execFile);
const publishScript = new URL("../publish-approved.mjs", import.meta.url);

test("publisher can republish from approved latest without deleting its own inputs", async () => {
  const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), "plain-publish-"));

  try {
    const approvedDir = path.join(tempRoot, "approved");
    const latestDir = path.join(approvedDir, "latest");
    await fs.mkdir(latestDir, { recursive: true });

    const comparison = comparisonFixture();
    const power = powerReportFixture();

    await writeText(path.join(latestDir, "comparison-marketing.json"), JSON.stringify(comparison, null, 2));
    await writeText(path.join(latestDir, "comparison-marketing.md"), "# Comparison\n");
    await writeText(path.join(latestDir, "plain-marketing.json"), "{}\n");
    await writeText(path.join(latestDir, "plain-marketing.md"), "# Plain\n");
    await writeText(path.join(latestDir, "browser-marketing.json"), "{}\n");
    await writeText(path.join(latestDir, "browser-marketing.md"), "# Browser\n");
    await writeText(path.join(latestDir, "urls-marketing.txt"), "https://example.com\n");
    await writeText(path.join(latestDir, "power-marketing.json"), JSON.stringify(power, null, 2));
    await writeText(path.join(latestDir, "power-marketing.md"), "# Power\n");

    await execFileAsync(process.execPath, [
      publishScript.pathname,
      "--comparison",
      path.join(latestDir, "comparison-marketing.json"),
      "--plain",
      path.join(latestDir, "plain-marketing.json"),
      "--browser",
      path.join(latestDir, "browser-marketing.json"),
      "--urls",
      path.join(latestDir, "urls-marketing.txt"),
      "--power",
      path.join(latestDir, "power-marketing.json"),
      "--out-dir",
      approvedDir,
    ]);

    const nextLatestComparison = JSON.parse(
      await fs.readFile(path.join(latestDir, "comparison-marketing.json"), "utf8"),
    );
    const nextLatestPower = JSON.parse(await fs.readFile(path.join(latestDir, "power-marketing.json"), "utf8"));
    const approvedEntries = await fs.readdir(approvedDir);

    assert.equal(nextLatestComparison.generatedAt, comparison.generatedAt);
    assert.equal(nextLatestPower.generatedAt, power.generatedAt);
    assert.ok(approvedEntries.includes("latest"));
    assert.ok(approvedEntries.some((entry) => entry !== "latest"));
  } finally {
    await fs.rm(tempRoot, { recursive: true, force: true });
  }
});

async function writeText(filePath, value) {
  await fs.writeFile(filePath, `${value.replace(/\n?$/, "\n")}`);
}

function comparisonFixture() {
  const generatedAt = new Date().toISOString();
  const urls = 20;
  const iterations = 3;
  const textBytes = 100;
  const imageBytes = 400;
  const browserBytes = 1000;
  const textRequests = 1;
  const browserRequests = 20;
  const textMilliseconds = 100;
  const imageMilliseconds = 120;
  const browserMilliseconds = 1000;

  return {
    generatedAt,
    inputs: {
      browserName: "chromium",
    },
    environment: {
      host: {
        os: "macOS",
        osVersion: "26.3",
        arch: "arm64",
        cpuModel: "Apple M2",
      },
      tooling: {
        nodeVersion: "v25.6.1",
        swiftVersion: "Apple Swift version 6.3.2",
        browserVersion: "148.0.7778.96",
      },
    },
    corpus: {
      sha256: "abc123",
    },
    evidence: {
      inputSkewHours: 0,
      plain: {
        generatedAt,
        iterations,
        modes: {
          "text-only": dataset({ urls, iterations }),
          images: dataset({ urls, iterations }),
        },
      },
      browser: {
        browserName: "chromium",
        generatedAt,
        iterations,
        ...dataset({ urls, iterations }),
      },
    },
    summary: {
      plainTextOnly: {
        medianTransferBytes: textBytes,
        medianRequestCount: textRequests,
        medianTimeMilliseconds: textMilliseconds,
        medianScriptBytes: 0,
      },
      plainImages: {
        medianTransferBytes: imageBytes,
        medianTimeMilliseconds: imageMilliseconds,
        medianScriptBytes: 0,
      },
      browser: {
        medianTransferBytes: browserBytes,
        medianRequestCount: browserRequests,
        medianTimeMilliseconds: browserMilliseconds,
        medianScriptBytes: 50_000,
      },
    },
    claims: [
      claim("text-only-bytes", "text-only", percentageReduction(textBytes, browserBytes)),
      claim("text-only-requests", "text-only", percentageReduction(textRequests, browserRequests)),
      claim("text-only-time", "text-only", percentageReduction(textMilliseconds, browserMilliseconds)),
      claim("images-bytes", "images", percentageReduction(imageBytes, browserBytes)),
      claim("images-time", "images", percentageReduction(imageMilliseconds, browserMilliseconds)),
      {
        label: "javascript",
        kind: "architectural",
        statement: "Plain executed 0 page JavaScript by design.",
      },
    ],
  };
}

function powerReportFixture() {
  const generatedAt = new Date().toISOString();
  return {
    generatedAt,
    method: {
      tool: "powermetrics",
      toolCaveat: "estimated values",
    },
    environment: {
      host: {
        osVersion: "26.3",
        arch: "arm64",
        cpuModel: "Apple M2",
      },
      tooling: {
        nodeVersion: "v25.6.1",
        swiftVersion: "Apple Swift version 6.3.2",
        browserVersion: "148.0.7778.96",
      },
      power: {
        batteryStatus: "Now drawing from 'AC Power'",
      },
    },
    corpus: {
      uniqueUrlCount: 20,
      iterations: 3,
      sha256: "abc123",
    },
    measurements: {
      idle: measurement({ joules: 3 }),
      plain: measurement({ joules: 40 }),
      browser: measurement({ joules: 100 }),
    },
    comparison: {
      plainIdleAdjustedJoules: 40,
      browserIdleAdjustedJoules: 100,
      idleAdjustedEnergyReductionPercent: 60,
    },
  };
}

function claim(label, plainMode, reductionPercent) {
  return {
    label,
    kind: "comparative",
    plainMode,
    pairedEvidence: dataset({ urls: 20, iterations: 3 }),
    reductionPercent,
    statement: `${label} passed.`,
  };
}

function dataset({ urls, iterations }) {
  return {
    iterations,
    uniqueUrlCount: urls,
    totalRuns: urls * iterations,
    successfulRuns: urls * iterations,
    successRate: 1,
  };
}

function measurement({ joules }) {
  return {
    sampleCount: 12,
    durationMilliseconds: 10_000,
    averageEstimatedSocPowerMilliwatts: 1000,
    idleAdjustedEstimatedSocEnergyJoules: joules,
    grossEstimatedSocEnergyJoules: joules + 3,
  };
}
