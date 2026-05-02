#!/usr/bin/env node
// One-shot bridge: run a code review prompt against a local Ollama-served model
// via the Claude Code CLI in headless mode. Subcommands: setup, review,
// adversarial-review.
//
// Env contract (read at runtime):
//   OLLAMA_REVIEW_MODEL  required for review/adversarial-review; the Ollama tag
//                        passed as `claude --model <tag>` (e.g. qwen3-coder:30b)
//   OLLAMA_BASE_URL      optional; default http://localhost:11434
//   OLLAMA_CLAUDE_BIN    optional; path to the claude CLI; default `claude`

import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PLUGIN_ROOT = path.resolve(__dirname, "..");
const PROMPT_DIR = path.join(PLUGIN_ROOT, "prompts");
const SCHEMA_PATH = path.join(PLUGIN_ROOT, "schemas", "review-output.schema.json");

const DEFAULT_BASE_URL = "http://localhost:11434";
const DEFAULT_CLAUDE_BIN = "claude";
// Plain review collects the whole working tree and tends to run longest.
const REVIEW_TIMEOUT_MS = 5_400_000;
// Adversarial review uses a tighter prompt and finishes faster.
const ADVERSARIAL_REVIEW_TIMEOUT_MS = 1_800_000;
const MAX_UNTRACKED_BYTES = 24 * 1024;
const INLINE_DIFF_MAX_FILES = 2;
const INLINE_DIFF_MAX_BYTES = 256 * 1024;

// ---------------------------------------------------------------------------
// Subprocess helpers (sync; review work is one-shot so async buys nothing)
// ---------------------------------------------------------------------------

function runSync(cmd, args, options = {}) {
  return spawnSync(cmd, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    ...options
  });
}

function runChecked(cmd, args, options = {}) {
  const result = runSync(cmd, args, options);
  if (result.error && result.error.code === "ENOENT") {
    throw new Error(`${cmd} is not installed or not on PATH.`);
  }
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    const stderr = (result.stderr || "").trim();
    throw new Error(`${cmd} ${args.join(" ")} failed (exit ${result.status})${stderr ? `: ${stderr}` : ""}`);
  }
  return result;
}

function git(cwd, args) {
  return runSync("git", args, { cwd });
}

function gitChecked(cwd, args) {
  return runChecked("git", args, { cwd });
}

// ---------------------------------------------------------------------------
// Argument parsing — review/adversarial-review only
// ---------------------------------------------------------------------------

// Convert one $ARGUMENTS-style string into an argv array. The skill body passes
// the raw `$ARGUMENTS` substitution as a single argv slot; everything else
// arrives as already-split argv. Either shape works.
function flattenRawArgs(argv) {
  if (argv.length === 1 && /\s/.test(argv[0])) {
    return argv[0].match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g)?.map(stripQuotes) ?? [];
  }
  return argv;
}

function stripQuotes(token) {
  if ((token.startsWith('"') && token.endsWith('"')) || (token.startsWith("'") && token.endsWith("'"))) {
    return token.slice(1, -1);
  }
  return token;
}

function parseReviewArgs(rawArgv) {
  const argv = flattenRawArgs(rawArgv);
  let scope = "auto";
  let baseRef = null;
  const focusParts = [];
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    // --wait/--background are routing flags handled by the SKILL.md, not by us
    if (token === "--wait" || token === "--background") continue;
    if (token === "--base") {
      baseRef = argv[++i] ?? null;
      if (!baseRef) throw new Error("--base requires a ref argument.");
      continue;
    }
    if (token.startsWith("--base=")) {
      baseRef = token.slice("--base=".length);
      continue;
    }
    if (token === "--scope") {
      scope = argv[++i] ?? "auto";
      continue;
    }
    if (token.startsWith("--scope=")) {
      scope = token.slice("--scope=".length);
      continue;
    }
    if (token.startsWith("--")) {
      throw new Error(`Unknown flag: ${token}`);
    }
    focusParts.push(token);
  }
  return { scope, baseRef, focus: focusParts.join(" ").trim() };
}

// ---------------------------------------------------------------------------
// Git scope resolution + context collection (ported from codex/lib/git.mjs)
// ---------------------------------------------------------------------------

