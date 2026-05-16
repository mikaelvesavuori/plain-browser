#!/usr/bin/env node

import fs from "node:fs/promises";
import { evaluateComparison, formatPercent } from "./claim-policy.mjs";

const options = parseArgs(process.argv.slice(2));
const comparison = JSON.parse(await fs.readFile(options.comparison, "utf8"));
const validation = evaluateComparison(comparison, options.policy, options.overrides);

console.log(`Plain claim gate: ${validation.passed ? "PASS" : "NOT READY"} (${validation.policy.name})`);
console.log(`Required: ${validation.policy.minUniqueUrls}+ URLs, ${validation.policy.minIterations}+ iterations, ${formatPercent(validation.policy.minSuccessRate * 100)}+ success rate`);

if (validation.errors.length) {
  console.log("");
  console.log("Errors:");
  for (const error of validation.errors) {
    console.log(`- ${error}`);
  }
}

if (validation.approvedClaims.length) {
  console.log("");
  console.log("Approved claims:");
  for (const claim of validation.approvedClaims) {
    console.log(`- ${claim.statement}`);
  }
}

if (validation.rejectedClaims.length) {
  console.log("");
  console.log("Not ready:");
  for (const claim of validation.rejectedClaims) {
    console.log(`- ${claim.statement}`);
    for (const reason of claim.reasons) {
      console.log(`  - ${reason}`);
    }
  }
}

if (validation.warnings.length) {
  console.log("");
  console.log("Warnings:");
  for (const warning of validation.warnings) {
    console.log(`- ${warning}`);
  }
}

if (!validation.passed) {
  process.exit(1);
}

function parseArgs(args) {
  const options = {
    comparison: "benchmarks/results/comparison.json",
    policy: "marketing",
    overrides: {},
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--comparison") options.comparison = next();
    else if (arg === "--policy") options.policy = next();
    else if (arg === "--min-urls") options.overrides.minUniqueUrls = positiveInteger(next(), arg);
    else if (arg === "--min-iterations") options.overrides.minIterations = positiveInteger(next(), arg);
    else if (arg === "--min-success-rate") options.overrides.minSuccessRate = boundedNumber(next(), arg);
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node benchmarks/claim-gate.mjs --comparison benchmarks/results/comparison.json --policy marketing");
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

function positiveInteger(value, optionName) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw new Error(`${optionName} must be a positive integer`);
  }
  return parsed;
}

function boundedNumber(value, optionName) {
  const parsed = Number.parseFloat(value);
  if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 1) {
    throw new Error(`${optionName} must be a number between 0 and 1`);
  }
  return parsed;
}
