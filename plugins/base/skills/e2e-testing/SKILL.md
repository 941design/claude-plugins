---
name: e2e-testing
description: >-
  Run e2e tests iteratively one at a time using Playwright MCP. Only proceeds to
  the next test when the current test passes. Reports failure immediately on
  first failing test. Use for end-to-end test verification after feature
  implementation or as a quality gate.
user-invocable: false
context: fork
agent: e2e-tester
allowed-tools: Read, Grep, Glob, Bash, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_console_messages, mcp__plugin_playwright_playwright__browser_drag, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_file_upload, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_handle_dialog, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_install, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_navigate_back, mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_press_key, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_run_code, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_tabs, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_wait_for
---

## E2E Test Execution

Run the following e2e tests iteratively, one at a time. Only proceed to the next
test if the current test passes. If any test fails, stop immediately and report
the failure.

Before running, load your project memory (`~/.claude/agent-memory/base-e2e-tester/`)
for stack-specific commands, container names, helpers, and known gotchas — these
override generic defaults.

For any run covering more than ~10 tests, pass `--max-failures=1` (or the
runner's equivalent). Sequential e2e suites cascade failures from a single root
cause; letting the run continue burns time confirming what triage would tell
you in minutes.

$ARGUMENTS
