import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(fileURLToPath(new URL("../..", import.meta.url)));

test("Plain architecture does not embed a web JavaScript engine", async () => {
  const sourceFiles = await swiftSourceFiles(path.join(repoRoot, "Sources"));
  const forbidden = [
    /\bimport\s+WebKit\b/,
    /\bWKWebView\b/,
    /\bimport\s+JavaScriptCore\b/,
    /\bJSContext\b/,
  ];

  for (const file of sourceFiles) {
    const contents = await fs.readFile(file, "utf8");
    for (const pattern of forbidden) {
      assert.equal(pattern.test(contents), false, `${path.relative(repoRoot, file)} matched ${pattern}`);
    }
  }
});

async function swiftSourceFiles(root) {
  const entries = await fs.readdir(root, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await swiftSourceFiles(fullPath)));
    } else if (entry.isFile() && entry.name.endsWith(".swift")) {
      files.push(fullPath);
    }
  }

  return files;
}