function ensureGitRepository(cwd) {
  const result = git(cwd, ["rev-parse", "--show-toplevel"]);
  if (result.error && result.error.code === "ENOENT") {
    throw new Error("git is not installed. Install Git and retry.");
  }
  if (result.status !== 0) {
    throw new Error("This command must run inside a Git repository.");
  }
  return result.stdout.trim();
}

function detectDefaultBranch(cwd) {
  const symbolic = git(cwd, ["symbolic-ref", "refs/remotes/origin/HEAD"]);
  if (symbolic.status === 0) {
    const ref = symbolic.stdout.trim();
    if (ref.startsWith("refs/remotes/origin/")) {
      return ref.replace("refs/remotes/origin/", "");
    }
  }
  for (const cand of ["main", "master", "trunk"]) {
    if (git(cwd, ["show-ref", "--verify", "--quiet", `refs/heads/${cand}`]).status === 0) return cand;
    if (git(cwd, ["show-ref", "--verify", "--quiet", `refs/remotes/origin/${cand}`]).status === 0) return `origin/${cand}`;
  }
  throw new Error("Unable to detect the repository default branch. Pass --base <ref> or use --scope working-tree.");
}

function getCurrentBranch(cwd) {
  return gitChecked(cwd, ["branch", "--show-current"]).stdout.trim() || "HEAD";
}

function getWorkingTreeState(cwd) {
  const staged = gitChecked(cwd, ["diff", "--cached", "--name-only"]).stdout.trim().split("\n").filter(Boolean);
  const unstaged = gitChecked(cwd, ["diff", "--name-only"]).stdout.trim().split("\n").filter(Boolean);
  const untracked = gitChecked(cwd, ["ls-files", "--others", "--exclude-standard"]).stdout.trim().split("\n").filter(Boolean);
  return { staged, unstaged, untracked, isDirty: staged.length + unstaged.length + untracked.length > 0 };
}

function resolveReviewTarget(cwd, { scope = "auto", baseRef = null } = {}) {
  ensureGitRepository(cwd);
  const supported = new Set(["auto", "working-tree", "branch"]);
  if (!supported.has(scope)) {
    throw new Error(`Unsupported review scope "${scope}". Use one of: auto, working-tree, branch.`);
  }
  if (baseRef) {
    return { mode: "branch", label: `branch diff against ${baseRef}`, baseRef };
  }
  if (scope === "working-tree") {
    return { mode: "working-tree", label: "working tree diff" };
  }
  if (scope === "branch") {
    const detected = detectDefaultBranch(cwd);
    return { mode: "branch", label: `branch diff against ${detected}`, baseRef: detected };
  }
  // auto
  if (getWorkingTreeState(cwd).isDirty) {
    return { mode: "working-tree", label: "working tree diff" };
  }
  const detected = detectDefaultBranch(cwd);
  return { mode: "branch", label: `branch diff against ${detected}`, baseRef: detected };
}

function isProbablyText(buffer) {
  const sample = buffer.subarray(0, Math.min(buffer.length, 8000));
  if (sample.includes(0)) return false;
  return true;
}

function formatSection(title, body) {
  const trimmed = (body || "").trim();
  return `## ${title}\n\n${trimmed || "(none)"}\n`;
}

function formatUntrackedFile(cwd, rel) {
  const abs = path.join(cwd, rel);
  let stat;
  try {
    stat = fs.statSync(abs);
  } catch {
    return `### ${rel}\n(skipped: broken symlink or unreadable file)`;
  }
  if (stat.isDirectory()) return `### ${rel}\n(skipped: directory)`;
  if (stat.size > MAX_UNTRACKED_BYTES) {
    return `### ${rel}\n(skipped: ${stat.size} bytes exceeds ${MAX_UNTRACKED_BYTES} byte limit)`;
  }
  let buf;
  try {
    buf = fs.readFileSync(abs);
  } catch {
    return `### ${rel}\n(skipped: broken symlink or unreadable file)`;
  }
  if (!isProbablyText(buf)) return `### ${rel}\n(skipped: binary file)`;
  return `### ${rel}\n\`\`\`\n${buf.toString("utf8").trimEnd()}\n\`\`\``;
}

