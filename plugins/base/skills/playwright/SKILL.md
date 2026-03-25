---
name: playwright
description: >-
  Browser automation and web interaction. Navigate URLs, click elements, fill
  forms, take screenshots, extract page content, test web applications, and
  perform end-to-end browser interactions using Playwright MCP.
argument-hint: "[browser task to perform]"
allowed-tools: Read, Grep, Glob, Write, Edit, WebFetch, WebSearch, Bash, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_close, mcp__plugin_playwright_playwright__browser_console_messages, mcp__plugin_playwright_playwright__browser_drag, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_file_upload, mcp__plugin_playwright_playwright__browser_fill_form, mcp__plugin_playwright_playwright__browser_handle_dialog, mcp__plugin_playwright_playwright__browser_hover, mcp__plugin_playwright_playwright__browser_install, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_navigate_back, mcp__plugin_playwright_playwright__browser_network_requests, mcp__plugin_playwright_playwright__browser_press_key, mcp__plugin_playwright_playwright__browser_resize, mcp__plugin_playwright_playwright__browser_run_code, mcp__plugin_playwright_playwright__browser_select_option, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_tabs, mcp__plugin_playwright_playwright__browser_take_screenshot, mcp__plugin_playwright_playwright__browser_type, mcp__plugin_playwright_playwright__browser_wait_for
context: fork
agent: playwright-browser
---

## Freshness Gate

Current Unix timestamp: !`date +%s`

Read your MEMORY.md and find the `last_fetch_date` value. If it does not
exist, or if the current timestamp minus `last_fetch_date` exceeds **604800**
(7 days), you MUST run a knowledge refresh before executing. Follow the
refresh procedure described in your agent system prompt (fetch Playwright MCP
docs, write findings to agent memory only — never modify plugin files).

If memory is fresh, proceed directly to execution.

## User Request

$ARGUMENTS

## Execution Guidelines

- **Execute, don't explain.** Perform the browser actions directly. Users want
  results, not descriptions of what you plan to do.
- Check your agent memory for site-specific patterns, known selector strategies,
  and workarounds before attempting the task.
- Prefer `browser_snapshot` over `browser_take_screenshot` to conserve context
  unless the user explicitly requests a screenshot or visual verification is
  needed.
- After completing the task, update your agent memory with any new patterns,
  selector strategies, or site quirks discovered during this session.
