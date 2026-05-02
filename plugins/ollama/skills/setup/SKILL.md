---
name: setup
description: Verify the Ollama daemon is reachable, the configured review model is pulled, the Anthropic-compatibility endpoint responds, and the Claude CLI is wired up for local-LLM review. Run this before /ollama:review or /ollama:adversarial-review.
argument-hint: '[--json]'
allowed-tools: Bash(node:*)
---

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/ollama-companion.mjs" setup $ARGUMENTS
```

Output rules:
- Present the script's setup output to the user verbatim.
- Do not interpret, summarize, or fix anything in this turn.
- The script returns exit 0 when ready, exit 1 when one or more checks failed; preserve that signal in your response framing.

Remediation guidance:
- If the script says the Ollama daemon is unreachable, the user needs to start `ollama serve` (or upgrade Ollama from https://ollama.com if they don't have a recent enough version).
- If the script says the model is not pulled, the user needs to `ollama pull <model-tag>`.
- If the script says the Anthropic-compatibility surface failed, the user is on a pre-0.14 Ollama and either needs to upgrade or stand up a translating proxy (LiteLLM or claude-code-router) and point `OLLAMA_BASE_URL` at it.
- If the script says `OLLAMA_REVIEW_MODEL` is unset, the user needs to export it to the Ollama tag they want to review with — e.g. `export OLLAMA_REVIEW_MODEL=qwen3-coder:30b`. The skill is intentionally model-agnostic; pick one your hardware supports.

Do not attempt to install Ollama from this skill — installation is platform-specific and beyond the script's scope.