function uniqSorted(...groups) {
  return [...new Set(groups.flat().filter(Boolean))].sort();
}

function measureBytes(cwd, args, cap) {
  const result = runSync("git", args, { cwd, maxBuffer: cap + 1 });
  if (result.error && result.error.code === "ENOBUFS") return cap + 1;
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error((result.stderr || "").trim() || `git ${args.join(" ")} failed`);
  return Buffer.byteLength(result.stdout, "utf8");
}

function collectWorkingTreeContext(cwd, state, includeDiff) {
  const status = gitChecked(cwd, ["status", "--short", "--untracked-files=all"]).stdout.trim();
  const untrackedBody = state.untracked.map((f) => formatUntrackedFile(cwd, f)).join("\n\n");
  if (includeDiff) {
    const stagedDiff = gitChecked(cwd, ["diff", "--cached", "--binary", "--no-ext-diff", "--submodule=diff"]).stdout;
    const unstagedDiff = gitChecked(cwd, ["diff", "--binary", "--no-ext-diff", "--submodule=diff"]).stdout;
    return [
      formatSection("Git Status", status),
      formatSection("Staged Diff", stagedDiff),
      formatSection("Unstaged Diff", unstagedDiff),
      formatSection("Untracked Files", untrackedBody)
    ].join("\n");
  }
  const stagedStat = gitChecked(cwd, ["diff", "--shortstat", "--cached"]).stdout.trim();
  const unstagedStat = gitChecked(cwd, ["diff", "--shortstat"]).stdout.trim();
  const changedFiles = uniqSorted(state.staged, state.unstaged, state.untracked);
  return [
    formatSection("Git Status", status),
    formatSection("Staged Diff Stat", stagedStat),
    formatSection("Unstaged Diff Stat", unstagedStat),
    formatSection("Changed Files", changedFiles.join("\n")),
    formatSection("Untracked Files", untrackedBody)
  ].join("\n");
}

function buildBranchComparison(cwd, baseRef) {
  const mergeBase = gitChecked(cwd, ["merge-base", "HEAD", baseRef]).stdout.trim();
  return { mergeBase, commitRange: `${mergeBase}..HEAD` };
}

function collectBranchContext(cwd, baseRef, includeDiff, comparison) {
  const branch = getCurrentBranch(cwd);
  const log = gitChecked(cwd, ["log", "--oneline", "--decorate", comparison.commitRange]).stdout.trim();
  const stat = gitChecked(cwd, ["diff", "--stat", comparison.commitRange]).stdout.trim();
  const changedFiles = gitChecked(cwd, ["diff", "--name-only", comparison.commitRange]).stdout.trim().split("\n").filter(Boolean);
  if (includeDiff) {
    const diff = gitChecked(cwd, ["diff", "--binary", "--no-ext-diff", "--submodule=diff", comparison.commitRange]).stdout;
    return {
      content: [
        formatSection(`Branch (${branch}) vs ${baseRef} — Commit Log`, log),
        formatSection("Diff Stat", stat),
        formatSection("Branch Diff", diff)
      ].join("\n"),
      changedFiles
    };
  }
  return {
    content: [
      formatSection(`Branch (${branch}) vs ${baseRef} — Commit Log`, log),
      formatSection("Diff Stat", stat),
      formatSection("Changed Files", changedFiles.join("\n"))
    ].join("\n"),
    changedFiles
  };
}

