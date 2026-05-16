#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { evaluateComparison } from "./claim-policy.mjs";
import { evaluatePowerReport } from "./power-policy.mjs";

const options = parseArgs(process.argv.slice(2));
const artifactInputs = await readArtifactInputs(options);
const comparison = JSON.parse(artifactInputs.comparisonJson);
const validation = evaluateComparison(comparison, "marketing");

if (!validation.passed) {
  console.error("Refusing to publish: marketing claim gate did not pass.");
  for (const error of validation.errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

if (options.power) {
  const powerReport = JSON.parse(artifactInputs.powerJson);
  const powerValidation = evaluatePowerReport(powerReport, "marketing");
  if (!powerValidation.passed) {
    console.error("Refusing to publish power evidence: marketing power claim gate did not pass.");
    for (const error of powerValidation.errors) {
      console.error(`- ${error}`);
    }
    for (const claim of powerValidation.rejectedClaims) {
      console.error(`- ${claim.statement}`);
      for (const reason of claim.reasons) console.error(`  - ${reason}`);
    }
    process.exit(1);
  }
}

const slug = options.slug || artifactSlug(comparison);
const artifactDir = path.join(options.outDir, slug);
const latestDir = path.join(options.outDir, "latest");

await fs.mkdir(artifactDir, { recursive: true });
await writeReportSet(artifactDir, artifactInputs);
await writePowerReport(artifactDir, artifactInputs);
await writeManifest(path.join(artifactDir, "manifest.json"), comparison, validation, options);

await fs.rm(latestDir, { recursive: true, force: true });
await fs.mkdir(latestDir, { recursive: true });
await writeReportSet(latestDir, artifactInputs);
await writePowerReport(latestDir, artifactInputs);
await writeManifest(path.join(latestDir, "manifest.json"), comparison, validation, options);

console.log(`Published approved evidence: ${artifactDir}`);
console.log(`Updated latest evidence: ${latestDir}`);

async function readArtifactInputs(paths) {
  return {
    comparisonJson: await fs.readFile(paths.comparison, "utf8"),
    comparisonMarkdown: await fs.readFile(replaceExtension(paths.comparison, ".md"), "utf8"),
    plainviewJson: await fs.readFile(paths.plainview, "utf8"),
    plainviewMarkdown: await fs.readFile(replaceExtension(paths.plainview, ".md"), "utf8"),
    browserJson: await fs.readFile(paths.browser, "utf8"),
    browserMarkdown: await fs.readFile(replaceExtension(paths.browser, ".md"), "utf8"),
    urlsText: await fs.readFile(paths.urls, "utf8"),
    powerJson: paths.power ? await fs.readFile(paths.power, "utf8") : null,
    powerMarkdown: paths.power ? await fs.readFile(replaceExtension(paths.power, ".md"), "utf8") : null,
  };
}

async function writeReportSet(destinationDir, inputs) {
  await fs.writeFile(path.join(destinationDir, "comparison-marketing.json"), inputs.comparisonJson);
  await fs.writeFile(path.join(destinationDir, "comparison-marketing.md"), inputs.comparisonMarkdown);
  await fs.writeFile(path.join(destinationDir, "plainview-marketing.json"), inputs.plainviewJson);
  await fs.writeFile(path.join(destinationDir, "plainview-marketing.md"), inputs.plainviewMarkdown);
  await fs.writeFile(path.join(destinationDir, "browser-marketing.json"), inputs.browserJson);
  await fs.writeFile(path.join(destinationDir, "browser-marketing.md"), inputs.browserMarkdown);
  await fs.writeFile(path.join(destinationDir, "urls-marketing.txt"), inputs.urlsText);
}

async function writePowerReport(destinationDir, inputs) {
  if (!inputs.powerJson || !inputs.powerMarkdown) return;

  await fs.writeFile(path.join(destinationDir, "power-marketing.json"), inputs.powerJson);
  await fs.writeFile(path.join(destinationDir, "power-marketing.md"), inputs.powerMarkdown);
}

async function writeManifest(filePath, comparison, validation, paths) {
  const manifest = {
    publishedAt: new Date().toISOString(),
    generatedAt: comparison.generatedAt,
    policy: validation.policy,
    approvedClaims: validation.approvedClaims,
    evidence: comparison.evidence,
    corpus: comparison.corpus,
    environment: comparison.environment,
    sourceFiles: {
      comparison: paths.comparison,
      plainview: paths.plainview,
      browser: paths.browser,
      urls: paths.urls,
      power: paths.power,
    },
  };

  await fs.writeFile(filePath, `${JSON.stringify(manifest, null, 2)}\n`);
}

function artifactSlug(comparison) {
  const date = String(comparison.generatedAt || new Date().toISOString()).slice(0, 10);
  const browser = sanitize(comparison.inputs?.browserName || comparison.environment?.tooling?.browserName || "browser");
  const os = sanitize(comparison.environment?.host?.os || comparison.environment?.host?.platform || "os");
  const arch = sanitize(comparison.environment?.host?.arch || process.arch);
  return `${date}-${browser}-${os}-${arch}`.toLowerCase();
}

function sanitize(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function replaceExtension(filePath, extension) {
  return path.join(path.dirname(filePath), `${path.basename(filePath, path.extname(filePath))}${extension}`);
}

function parseArgs(args) {
  const options = {
    comparison: "benchmarks/results/comparison-marketing.json",
    plainview: "benchmarks/results/plainview-marketing.json",
    browser: "benchmarks/results/browser-marketing.json",
    urls: "benchmarks/urls-marketing.txt",
    power: null,
    outDir: "benchmarks/approved",
    slug: null,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const next = () => {
      index += 1;
      if (index >= args.length) throw new Error(`Missing value for ${arg}`);
      return args[index];
    };

    if (arg === "--comparison") options.comparison = next();
    else if (arg === "--plainview") options.plainview = next();
    else if (arg === "--browser") options.browser = next();
    else if (arg === "--urls") options.urls = next();
    else if (arg === "--power") options.power = next();
    else if (arg === "--out-dir") options.outDir = next();
    else if (arg === "--slug") options.slug = next();
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node benchmarks/publish-approved.mjs --comparison benchmarks/results/comparison-marketing.json --plainview benchmarks/results/plainview-marketing.json --browser benchmarks/results/browser-marketing.json");
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}
