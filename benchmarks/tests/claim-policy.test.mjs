import assert from "node:assert/strict";
import test from "node:test";

import { evaluateComparison, percentageReduction } from "../claim-policy.mjs";

test("marketing policy approves a sufficiently large benchmark with strong reductions", () => {
  const comparison = comparisonFixture();
  const validation = evaluateComparison(comparison, "marketing");

  assert.equal(validation.passed, true);
  assert.deepEqual(
    validation.approvedClaims.map((claim) => claim.label),
    [
      "text-only-bytes",
      "text-only-requests",
      "text-only-time",
      "images-bytes",
      "images-time",
      "javascript",
    ],
  );
});

test("marketing policy rejects tiny benchmark sets", () => {
  const comparison = comparisonFixture({ urls: 3, iterations: 1 });
  const validation = evaluateComparison(comparison, "marketing");

  assert.equal(validation.passed, false);
  assert.match(validation.rejectedClaims[0].reasons.join("\n"), /requires at least 20/);
  assert.match(validation.rejectedClaims[0].reasons.join("\n"), /requires at least 3/);
});

test("marketing policy rejects weak comparative reductions", () => {
  const comparison = comparisonFixture({ textBytes: 760, browserBytes: 1000 });
  const validation = evaluateComparison(comparison, "marketing");
  const rejected = validation.rejectedClaims.find((claim) => claim.label === "text-only-bytes");

  assert.equal(validation.passed, false);
  assert.ok(rejected);
  assert.match(rejected.reasons.join("\n"), /requires at least 50%/);
});

test("marketing policy rejects weak speed reductions", () => {
  const comparison = comparisonFixture({ textMilliseconds: 900, browserMilliseconds: 1000 });
  const validation = evaluateComparison(comparison, "marketing");
  const rejected = validation.rejectedClaims.find((claim) => claim.label === "text-only-time");

  assert.equal(validation.passed, false);
  assert.ok(rejected);
  assert.match(rejected.reasons.join("\n"), /requires at least 30%/);
});

test("marketing policy approves optional memory claims with sufficient reduction", () => {
  const comparison = comparisonFixture({ includeMemoryClaims: true });
  const validation = evaluateComparison(comparison, "marketing");

  assert.equal(validation.passed, true);
  assert.ok(validation.approvedClaims.find((claim) => claim.label === "text-only-memory"));
  assert.ok(validation.approvedClaims.find((claim) => claim.label === "images-memory"));
});

test("marketing policy rejects weak optional memory reductions", () => {
  const comparison = comparisonFixture({
    includeMemoryClaims: true,
    textMemory: 800,
    imageMemory: 820,
    browserMemory: 1000,
  });
  const validation = evaluateComparison(comparison, "marketing");
  const rejected = validation.rejectedClaims.find((claim) => claim.label === "text-only-memory");

  assert.equal(validation.passed, false);
  assert.ok(rejected);
  assert.match(rejected.reasons.join("\n"), /requires at least 30%/);
});

test("marketing policy rejects reports missing required claims", () => {
  const comparison = comparisonFixture();
  comparison.claims = comparison.claims.filter((claim) => claim.label !== "images-time");
  const validation = evaluateComparison(comparison, "marketing");

  assert.equal(validation.passed, false);
  assert.match(validation.errors.join("\n"), /Required claim "images-time" was missing/);
});

test("marketing policy rejects missing environment metadata", () => {
  const comparison = comparisonFixture();
  comparison.environment.tooling.browserVersion = null;
  const validation = evaluateComparison(comparison, "marketing");

  assert.equal(validation.passed, false);
  assert.match(validation.errors.join("\n"), /missing browser version/);
});

test("marketing policy rejects comparisons with too few paired successful runs", () => {
  const comparison = comparisonFixture({ pairedUrls: 18, pairedSuccessRate: 0.9 });
  const validation = evaluateComparison(comparison, "marketing");
  const rejected = validation.rejectedClaims.find((claim) => claim.label === "text-only-bytes");

  assert.equal(validation.passed, false);
  assert.ok(rejected);
  assert.match(rejected.reasons.join("\n"), /Paired text-only comparison used 18 unique URL/);
  assert.match(rejected.reasons.join("\n"), /success rate was 90%/);
});

test("architectural JavaScript claim can pass while comparative claims remain blocked", () => {
  const comparison = comparisonFixture({ urls: 3, iterations: 1 });
  const validation = evaluateComparison(comparison, "marketing");
  const javascriptClaim = validation.approvedClaims.find((claim) => claim.label === "javascript");

  assert.equal(validation.passed, false);
  assert.ok(javascriptClaim);
});