function collectReviewContext(cwd, target) {
  const repoRoot = ensureGitRepository(cwd);
  if (target.mode === "working-tree") {
    const state = getWorkingTreeState(repoRoot);
    const fileCount = uniqSorted(state.staged, state.unstaged, state.untracked).length;
    const diffBytes = measureBytes(
      repoRoot,
      ["diff", "--cached", "--binary", "--no-ext-diff", "--submodule=diff"],
      INLINE_DIFF_MAX_BYTES
    );
    const includeDiff = fileCount <= INLINE_DIFF_MAX_FILES && diffBytes <= INLINE_DIFF_MAX_BYTES;
    return {
      repoRoot,
      content: collectWorkingTreeContext(repoRoot, state, includeDiff),
      inputMode: includeDiff ? "inline-diff" : "self-collect",
      fileCount,
      diffBytes
    };
  }
  const comparison = buildBranchComparison(repoRoot, target.baseRef);
  const filesOut = gitChecked(repoRoot, ["diff", "--name-only", comparison.commitRange]).stdout.trim();
  const fileCount = filesOut ? filesOut.split("\n").filter(Boolean).length : 0;
  const diffBytes = measureBytes(
    repoRoot,
    ["diff", "--binary", "--no-ext-diff", "--submodule=diff", comparison.commitRange],
    INLINE_DIFF_MAX_BYTES
  );
  const includeDiff = fileCount <= INLINE_DIFF_MAX_FILES && diffBytes <= INLINE_DIFF_MAX_BYTES;
  const branchCtx = collectBranchContext(repoRoot, target.baseRef, includeDiff, comparison);
  return {
    repoRoot,
    content: branchCtx.content,
    inputMode: includeDiff ? "inline-diff" : "self-collect",
    fileCount,
    diffBytes
  };
}

function buildCollectionGuidance(inputMode) {
  if (inputMode === "inline-diff") {
    return "Use the repository context below as primary evidence.";
  }
  return "The repository context below is a lightweight summary because the diff exceeded inlining limits. Reason from what is here; do not invent code paths you cannot see.";
}

// ---------------------------------------------------------------------------
// Prompt loading + interpolation
// ---------------------------------------------------------------------------

function loadPromptTemplate(name) {
  const templatePath = path.join(PROMPT_DIR, `${name}.md`);
  return fs.readFileSync(templatePath, "utf8");
}

function interpolateTemplate(template, vars) {
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    if (Object.prototype.hasOwnProperty.call(vars, key)) {
      return vars[key];
    }
    return match;
  });
}

function buildPrompt(promptName, target, context, focus) {
  const template = loadPromptTemplate(promptName);
  const schema = fs.readFileSync(SCHEMA_PATH, "utf8");
  const interpolated = interpolateTemplate(template, {
    TARGET_LABEL: target.label,
    USER_FOCUS: focus || "No extra focus provided.",
    REVIEW_INPUT: context.content,
    REVIEW_COLLECTION_GUIDANCE: buildCollectionGuidance(context.inputMode)
  });
  // Append the schema and a hard JSON-only instruction. Codex enforces this via
  // an outputSchema RPC; Ollama models honor an explicit "JSON only" line in
  // the prompt far more reliably than any flag we could pass.
  return [
    interpolated,
    "",
    "<output_schema>",
    schema.trim(),
    "</output_schema>",
    "",
    "Return ONLY a JSON object matching the schema above. No prose before or after. No code fences."
  ].join("\n");
}

// ---------------------------------------------------------------------------
// Claude headless invocation
// ---------------------------------------------------------------------------

function buildClaudeEnv(model, baseUrl) {
  return {
    ...process.env,
    ANTHROPIC_BASE_URL: baseUrl,
    // Empty string (not unset) disables outbound auth to api.anthropic.com so
    // the CLI accepts the local endpoint. Verified via claude-code-guide research.
    ANTHROPIC_API_KEY: "",
    ANTHROPIC_AUTH_TOKEN: "ollama",
    // Override tier defaults so any internal background call lands on the same
    // local model rather than a hosted Claude tier the local server can't serve.
    ANTHROPIC_DEFAULT_HAIKU_MODEL: model,
    ANTHROPIC_DEFAULT_SONNET_MODEL: model,
    ANTHROPIC_DEFAULT_OPUS_MODEL: model
  };
}

