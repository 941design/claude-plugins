# ollama plugin

Local-LLM code review skills for Claude Code. Mirrors the [`codex`](https://github.com/941design/claude-plugins) plugin's `review` / `adversarial-review` / `setup` surface, but routes the prompt through the user's local **Claude Code CLI in headless mode**, with `ANTHROPIC_BASE_URL` pointed at a locally-served **Ollama** model (`qwen3-coder:30b`, `qwen3:32b`, or whatever you choose).

The point: a private, offline-capable second opinion that drops into the same call sites in `base` (`integration-architect`, `verification-examiner`, the `feature` workflow) where `/codex:*` is wired in today.

## Skills

| Skill                              | Purpose                                                                 |
|------------------------------------|-------------------------------------------------------------------------|
| `/ollama:review`                   | Code review of local git state (working tree or branch diff).           |
| `/ollama:adversarial-review`       | Same target selection, but adversarial framing + optional focus text.   |
| `/ollama:setup`                    | Verify Ollama, model, and Claude CLI are wired up. **Run this first.**  |
| `ollama:ollama-cli-runtime`        | Internal advisory — calling convention for other skills/agents.         |
| `ollama:ollama-result-handling`    | Internal advisory — how to present the script's output.                 |

## Prerequisites

1. **Ollama ≥ 0.14** running locally (the version that exposes the Anthropic-compatible `/v1/messages` endpoint). Install or upgrade from <https://ollama.com>.
2. **A pulled model.** No default is shipped — pick one your hardware supports:
   ```bash
   ollama pull qwen3-coder:30b
   ```
3. **Claude Code CLI** on `PATH` (the same `claude` binary you already use).
4. **Environment**:
   ```bash
   export OLLAMA_REVIEW_MODEL=qwen3-coder:30b   # required
   export OLLAMA_BASE_URL=http://localhost:11434  # optional, default
   # export OLLAMA_CLAUDE_BIN=/path/to/claude     # optional, default `claude`
   ```

Then run `/ollama:setup` to verify. The setup skill checks daemon reachability, model presence, and the `/v1/messages` compatibility surface, and exits non-zero if anything is missing.

## How it works

The companion script (`scripts/ollama-companion.mjs`) does the work:

1. Resolves the git scope — working tree, branch, or explicit `--base <ref>`.
2. Collects the diff + untracked-file context (mirroring the codex plugin's logic).
3. Loads the matching prompt template (`prompts/review.md` or `prompts/adversarial-review.md`), interpolates target label / user focus / review input.
4. Appends the `schemas/review-output.schema.json` schema and a hard "JSON only" instruction.
5. Spawns `claude -p <prompt> --model $OLLAMA_REVIEW_MODEL --output-format json --max-turns 1 --allowedTools "" --strict-mcp-config` with the Ollama env vars injected:
   ```
   ANTHROPIC_BASE_URL=$OLLAMA_BASE_URL
   ANTHROPIC_API_KEY=""
   ANTHROPIC_AUTH_TOKEN=ollama
   ANTHROPIC_DEFAULT_{HAIKU,SONNET,OPUS}_MODEL=$OLLAMA_REVIEW_MODEL
   ```
6. Parses the two-layer JSON (claude envelope → model JSON), falls back to a `Raw model output (schema parse failed)` block if the local model didn't honor the schema, and renders findings sorted by severity.

There is no app-server broker, no job queue, and no `--write` mode. Reviews are read-only by construction.

## Limitations and caveats

- **Sandbox-untestable.** This plugin was built without a live Ollama instance available. The companion script's defensive checks (especially in `/ollama:setup`) are how first-use failures fail loudly with actionable errors instead of producing garbage. Validate end-to-end on your own machine before depending on it.
- **Schema discipline depends on the model.** Smaller / general-purpose models may produce prose around or instead of JSON. The script's raw-output fallback is the safety net; if you see it constantly, switch to a coder-tuned or larger Qwen3 variant.
- **No tools, no MCP.** The headless run is launched with `--allowedTools ""` and `--strict-mcp-config`, so the local model cannot read files, call tools, or trigger MCP servers. The diff is in the prompt or it isn't reviewed.
- **Codex stays in the picture.** This plugin doesn't replace codex — it supplements it. `/codex:rescue` (write-capable, iterative) has no Ollama equivalent here. Use both: codex for cloud-based stronger-reasoning passes, ollama for private/offline second opinions.

## Troubleshooting

| Symptom                                                    | Likely cause                                                      | Fix                                                              |
|------------------------------------------------------------|-------------------------------------------------------------------|------------------------------------------------------------------|
| `OLLAMA_REVIEW_MODEL is not set`                           | Env var missing.                                                  | `export OLLAMA_REVIEW_MODEL=<tag>`                               |
| `/ollama:setup` says daemon unreachable                    | `ollama serve` not running, or `OLLAMA_BASE_URL` points elsewhere.| Start ollama, or correct `OLLAMA_BASE_URL`.                      |
| `/ollama:setup` says `/v1/messages` failed                 | Ollama < 0.14, or proxy in the way.                               | Upgrade Ollama, or stand up a LiteLLM/claude-code-router proxy.  |
| `Raw model output (schema parse failed)` every run         | Model isn't disciplined enough about JSON.                        | Try a bigger or coder-tuned tag (e.g. `qwen3-coder:30b`).        |
| `claude headless exited with status N`                     | Auth env mishandled, or claude CLI version mismatch.              | Run `/ollama:setup`, check `ANTHROPIC_API_KEY=""` (empty).       |

## Layout

```
plugins/ollama/
├── .claude-plugin/plugin.json
├── README.md
├── prompts/
│   ├── review.md              # neutral framing
│   └── adversarial-review.md  # verbatim from codex
├── schemas/
│   └── review-output.schema.json
├── scripts/
│   └── ollama-companion.mjs
└── skills/
    ├── adversarial-review/SKILL.md
    ├── ollama-cli-runtime/SKILL.md
    ├── ollama-result-handling/SKILL.md
    ├── review/SKILL.md
    └── setup/SKILL.md
```
