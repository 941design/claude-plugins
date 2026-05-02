---
name: ollama-result-handling
description: Internal guidance for presenting ollama-companion output back to the user
user-invocable: false
---

# Ollama Result Handling

When the helper returns review output:
- Preserve the helper's verdict, summary, findings, and next-steps structure.
- Present findings first and keep them ordered by severity (the script already does this — do not re-sort).
- Use the file paths and line numbers exactly as the helper reports them.
- Preserve evidence boundaries. If the model marked something as an inference or uncertain, keep that distinction in the rendered output.
- If there are no findings, say that explicitly and keep any residual-risk note brief.
- The script never makes edits — there is no `--write` mode. Do not claim files were touched.
- CRITICAL: After presenting review findings, STOP. Do not make any code changes. Do not fix any issues. You MUST explicitly ask the user which issues, if any, they want fixed before touching a single file. Auto-applying fixes from a review is strictly forbidden, even if the fix is obvious.

Schema-parse failure mode:
- The local Ollama model may not always return clean JSON matching the review schema. When that happens, the script renders a `Raw model output (schema parse failed)` block instead of the structured findings sections.
- This is intentional and expected for some models. Show the raw output as-is — do not try to interpret, reformat, or extract findings from it.
- If raw-output fallback is the norm rather than the exception for a given model, suggest the user try a stronger or more JSON-disciplined Ollama tag (e.g. swap a small variant for `qwen3-coder:30b`).

Failure modes to surface verbatim:
- If the helper reports `claude headless exited with status N` with stderr included, present that block as-is and direct the user to `/ollama:setup` and do not improvise alternate auth flows.
- If the helper reports `OLLAMA_REVIEW_MODEL is not set` or any other preflight failure, direct the user to `/ollama:setup` and stop.
- If the Bash call itself fails (script not found, node missing), include the most actionable stderr lines and stop instead of guessing.

Comparison to codex:
- This runtime is read-only and one-shot. Behavior that the codex plugin's `codex-result-handling` skill describes for `--write` task runs, resumed sessions, or background-job result-fetching does not apply here. If the user wants those, route them to `/codex:rescue`, `/codex:review`, or `/codex:adversarial-review` instead.