function invokeClaudeHeadless(prompt, model, baseUrl, claudeBin, timeoutMs = REVIEW_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const args = [
      "-p", "-",
      "--model", model,
      "--output-format", "json",
      "--max-turns", "50",
      "--permission-mode", "default",
      "--allowedTools", "Read",
      "--allowedTools", "Glob",
      "--allowedTools", "Grep",
      "--strict-mcp-config"
    ];
    const child = spawn(claudeBin, args, {
      env: buildClaudeEnv(model, baseUrl),
      stdio: ["pipe", "pipe", "pipe"]
    });
    // Pipe prompt via stdin to avoid E2BIG when the inlined diff is large
    child.stdin.on("error", () => {});
    child.stdin.end(prompt, "utf8");
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });

    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`claude headless run timed out after ${timeoutMs} ms`));
    }, timeoutMs);

    child.on("error", (err) => {
      clearTimeout(timer);
      if (err.code === "ENOENT") {
        reject(new Error(`claude CLI not found at "${claudeBin}". Set OLLAMA_CLAUDE_BIN or install Claude Code.`));
        return;
      }
      reject(err);
    });
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, stdout, stderr });
    });
  });
}

// ---------------------------------------------------------------------------
// Output parsing and rendering (ported from codex/lib/render.mjs)
// ---------------------------------------------------------------------------

// claude --output-format json (CLI 2.1.118+) emits a JSON array of typed
// events. Older builds emitted a single flat object. Accept both shapes.
function extractResultEvent(stdout) {
  try {
    const parsed = JSON.parse(stdout);
    const events = Array.isArray(parsed) ? parsed : [parsed];
    return events.find(e => e.type === "result") ?? null;
  } catch {
    return null;
  }
}

function parseClaudeEnvelope(stdout) {
  try {
    const resultEvent = extractResultEvent(stdout);
    const inner = typeof resultEvent?.result === "string" ? resultEvent.result : "";
    return { envelope: resultEvent, inner };
  } catch (err) {
    return { envelope: null, inner: stdout, envelopeParseError: err.message };
  }
}

function stripJsonFences(text) {
  const trimmed = text.trim();
  const fenced = trimmed.match(/^```(?:json)?\s*\n([\s\S]*?)\n```$/);
  if (fenced) return fenced[1].trim();
  return trimmed;
}

function parseModelJson(inner) {
  if (!inner || !inner.trim()) {
    return { parsed: null, parseError: "empty model output", raw: inner };
  }
  const stripped = stripJsonFences(inner);
  try {
    return { parsed: JSON.parse(stripped), parseError: null, raw: inner };
  } catch (err) {
    // Last-ditch: pull the first {...} block out of the text.
    const first = stripped.indexOf("{");
    const last = stripped.lastIndexOf("}");
    if (first !== -1 && last > first) {
      try {
        return { parsed: JSON.parse(stripped.slice(first, last + 1)), parseError: null, raw: inner };
      } catch {
        // fall through
      }
    }
    return { parsed: null, parseError: err.message, raw: inner };
  }
}

function severityRank(severity) {
  switch (severity) {
    case "critical": return 0;
    case "high":     return 1;
    case "medium":   return 2;
    default:         return 3;
  }
}

function formatLineRange(finding) {
  if (!finding.line_start) return "";
  if (!finding.line_end || finding.line_end === finding.line_start) return `:${finding.line_start}`;
  return `:${finding.line_start}-${finding.line_end}`;
}

function validateReviewShape(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return "Expected a top-level JSON object.";
  if (typeof data.verdict !== "string" || !data.verdict.trim()) return "Missing string `verdict`.";
  if (typeof data.summary !== "string" || !data.summary.trim()) return "Missing string `summary`.";
  if (!Array.isArray(data.findings)) return "Missing array `findings`.";
  if (!Array.isArray(data.next_steps)) return "Missing array `next_steps`.";
  return null;
}

function normalizeFinding(source, index) {
  const src = source && typeof source === "object" && !Array.isArray(source) ? source : {};
  const lineStart = Number.isInteger(src.line_start) && src.line_start > 0 ? src.line_start : null;
  const lineEnd =
    Number.isInteger(src.line_end) && src.line_end > 0 && (!lineStart || src.line_end >= lineStart)
      ? src.line_end
      : lineStart;
  return {
    severity: typeof src.severity === "string" && src.severity.trim() ? src.severity.trim() : "low",
    title: typeof src.title === "string" && src.title.trim() ? src.title.trim() : `Finding ${index + 1}`,
    body: typeof src.body === "string" && src.body.trim() ? src.body.trim() : "No details provided.",
    file: typeof src.file === "string" && src.file.trim() ? src.file.trim() : "unknown",
    line_start: lineStart,
    line_end: lineEnd,
    confidence: typeof src.confidence === "number" ? src.confidence : null,
    recommendation: typeof src.recommendation === "string" ? src.recommendation.trim() : ""
  };
}

