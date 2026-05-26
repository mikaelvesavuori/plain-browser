const DAY_MS = 24 * 60 * 60 * 1000;

export const POWER_POLICIES = Object.freeze({
  smoke: Object.freeze({
    name: "smoke",
    minUniqueUrls: 1,
    minIterations: 1,
    minSamples: 2,
    maxReportAgeDays: 3650,
    minIdleAdjustedEnergyReductionPercent: 0,
    requireEnvironment: false,
  }),
  marketing: Object.freeze({
    name: "marketing",
    minUniqueUrls: 20,
    minIterations: 3,
    minSamples: 10,
    maxReportAgeDays: 30,
    minIdleAdjustedEnergyReductionPercent: 30,
    requireEnvironment: true,
  }),
});

export function evaluatePowerReport(report, policy = "marketing", overrides = {}) {
  const resolvedPolicy = resolvePowerPolicy(policy, overrides);
  const errors = [];
  const warnings = [];
  const approvedClaims = [];
  const rejectedClaims = [];
  const comparison = report?.comparison || {};
  const reductionPercent = comparison.idleAdjustedEnergyReductionPercent || 0;

  errors.push(...freshnessReasons(report, resolvedPolicy));
  errors.push(...corpusReasons(report?.corpus, resolvedPolicy));
  errors.push(...measurementReasons("Idle baseline", report?.measurements?.idle, resolvedPolicy));
  errors.push(...measurementReasons("Plain workload", report?.measurements?.plain, resolvedPolicy));
  errors.push(...measurementReasons("Chromium workload", report?.measurements?.browser, resolvedPolicy));

  if (resolvedPolicy.requireEnvironment) {
    errors.push(...environmentReasons(report?.environment));
  }

  const claim = {
    label: "idle-adjusted-estimated-soc-energy",
    kind: "power",
    metric: "idle-adjusted-estimated-soc-energy-joules",
    plainValue: comparison.plainIdleAdjustedJoules,
    browserValue: comparison.browserIdleAdjustedJoules,
    reductionPercent,
    statement: `In this measured local run, Plain used ${formatPercent(reductionPercent)} less idle-adjusted estimated SoC energy than the Chromium baseline.`,
    basis: "macOS powermetrics estimated CPU/GPU/ANE power integrated over matched benchmark workloads on the same machine.",
  };

  if (reductionPercent < resolvedPolicy.minIdleAdjustedEnergyReductionPercent) {
    rejectedClaims.push({
      ...claim,
      reasons: [
        `Energy reduction was ${formatPercent(reductionPercent)}; policy requires at least ${formatPercent(resolvedPolicy.minIdleAdjustedEnergyReductionPercent)}.`,
      ],
    });
  } else {
    approvedClaims.push(claim);
  }

  if (!report?.method?.toolCaveat) {
    warnings.push("Report is missing the powermetrics caveat; power claims should stay qualified as estimated local measurements.");
  }

  return {
    policy: resolvedPolicy,
    passed: errors.length === 0 && rejectedClaims.length === 0,
    errors,
    warnings,
    approvedClaims,
    rejectedClaims,
  };
}

export function resolvePowerPolicy(policy = "marketing", overrides = {}) {
  const base = typeof policy === "string" ? POWER_POLICIES[policy] : policy;
  if (!base) throw new Error(`Unknown power policy: ${policy}`);
  return { ...base, ...overrides };
}

export function percentageReduction(value, baseline) {
  if (!Number.isFinite(value) || !Number.isFinite(baseline) || baseline <= 0 || value >= baseline) {
    return 0;
  }

  return ((baseline - value) / baseline) * 100;
}

export function formatPercent(value) {
  return `${Math.round(value)}%`;
}

function freshnessReasons(report, policy) {
  const generatedAt = Date.parse(report?.generatedAt || "");
  if (!Number.isFinite(generatedAt)) return ["Power report is missing a valid generatedAt timestamp."];

  const ageDays = (Date.now() - generatedAt) / DAY_MS;
  if (ageDays > policy.maxReportAgeDays) {
    return [`Power report is ${ageDays.toFixed(1)} day(s) old; policy allows at most ${policy.maxReportAgeDays}.`];
  }

  return [];
}

function corpusReasons(corpus, policy) {
  const reasons = [];
  if (!corpus?.sha256) reasons.push("Power report is missing corpus hash.");
  if ((corpus?.uniqueUrlCount || 0) < policy.minUniqueUrls) {
    reasons.push(`Power report used ${corpus?.uniqueUrlCount || 0} URL(s); policy requires at least ${policy.minUniqueUrls}.`);
  }
  if ((corpus?.iterations || 0) < policy.minIterations) {
    reasons.push(`Power report used ${corpus?.iterations || 0} iteration(s); policy requires at least ${policy.minIterations}.`);
  }
  return reasons;
}

function measurementReasons(label, measurement, policy) {
  if (!measurement) return [`${label} measurement is missing.`];

  const reasons = [];
  if ((measurement.sampleCount || 0) < policy.minSamples) {
    reasons.push(`${label} has ${measurement.sampleCount || 0} power sample(s); policy requires at least ${policy.minSamples}.`);
  }
  if (!Number.isFinite(measurement.averageEstimatedSocPowerMilliwatts)) {
    reasons.push(`${label} is missing average estimated SoC power.`);
  }
  if (label !== "Idle baseline" && !Number.isFinite(measurement.idleAdjustedEstimatedSocEnergyJoules)) {
    reasons.push(`${label} is missing idle-adjusted estimated SoC energy.`);
  }
  return reasons;
}

function environmentReasons(environment) {
  const reasons = [];
  if (!environment) return ["Power report is missing environment metadata."];
  if (!environment.host?.osVersion) reasons.push("Power report environment is missing OS version.");
  if (!environment.host?.arch) reasons.push("Power report environment is missing CPU architecture.");
  if (!environment.host?.cpuModel) reasons.push("Power report environment is missing CPU model.");
  if (!environment.tooling?.nodeVersion) reasons.push("Power report environment is missing Node version.");
  if (!environment.tooling?.swiftVersion) reasons.push("Power report environment is missing Swift version.");
  if (!environment.tooling?.browserVersion) reasons.push("Power report environment is missing browser version.");
  if (!environment.power?.batteryStatus) reasons.push("Power report environment is missing power status.");
  return reasons;
}
