import assert from "node:assert/strict";
import test from "node:test";

import { evaluatePowerReport } from "../power-policy.mjs";
import { parsePowermetricsText, summarizePowerSamples } from "../powermetrics-parser.mjs";

test("powermetrics parser extracts estimated SoC power samples", () => {
  const text = `
*** Sampled system activity ***
CPU Power: 1200 mW
GPU Power: 200 mW
ANE Power: 0 mW
*** Sampled system activity ***
CPU Power: 1.1 W
GPU Power: 100 mW
ANE Power: 0 mW
`;
  const samples = parsePowermetricsText(text);

  assert.equal(samples.length, 2);
  assert.equal(samples[0].estimatedSocPowerMilliwatts, 1400);
  assert.equal(samples[1].estimatedSocPowerMilliwatts, 1200);
});

test("power policy approves strong measured local energy reduction", () => {
  const report = powerReportFixture();
  const validation = evaluatePowerReport(report, "marketing");

  assert.equal(validation.passed, true);
  assert.equal(validation.approvedClaims[0].label, "idle-adjusted-estimated-soc-energy");
});

test("power policy rejects weak measured energy reduction", () => {
  const report = powerReportFixture({
    plainJoules: 80,
    browserJoules: 100,
  });
  const validation = evaluatePowerReport(report, "marketing");

  assert.equal(validation.passed, false);
  assert.match(validation.rejectedClaims[0].reasons.join("\n"), /requires at least 30%/);
});

test("power policy rejects missing browser version", () => {
  const report = powerReportFixture();
  report.environment.tooling.browserVersion = null;
  const validation = evaluatePowerReport(report, "marketing");

  assert.equal(validation.passed, false);
  assert.match(validation.errors.join("\n"), /missing browser version/);
});

test("power sample summarizer computes idle-adjusted joules", () => {
  const samples = [
    { estimatedSocPowerMilliwatts: 1200 },
    { estimatedSocPowerMilliwatts: 1400 },
  ];
  const summary = summarizePowerSamples(samples, 10_000, 300);

  assert.equal(summary.sampleCount, 2);
  assert.equal(summary.averageEstimatedSocPowerMilliwatts, 1300);
  assert.equal(summary.grossEstimatedSocEnergyJoules, 13);
  assert.equal(summary.idleAdjustedEstimatedSocEnergyJoules, 10);
});

function powerReportFixture({
  plainJoules = 40,
  browserJoules = 100,
  sampleCount = 12,
} = {}) {
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
      idle: measurement({ sampleCount, averagePower: 300 }),
      plain: measurement({ sampleCount, joules: plainJoules }),
      browser: measurement({ sampleCount, joules: browserJoules }),
    },
    comparison: {
      plainIdleAdjustedJoules: plainJoules,
      browserIdleAdjustedJoules: browserJoules,
      idleAdjustedEnergyReductionPercent: ((browserJoules - plainJoules) / browserJoules) * 100,
    },
  };
}

function measurement({ sampleCount, averagePower = 1000, joules = 10 }) {
  return {
    sampleCount,
    durationMilliseconds: 10_000,
    averageEstimatedSocPowerMilliwatts: averagePower,
    idleAdjustedEstimatedSocEnergyJoules: joules,
    grossEstimatedSocEnergyJoules: joules + 3,
  };
}