function renderStructured(reviewLabel, targetLabel, data) {
  const findings = [...data.findings].map(normalizeFinding).sort(
    (a, b) => severityRank(a.severity) - severityRank(b.severity)
  );
  const lines = [
    `# Ollama ${reviewLabel}`,
    "",
    `Target: ${targetLabel}`,
    `Verdict: ${data.verdict}`,
    "",
    data.summary.trim(),
    ""
  ];
  if (findings.length === 0) {
    lines.push("No material findings.");
  } else {
    lines.push("Findings:");
    for (const f of findings) {
      lines.push(`- [${f.severity}] ${f.title} (${f.file}${formatLineRange(f)})`);
      lines.push(`  ${f.body}`);
      if (f.recommendation) lines.push(`  Recommendation: ${f.recommendation}`);
    }
  }
  const nextSteps = data.next_steps.filter((s) => typeof s === "string" && s.trim()).map((s) => s.trim());
  if (nextSteps.length > 0) {
    lines.push("", "Next steps:");
    for (const step of nextSteps) lines.push(`- ${step}`);
  }
  return lines.join("\n").trimEnd() + "\n";
}

function renderRawFallback(reviewLabel, targetLabel, raw, parseError) {
  const lines = [
    `# Ollama ${reviewLabel}`,
    "",
    `Target: ${targetLabel}`,
    "",
    "Raw model output (schema parse failed):",
    "",
    `- Parse error: ${parseError}`,
    "",
    "```text",
    (raw || "").trim() || "(no output)",
    "```"
  ];
  return lines.join("\n").trimEnd() + "\n";
}

function renderClaudeFailure(reviewLabel, targetLabel, status, stderr) {
  const lines = [
    `# Ollama ${reviewLabel}`,
    "",
    `Target: ${targetLabel}`,
    "",
    `claude headless exited with status ${status}.`,
    "",
    "stderr:",
    "",
    "```text",
    stderr.trim() || "(empty)",
    "```",
    "",
    "Run `/ollama:setup` to verify the Ollama daemon, model, and Claude CLI are wired up correctly."
  ];
  return lines.join("\n").trimEnd() + "\n";
}

// ---------------------------------------------------------------------------
// Subcommand: review / adversarial-review
// ---------------------------------------------------------------------------

function readEnv() {
  const model = process.env.OLLAMA_REVIEW_MODEL?.trim();
  if (!model) {
    throw new Error(
      "OLLAMA_REVIEW_MODEL is not set. Export it to the Ollama tag you want to review with " +
        "(e.g. `export OLLAMA_REVIEW_MODEL=qwen3-coder:30b`) and retry. Run `/ollama:setup` for a checklist."
    );
  }
  const baseUrl = (process.env.OLLAMA_BASE_URL?.trim() || DEFAULT_BASE_URL).replace(/\/+$/, "");
  const claudeBin = process.env.OLLAMA_CLAUDE_BIN?.trim() || DEFAULT_CLAUDE_BIN;
  return { model, baseUrl, claudeBin };
}

