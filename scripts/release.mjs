#!/usr/bin/env node

import { select, confirm } from "@inquirer/prompts";
import { readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { execSync } from "node:child_process";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const PLUGINS_DIR = join(ROOT, "plugins");
const MARKETPLACE = join(ROOT, ".claude-plugin", "marketplace.json");

// ── helpers ──────────────────────────────────────────────────────────────────

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf-8"));
}

function writeJson(path, data) {
  writeFileSync(path, JSON.stringify(data, null, 2) + "\n");
}

function bump(version, type) {
  const [major, minor, patch] = version.split(".").map(Number);
  switch (type) {
    case "major":
      return `${major + 1}.0.0`;
    case "minor":
      return `${major}.${minor + 1}.0`;
    case "patch":
      return `${major}.${minor}.${patch + 1}`;
  }
}

function discoverPlugins() {
  return readdirSync(PLUGINS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => {
      const manifest = join(PLUGINS_DIR, d.name, ".claude-plugin", "plugin.json");
      if (!existsSync(manifest)) return null;
      const data = readJson(manifest);
      return { name: data.name, version: data.version, manifest };
    })
    .filter(Boolean);
}

function run(cmd) {
  execSync(cmd, { cwd: ROOT, stdio: "inherit" });
}

// ── main ─────────────────────────────────────────────────────────────────────

const plugins = discoverPlugins();

if (plugins.length === 0) {
  console.error("No plugins found.");
  process.exit(1);
}

const plugin = await select({
  message: "Which plugin?",
  choices: plugins.map((p) => ({
    name: `${p.name} (v${p.version})`,
    value: p,
  })),
});

const type = await select({
  message: `Bump type for ${plugin.name} (current: v${plugin.version})?`,
  choices: [
    { name: "patch", value: "patch" },
    { name: "minor", value: "minor" },
    { name: "major", value: "major" },
  ],
});

const newVersion = bump(plugin.version, type);

const ok = await confirm({
  message: `Release ${plugin.name} v${plugin.version} → v${newVersion}?`,
});

if (!ok) {
  console.log("Aborted.");
  process.exit(0);
}

// update plugin manifest
const manifestData = readJson(plugin.manifest);
manifestData.version = newVersion;
writeJson(plugin.manifest, manifestData);
console.log(`  updated ${plugin.manifest}`);

// update marketplace registry if plugin is listed there
const filesToStage = [plugin.manifest];

if (existsSync(MARKETPLACE)) {
  const marketplace = readJson(MARKETPLACE);
  const entry = marketplace.plugins?.find((p) => p.name === plugin.name);
  if (entry) {
    entry.version = newVersion;
    writeJson(MARKETPLACE, marketplace);
    filesToStage.push(MARKETPLACE);
    console.log(`  updated ${MARKETPLACE}`);
  }
}

// git stage, commit, tag
run(`git add ${filesToStage.map((f) => `"${f}"`).join(" ")}`);
run(`git commit -m "Release ${plugin.name} v${newVersion}"`);
run(`git tag -a "${plugin.name}/v${newVersion}" -m "${plugin.name} v${newVersion}"`);

console.log(`\nTagged ${plugin.name}/v${newVersion}`);
console.log("Run 'git push && git push --tags' to publish.");
