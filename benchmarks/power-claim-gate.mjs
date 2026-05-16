#!/usr/bin/env node

import fs from "node:fs/promises";
import { evaluatePowerReport, formatPercent } from "./power-policy.mjs";

const options = parseArgs(process.argv.slice(2));
const report = JSON.parse(await fs.readFile(options.power, "utf8"));
const validation = evaluatePowerReport(report, options.policy);

console.log(`Plain power claim gate: ${validation.passed ? "PASS" : "NOT READY"} (${validation.policy.name})`);
console.log(`Required: ${validation.policy.minUniqueUrls}+ URLs, ${validation.policy.minIterations}+ iterations, ${validation.policy.minSamples}+ power samples, ${formatPercent(validation.policy.minIdleAdjustedEnergyReductionPercent)}+ idle-adjusted estimated SoC energy reduction`);

if (validation.errors.length) {
  console.log("");
  console.log("Errors:");
  for (const error of validation.errors) console.log(`- ${error}`);
}

if (validation.approvedClaims.length) {
  console.log("");
  console.log("Approved claims:");
  for (const claim of validation.approvedClaims) console.log(`- ${claim.statement}`);
}

if (validation.rejectedClaims.length) {
  console.log("");
  console.log("Not ready:");
  for (const claim of validation.rejectedClaims) {
    console.log(`- ${claim.statement}`);
    for (const reason of claim.reasons) console.log(`  - ${reason}`);
  }
}

if (validation.warnings.length) {
  console.log("");
  console.log("Warnings:");
  for (const warning of validation.warnings) console.log(`- ${warning}`);
}

if (!validation.passed) process.exit(1);

function parseArgs(args) {
  const options = {
    power: "benchmarks/results/power-marketing.json",
    policy: "marketing",
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--power") options.power = next();
    else if (arg === "--policy") options.policy = next();
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node benchmarks/power-claim-gate.mjs --power benchmarks/results/power-marketing.json --policy marketing");
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}