async function runReviewSubcommand(promptName, reviewLabel, rawArgv) {
  const env = readEnv();
  const { scope, baseRef, focus } = parseReviewArgs(rawArgv);
  const cwd = process.cwd();
  const target = resolveReviewTarget(cwd, { scope, baseRef });
  const context = collectReviewContext(cwd, target);
  const prompt = buildPrompt(promptName, target, context, focus);
  const timeoutMs = promptName === "adversarial-review" ? ADVERSARIAL_REVIEW_TIMEOUT_MS : REVIEW_TIMEOUT_MS;

  const result = await invokeClaudeHeadless(prompt, env.model, env.baseUrl, env.claudeBin, timeoutMs);
  if (result.status !== 0) {
    let hint = "";
    const r = extractResultEvent(result.stdout);
    if (r?.subtype) hint = ` (${r.subtype})`;
    process.stdout.write(renderClaudeFailure(reviewLabel, target.label, result.status, result.stderr + hint));
    process.exitCode = 1;
    return;
  }

  const { inner, envelopeParseError } = parseClaudeEnvelope(result.stdout);
  const parsed = parseModelJson(inner);
  if (!parsed.parsed) {
    const parseError = parsed.parseError + (envelopeParseError ? ` (envelope: ${envelopeParseError})` : "");
    process.stdout.write(renderRawFallback(reviewLabel, target.label, parsed.raw, parseError));
    return;
  }
  const shapeError = validateReviewShape(parsed.parsed);
  if (shapeError) {
    process.stdout.write(renderRawFallback(reviewLabel, target.label, parsed.raw, shapeError));
    return;
  }
  process.stdout.write(renderStructured(reviewLabel, target.label, parsed.parsed));
}

// ---------------------------------------------------------------------------
// Subcommand: setup
// ---------------------------------------------------------------------------

async function probeBaseUrl(baseUrl, pathSuffix) {
  const url = `${baseUrl}${pathSuffix}`;
  try {
    const res = await fetch(url, { method: "GET", signal: AbortSignal.timeout(5000) });
    return { ok: res.ok, status: res.status, url };
  } catch (err) {
    return { ok: false, status: 0, url, error: err.message };
  }
}

async function probeMessagesEndpoint(baseUrl, model) {
  const url = `${baseUrl}/v1/messages`;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model, max_tokens: 1, messages: [{ role: "user", content: "ping" }] }),
      signal: AbortSignal.timeout(15000)
    });
    return { ok: res.ok, status: res.status, url };
  } catch (err) {
    return { ok: false, status: 0, url, error: err.message };
  }
}

