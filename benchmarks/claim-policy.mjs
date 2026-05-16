const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

export const POLICIES = Object.freeze({
  smoke: Object.freeze({
    name: "smoke",
    label: "Smoke",
    requireComparativeClaims: true,
    minUniqueUrls: 1,
    minIterations: 1,
    minSuccessRate: 0.8,
    maxReportAgeDays: 3650,
    maxInputSkewHours: 168,
    requireEnvironment: false,
    requiredClaims: Object.freeze([
      "text-only-bytes",
      "text-only-requests",
      "text-only-time",
      "images-bytes",
      "images-time",
      "javascript",
    ]),
    claims: Object.freeze({
      "text-only-bytes": Object.freeze({ minReductionPercent: 0 }),
      "text-only-requests": Object.freeze({ minReductionPercent: 0 }),
      "text-only-time": Object.freeze({ minReductionPercent: 0 }),
      "text-only-memory": Object.freeze({ minReductionPercent: 0 }),
      "images-bytes": Object.freeze({ minReductionPercent: 0 }),
      "images-time": Object.freeze({ minReductionPercent: 0 }),
      "images-memory": Object.freeze({ minReductionPercent: 0 }),
    }),
  }),
  marketing: Object.freeze({
    name: "marketing",
    label: "Marketing evidence",
    requireComparativeClaims: true,
    minUniqueUrls: 20,
    minIterations: 3,
    minSuccessRate: 0.95,
    maxReportAgeDays: 30,
    maxInputSkewHours: 24,
    requireEnvironment: true,
    requiredClaims: Object.freeze([
      "text-only-bytes",
      "text-only-requests",
      "text-only-time",
      "images-bytes",
      "images-time",
      "javascript",
    ]),
    claims: Object.freeze({
      "text-only-bytes": Object.freeze({ minReductionPercent: 50 }),
      "text-only-requests": Object.freeze({ minReductionPercent: 50 }),
      "text-only-time": Object.freeze({ minReductionPercent: 30 }),
      "text-only-memory": Object.freeze({ minReductionPercent: 30 }),
      "images-bytes": Object.freeze({ minReductionPercent: 30 }),
      "images-time": Object.freeze({ minReductionPercent: 30 }),
      "images-memory": Object.freeze({ minReductionPercent: 30 }),
    }),
  }),
});

export function resolvePolicy(policy = "marketing", overrides = {}) {
  const base = typeof policy === "string" ? POLICIES[policy] : policy;
  if (!base) {
    throw new Error(`Unknown claim policy: ${policy}`);
  }

  return {
    ...base,
    ...overrides,
    requiredClaims: overrides.requiredClaims || base.requiredClaims || [],
    claims: {
      ...base.claims,
      ...(overrides.claims || {}),
    },
  };
}

export function buildEvidence(plainviewReport, browserReport) {
  const plainviewResults = Array.isArray(plainviewReport?.results) ? plainviewReport.results : [];
  const browserResults = Array.isArray(browserReport?.results) ? browserReport.results : [];
  const plainviewGeneratedAt = plainviewReport?.generatedAt || null;
  const browserGeneratedAt = browserReport?.generatedAt || null;

  return {
    plainview: {
      generatedAt: plainviewGeneratedAt,
      toolVersion: plainviewReport?.toolVersion || null,
      iterations: iterationCount(plainviewReport, plainviewResults),
      ...datasetEvidence(plainviewResults),
      modes: {
        "text-only": {
          iterations: iterationCount(plainviewReport, plainviewResults.filter((result) => result.mode === "text-only")),
          ...datasetEvidence(plainviewResults.filter((result) => result.mode === "text-only")),
        },
        images: {
          iterations: iterationCount(plainviewReport, plainviewResults.filter((result) => result.mode === "images")),
          ...datasetEvidence(plainviewResults.filter((result) => result.mode === "images")),
        },
      },
    },
    browser: {
      browserName: browserReport?.browser || null,
      generatedAt: browserGeneratedAt,
      toolVersion: browserReport?.toolVersion || null,
      iterations: iterationCount(browserReport, browserResults),
      ...datasetEvidence(browserResults),
    },
    inputSkewHours: inputSkewHours([plainviewGeneratedAt, browserGeneratedAt]),
  };
}