function comparisonFixture({
  urls = 20,
  iterations = 3,
  textBytes = 100,
  imageBytes = 400,
  browserBytes = 1000,
  textRequests = 1,
  imageRequests = 2,
  browserRequests = 20,
  textMilliseconds = 100,
  imageMilliseconds = 120,
  browserMilliseconds = 1000,
  textMemory = 100,
  imageMemory = 140,
  browserMemory = 1000,
  includeMemoryClaims = false,
  successRate = 1,
  pairedUrls = urls,
  pairedSuccessRate = successRate,
} = {}) {
  const now = new Date().toISOString();
  const textReduction = percentageReduction(textBytes, browserBytes);
  const imageReduction = percentageReduction(imageBytes, browserBytes);
  const requestReduction = percentageReduction(textRequests, browserRequests);
  const textTimeReduction = percentageReduction(textMilliseconds, browserMilliseconds);
  const imageTimeReduction = percentageReduction(imageMilliseconds, browserMilliseconds);
  const textMemoryReduction = percentageReduction(textMemory, browserMemory);
  const imageMemoryReduction = percentageReduction(imageMemory, browserMemory);
  const claims = [
    {
      label: "text-only-bytes",
      kind: "comparative",
      plainviewMode: "text-only",
      pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
      reductionPercent: textReduction,
      statement: "Plain text-only downloaded fewer bytes.",
    },
    {
      label: "text-only-requests",
      kind: "comparative",
      plainviewMode: "text-only",
      pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
      reductionPercent: requestReduction,
      statement: "Plain text-only made fewer requests.",
    },
    {
      label: "text-only-time",
      kind: "comparative",
      plainviewMode: "text-only",
      pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
      reductionPercent: textTimeReduction,
      statement: "Plain text-only reached a rendered document sooner.",
    },
    {
      label: "images-bytes",
      kind: "comparative",
      plainviewMode: "images",
      pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
      reductionPercent: imageReduction,
      statement: "Plain images downloaded fewer bytes.",
    },
    {
      label: "images-time",
      kind: "comparative",
      plainviewMode: "images",
      pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
      reductionPercent: imageTimeReduction,
      statement: "Plain images reached a rendered document sooner.",
    },
    {
      label: "javascript",
      kind: "architectural",
      statement: "Plain executed 0 page JavaScript by design.",
    },
  ];

  if (includeMemoryClaims) {
    claims.splice(
      3,
      0,
      {
        label: "text-only-memory",
        kind: "comparative",
        plainviewMode: "text-only",
        pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
        reductionPercent: textMemoryReduction,
        statement: "Plain text-only used less resident memory.",
      },
    );
    claims.splice(
      6,
      0,
      {
        label: "images-memory",
        kind: "comparative",
        plainviewMode: "images",
        pairedEvidence: dataset({ urls: pairedUrls, iterations, successRate: pairedSuccessRate }),
        reductionPercent: imageMemoryReduction,
        statement: "Plain images used less resident memory.",
      },
    );
  }

  return {
    generatedAt: now,
    inputs: {
      plainview: "plainview.json",
      browser: "browser.json",
      browserName: "chromium",
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
        browserVersion: "143.0.7499.40",
      },
    },
    corpus: {
      sha256: "abc123",
    },
    evidence: {
      inputSkewHours: 1,
      plainview: {
        generatedAt: now,
        iterations,
        uniqueUrlCount: urls,
        totalRuns: urls * iterations * 2,
        successfulRuns: Math.round(urls * iterations * 2 * successRate),
        successRate,
        modes: {
          "text-only": dataset({ urls, iterations, successRate }),
          images: dataset({ urls, iterations, successRate }),
        },
      },
      browser: {
        browserName: "chromium",
        generatedAt: now,
        iterations,
        ...dataset({ urls, iterations, successRate }),
      },
    },
    summary: {
      plainviewTextOnly: {
        runs: urls * iterations,
        medianTimeMilliseconds: textMilliseconds,
        medianTransferBytes: textBytes,
        medianRequestCount: textRequests,
        medianResidentBytes: textMemory,
        medianScriptBytes: 0,
      },
      plainviewImages: {
        runs: urls * iterations,
        medianTimeMilliseconds: imageMilliseconds,
        medianTransferBytes: imageBytes,
        medianRequestCount: imageRequests,
        medianResidentBytes: imageMemory,
        medianScriptBytes: 0,
      },
      browser: {
        runs: urls * iterations,
        medianTimeMilliseconds: browserMilliseconds,
        medianTransferBytes: browserBytes,
        medianRequestCount: browserRequests,
        medianResidentBytes: browserMemory,
        medianScriptBytes: 50_000,
      },
    },
    claims,
  };
}

function dataset({ urls, iterations, successRate }) {
  const totalRuns = urls * iterations;
  return {
    iterations,
    uniqueUrlCount: urls,
    totalRuns,
    successfulRuns: Math.round(totalRuns * successRate),
    successRate,
  };
}
