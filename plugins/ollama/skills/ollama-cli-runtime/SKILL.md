---
name: ollama-cli-runtime
description: Internal helper contract for calling the ollama-companion runtime from Claude Code
user-invocable: false
---

# Ollama Runtime

Use this skill only inside other skills or agents that delegate review work to the local-LLM Ollama runtime. End users invoke `/ollama:review`, `/ollama:adversarial-review`, or `/ollama:setup` directly — they should not see this skill.

Primary helpers:
- `node "${CLAUDE_PLUGIN_ROOT}/scripts/ollama-companion.mjs" review "<raw arguments>"`
- `node "${CLAUDE_PLUGIN_ROOT}/scripts/ollama-companion.mjs" adversarial-review "<raw arguments>"`
- `node "${CLAUDE_PLUGIN_ROOT}/scripts/ollama-companion.mjs" setup [--json]`

Execution rules:
- The runtime is one-shot. There is no `task`, no `--write`, no `--resume`, no model alias map, and no job-control surface (`status`, `result`, `cancel`). If you need any of those, use the `codex` plugin instead.
- Reviews are read-only by construction. The companion spawns `claude -p` with `--allowedTools ""` and `--strict-mcp-config`, so the local model cannot edit files even if it tried.
- Do not call the script directly from an agent that is also expected to consume the output structurally. Always treat the script's stdout as a finished artifact for the user.
- Pass the user's arguments through unchanged after stripping any routing flags your skill owns.
- `--wait` and `--background` are routing flags handled by the calling skill, not the script. The script ignores them.
- The companion always uses the model specified by `OLLAMA_REVIEW_MODEL`. Do not try to override per-call — the script does not accept a `--model` flag.

Environment contract (set by the user, read by the script):
- `OLLAMA_REVIEW_MODEL` — required. The Ollama tag (e.g. `qwen3-coder:30b`).
- `OLLAMA_BASE_URL` — optional. Default `http://localhost:11434`.
- `OLLAMA_CLAUDE_BIN` — optional. Path to the Claude CLI; default `claude` on `PATH`.

The script injects per-invocation env when spawning Claude:
- `ANTHROPIC_BASE_URL=$OLLAMA_BASE_URL`
- `ANTHROPIC_API_KEY=""`
- `ANTHROPIC_AUTH_TOKEN=ollama`
- `ANTHROPIC_DEFAULT_{HAIKU,SONNET,OPUS}_MODEL=$OLLAMA_REVIEW_MODEL`

Do not duplicate that wiring in the calling skill — let the script own it. If the user needs different env, they set it in their shell before invoking the slash command.

Safety rules:
- Do not catch the script's exit codes and substitute your own success message.
- Do not re-render or re-parse the script's stdout. Pass it to the user verbatim.
- If the Bash call fails to spawn `node`, surface the original error message; do not invent one.