async function listOllamaTags(baseUrl) {
  try {
    const res = await fetch(`${baseUrl}/api/tags`, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return null;
    const body = await res.json();
    return Array.isArray(body?.models) ? body.models.map((m) => m.name).filter(Boolean) : [];
  } catch {
    return null;
  }
}

async function runSetupSubcommand(rawArgv) {
  const argv = flattenRawArgs(rawArgv);
  const wantJson = argv.includes("--json");

  const baseUrl = (process.env.OLLAMA_BASE_URL?.trim() || DEFAULT_BASE_URL).replace(/\/+$/, "");
  const claudeBin = process.env.OLLAMA_CLAUDE_BIN?.trim() || DEFAULT_CLAUDE_BIN;
  const requestedModel = process.env.OLLAMA_REVIEW_MODEL?.trim() || null;

  const checks = {};

  // claude CLI
  const claudeVersion = runSync(claudeBin, ["--version"]);
  checks.claudeCli = {
    ok: !claudeVersion.error && claudeVersion.status === 0,
    detail: claudeVersion.error
      ? `not found at "${claudeBin}" (${claudeVersion.error.code})`
      : (claudeVersion.stdout || "").trim() || `exit ${claudeVersion.status}`
  };

  // model env
  checks.model = {
    ok: !!requestedModel,
    detail: requestedModel ? requestedModel : "OLLAMA_REVIEW_MODEL is not set"
  };

  // ollama daemon (/api/tags)
  const tagsProbe = await probeBaseUrl(baseUrl, "/api/tags");
  checks.ollamaDaemon = {
    ok: tagsProbe.ok,
    detail: tagsProbe.ok
      ? `reachable at ${tagsProbe.url}`
      : `unreachable at ${tagsProbe.url}${tagsProbe.error ? ` — ${tagsProbe.error}` : ` (HTTP ${tagsProbe.status})`}`
  };

  // model present in tag list
  if (tagsProbe.ok && requestedModel) {
    const tags = await listOllamaTags(baseUrl);
    if (tags === null) {
      checks.modelPulled = { ok: false, detail: "could not list /api/tags response" };
    } else {
      const present = tags.includes(requestedModel) || tags.some((t) => t.split(":")[0] === requestedModel);
      checks.modelPulled = {
        ok: present,
        detail: present
          ? `found in ollama tag list`
          : `not pulled — run \`ollama pull ${requestedModel}\``
      };
    }
  } else {
    checks.modelPulled = { ok: false, detail: "skipped (daemon unreachable or model unset)" };
  }

  // /v1/messages compatibility surface
  if (tagsProbe.ok && requestedModel) {
    const msg = await probeMessagesEndpoint(baseUrl, requestedModel);
    checks.anthropicCompat = {
      ok: msg.ok,
      detail: msg.ok
        ? `responded at ${msg.url}`
        : `failed at ${msg.url}${msg.error ? ` — ${msg.error}` : ` (HTTP ${msg.status})`} — Ollama ≥ 0.14 is required, or use a LiteLLM/claude-code-router proxy`
    };
  } else {
    checks.anthropicCompat = { ok: false, detail: "skipped (daemon unreachable or model unset)" };
  }

  const allOk = Object.values(checks).every((c) => c.ok);
  const report = {
    ready: allOk,
    baseUrl,
    claudeBin,
    model: requestedModel,
    checks,
    envSample: [
      `export OLLAMA_REVIEW_MODEL=${requestedModel ?? "qwen3-coder:30b"}`,
      `export OLLAMA_BASE_URL=${baseUrl}`,
      `# export OLLAMA_CLAUDE_BIN=${claudeBin}`
    ]
  };

  if (wantJson) {
    process.stdout.write(JSON.stringify(report, null, 2) + "\n");
    process.exitCode = allOk ? 0 : 1;
    return;
  }

  const lines = [
    "# Ollama Review Setup",
    "",
    `Status: ${allOk ? "ready" : "needs attention"}`,
    `Ollama base URL: ${baseUrl}`,
    `Claude CLI: ${claudeBin}`,
    `Review model: ${requestedModel ?? "(unset)"}`,
    "",
    "Checks:",
    `- claude CLI: ${checks.claudeCli.detail}`,
    `- review model env: ${checks.model.detail}`,
    `- ollama daemon: ${checks.ollamaDaemon.detail}`,
    `- model pulled: ${checks.modelPulled.detail}`,
    `- anthropic-compat /v1/messages: ${checks.anthropicCompat.detail}`,
    "",
    "Sample env block:",
    "",
    "```bash",
    ...report.envSample,
    "```"
  ];
  if (!allOk) {
    lines.push("", "Resolve the failing checks before running `/ollama:review` or `/ollama:adversarial-review`.");
    lines.push("Ollama install/upgrade: https://ollama.com");
  }
  process.stdout.write(lines.join("\n") + "\n");
  process.exitCode = allOk ? 0 : 1;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

function printUsage() {
  process.stderr.write(
    [
      "Usage:",
      "  node ollama-companion.mjs setup [--json]",
      "  node ollama-companion.mjs review [--wait|--background] [--base <ref>] [--scope <auto|working-tree|branch>] [focus text]",
      "  node ollama-companion.mjs adversarial-review [--wait|--background] [--base <ref>] [--scope <auto|working-tree|branch>] [focus text]",
      "",
      "Required env: OLLAMA_REVIEW_MODEL (Ollama tag).",
      "Optional env: OLLAMA_BASE_URL (default http://localhost:11434), OLLAMA_CLAUDE_BIN (default claude)."
    ].join("\n") + "\n"
  );
}

async function main() {
  const [, , subcommand, ...rest] = process.argv;
  try {
    switch (subcommand) {
      case "setup":
        await runSetupSubcommand(rest);
        return;
      case "review":
        await runReviewSubcommand("review", "Review", rest);
        return;
      case "adversarial-review":
        await runReviewSubcommand("adversarial-review", "Adversarial Review", rest);
        return;
      case undefined:
      case "--help":
      case "-h":
        printUsage();
        process.exitCode = subcommand ? 0 : 1;
        return;
      default:
        process.stderr.write(`Unknown subcommand: ${subcommand}\n`);
        printUsage();
        process.exitCode = 1;
    }
  } catch (err) {
    process.stderr.write(`${err.message}\n`);
    process.exitCode = 1;
  }
}

main();