export function evaluateComparison(comparison, policy = "marketing", overrides = {}) {
  const resolvedPolicy = resolvePolicy(policy, overrides);
  const claims = Array.isArray(comparison?.claims) ? comparison.claims : [];
  const comparativeClaims = claims.filter((claim) => claim.kind === "comparative");
  const approvedClaims = [];
  const rejectedClaims = [];
  const errors = [];
  const warnings = [];

  if (resolvedPolicy.requireComparativeClaims && comparativeClaims.length === 0) {
    errors.push("No comparative benchmark claims were found.");
  }

  const claimLabels = new Set(claims.map((claim) => claim.label));
  for (const requiredLabel of resolvedPolicy.requiredClaims || []) {
    if (!claimLabels.has(requiredLabel)) {
      errors.push(`Required claim "${requiredLabel}" was missing.`);
    }
  }

  if (resolvedPolicy.requireEnvironment) {
    errors.push(...environmentReasons(comparison));
  }

  for (const claim of claims) {
    const reasons = reasonsForClaim(claim, comparison, resolvedPolicy);
    if (reasons.length) {
      rejectedClaims.push({ ...claim, reasons });
    } else {
      approvedClaims.push(claim);
    }
  }

  const rejectedComparativeCount = rejectedClaims.filter((claim) => claim.kind === "comparative").length;
  const rejectedArchitecturalCount = rejectedClaims.filter((claim) => claim.kind === "architectural").length;

  if (rejectedComparativeCount > 0) {
    errors.push(`${rejectedComparativeCount} comparative claim(s) did not meet the ${resolvedPolicy.name} policy.`);
  }

  if (rejectedArchitecturalCount > 0) {
    errors.push(`${rejectedArchitecturalCount} architectural claim(s) did not meet the ${resolvedPolicy.name} policy.`);
  }

  if ((comparison?.summary?.browser?.medianScriptBytes || 0) === 0) {
    warnings.push("Browser baseline reported 0 script bytes; check that resource timing was captured correctly.");
  }

  return {
    policy: {
      name: resolvedPolicy.name,
      label: resolvedPolicy.label,
      minUniqueUrls: resolvedPolicy.minUniqueUrls,
      minIterations: resolvedPolicy.minIterations,
      minSuccessRate: resolvedPolicy.minSuccessRate,
      maxReportAgeDays: resolvedPolicy.maxReportAgeDays,
      maxInputSkewHours: resolvedPolicy.maxInputSkewHours,
      requireEnvironment: resolvedPolicy.requireEnvironment,
      requiredClaims: resolvedPolicy.requiredClaims,
      claims: resolvedPolicy.claims,
    },
    passed: errors.length === 0,
    errors,
    warnings,
    approvedClaims,
    rejectedClaims,
  };
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

function reasonsForClaim(claim, comparison, policy) {
  if (claim.kind === "architectural") {
    return architecturalClaimReasons(claim, comparison);
  }

  if (claim.kind !== "comparative") {
    return [`Unknown claim kind: ${claim.kind || "missing"}.`];
  }

  const evidence = comparison?.evidence;
  if (!evidence) {
    return ["Comparison is missing evidence metadata. Re-run benchmarks/compare.mjs with the current tooling."];
  }

  const reasons = [];
  const plainviewMode = claim.plainviewMode || inferPlainviewMode(claim.label);
  if (claim.pairedEvidence) {
    reasons.push(...datasetReasons(`Paired ${plainviewMode} comparison`, claim.pairedEvidence, policy));
  } else {
    const plainviewEvidence = evidence.plainview?.modes?.[plainviewMode];
    reasons.push(...datasetReasons(`Plain ${plainviewMode}`, plainviewEvidence, policy));
    reasons.push(...datasetReasons("Browser baseline", evidence.browser, policy));
  }

  reasons.push(...freshnessReasons(comparison, evidence, policy));

  const requirement = policy.claims?.[claim.label];
  if (!requirement) {
    reasons.push(`No policy requirement is defined for claim "${claim.label}".`);
  } else if ((claim.reductionPercent || 0) < requirement.minReductionPercent) {
    reasons.push(
      `${claim.label} reduction was ${formatPercent(claim.reductionPercent || 0)}; policy requires at least ${formatPercent(requirement.minReductionPercent)}.`,
    );
  }

  return reasons;
}

function architecturalClaimReasons(claim, comparison) {
  if (claim.label !== "javascript") {
    return [];
  }

  const textScriptBytes = comparison?.summary?.plainviewTextOnly?.medianScriptBytes || 0;
  const imageScriptBytes = comparison?.summary?.plainviewImages?.medianScriptBytes || 0;
  const reasons = [];

  if (textScriptBytes !== 0) {
    reasons.push(`Plain text-only reported ${textScriptBytes} script bytes; expected 0.`);
  }

  if (imageScriptBytes !== 0) {
    reasons.push(`Plain images reported ${imageScriptBytes} script bytes; expected 0.`);
  }

  return reasons;
}

function datasetReasons(label, dataset, policy) {
  if (!dataset) {
    return [`${label} evidence is missing.`];
  }

  const reasons = [];

  if ((dataset.uniqueUrlCount || 0) < policy.minUniqueUrls) {
    reasons.push(`${label} used ${dataset.uniqueUrlCount || 0} unique URL(s); policy requires at least ${policy.minUniqueUrls}.`);
  }

  if ((dataset.iterations || 0) < policy.minIterations) {
    reasons.push(`${label} used ${dataset.iterations || 0} iteration(s); policy requires at least ${policy.minIterations}.`);
  }

  if ((dataset.totalRuns || 0) === 0) {
    reasons.push(`${label} has no benchmark runs.`);
  } else if ((dataset.successRate || 0) < policy.minSuccessRate) {
    reasons.push(
      `${label} success rate was ${formatPercent((dataset.successRate || 0) * 100)}; policy requires at least ${formatPercent(policy.minSuccessRate * 100)}.`,
    );
  }

  return reasons;
}

function freshnessReasons(comparison, evidence, policy) {
  const reasons = [];
  const generatedAt = Date.parse(comparison?.generatedAt || "");

  if (!Number.isFinite(generatedAt)) {
    reasons.push("Comparison is missing a valid generatedAt timestamp.");
  } else {
    const ageDays = (Date.now() - generatedAt) / DAY_MS;
    if (ageDays > policy.maxReportAgeDays) {
      reasons.push(`Comparison is ${ageDays.toFixed(1)} day(s) old; policy allows at most ${policy.maxReportAgeDays}.`);
    }
  }

  if (evidence.inputSkewHours == null) {
    reasons.push("Plain and browser input timestamps are missing or invalid.");
  } else if (evidence.inputSkewHours > policy.maxInputSkewHours) {
    reasons.push(
      `Plain/browser reports were captured ${evidence.inputSkewHours.toFixed(1)} hour(s) apart; policy allows at most ${policy.maxInputSkewHours}.`,
    );
  }

  if (!evidence.browser?.browserName) {
    reasons.push("Browser baseline name is missing.");
  }

  return reasons;
}

function environmentReasons(comparison) {
  const reasons = [];
  const environment = comparison?.environment;

  if (!environment) {
    return ["Comparison is missing environment metadata."];
  }

  if (!environment.host?.osVersion) reasons.push("Environment is missing OS version.");
  if (!environment.host?.arch) reasons.push("Environment is missing CPU architecture.");
  if (!environment.host?.cpuModel) reasons.push("Environment is missing CPU model.");
  if (!environment.tooling?.nodeVersion) reasons.push("Environment is missing Node version.");
  if (!environment.tooling?.swiftVersion) reasons.push("Environment is missing Swift version.");
  if (!environment.tooling?.browserVersion) reasons.push("Environment is missing browser version.");
  if (!comparison?.corpus?.sha256) reasons.push("Comparison is missing corpus hash.");

  return reasons;
}

function datasetEvidence(results) {
  const successfulRuns = results.filter((result) => result.success).length;
  const totalRuns = results.length;

  return {
    uniqueUrlCount: new Set(results.map((result) => result.url).filter(Boolean)).size,
    totalRuns,
    successfulRuns,
    successRate: totalRuns ? successfulRuns / totalRuns : 0,
  };
}

function iterationCount(report, results) {
  if (Number.isInteger(report?.iterations) && report.iterations > 0) {
    return report.iterations;
  }

  return new Set(results.map((result) => result.iteration).filter((iteration) => Number.isInteger(iteration))).size;
}

function inputSkewHours(values) {
  const timestamps = values.map((value) => Date.parse(value || "")).filter((value) => Number.isFinite(value));
  if (timestamps.length < 2) return null;

  return (Math.max(...timestamps) - Math.min(...timestamps)) / HOUR_MS;
}

function inferPlainviewMode(label) {
  if (label === "images-bytes") return "images";
  return "text-only";
}
