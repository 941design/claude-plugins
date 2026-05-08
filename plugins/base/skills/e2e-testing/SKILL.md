---
name: e2e-testing
description: |-
  Run long-running test suites sequentially, one test at a time, stopping
  on the first failure so a single root cause doesn't cascade through the
  rest of the run. Re-runs previously failed tests first so regressions
  surface fastest.

  ALWAYS use this skill before kicking off an e2e or other long-running
  suite. Do not invoke the runner directly via Bash — that skips the
  sequential discipline and fail-first ordering this skill provides.

  TRIGGER when: about to run an e2e, integration, or other long-running
  test suite (Playwright, Cypress, WebdriverIO, etc.); user says "run the
  e2e tests", "verify e2e", "check the suite", or names a suite to run;
  quality-gating a feature after implementation; re-running a previously
  failing test. Agent self-detected uncertainty about whether a run
  qualifies is itself sufficient to trigger.

  SKIP when: running fast unit-test suites; one-off interactive debugging
  where sequential execution adds no value; user explicitly asks to bypass
  sequential execution.
user-invocable: false
context: fork
agent: e2e-tester
allowed-tools: Read, Grep, Glob, Bash, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_console_messages, mcp__plugin_playwright_playwright__browser_drag, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_file_upload, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_handle_dialog, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_install, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_navigate_back, mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_press_key, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_run_code, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_tabs, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_wait_for
---

## E2E Test Execution

Run e2e tests iteratively, one at a time. Stop immediately on the first
failure and report it.

Goal: surface a failing test as fast as possible. Unless the user named a
specific test or file, run previously failed tests first using whatever
rerun-failed mechanism the runner provides (e.g. Playwright
`--last-failed`, Jest `--onlyFailures`, or a cached failure list). If no
prior-failure signal is available, fall back to the suite's natural order.

Before running, load your project memory (`~/.claude/agent-memory/base-e2e-tester/`)
for stack-specific commands, container names, helpers, and known gotchas — these
override generic defaults.

For any run covering more than ~10 tests, pass `--max-failures=1` (or the
runner's equivalent). Sequential e2e suites cascade failures from a single root
cause; letting the run continue burns time confirming what triage would tell
you in minutes.

Do not reach for `.skip`, `.only`, `test.fixme`, or commenting tests out to
make a run go green. Skipped tests rot — they drift out of sync with the code,
nobody notices when the underlying bug regresses, and the suite quietly loses
coverage. A failing test is a useful signal: surface it, report it, and let
the user decide whether to fix the code, fix the test, or delete it
deliberately. Silencing the signal is not your call to make.

$ARGUMENTS
