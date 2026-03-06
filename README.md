# 941design Claude Plugins

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin
marketplace by [941design](https://github.com/941design). Focused on
developer tools for decentralized protocols and privacy-first systems.

## Plugins

| Plugin | Description |
|---|---|
| [nostr-skills](plugins/nostr-skills/) | [Marmot Protocol](https://github.com/marmot-protocol/marmot) implementation advisor — [MDK](https://github.com/parres-hq/mdk), [marmot-ts](https://github.com/marmot-protocol/marmot-ts), [WhiteNoise](https://github.com/marmot-protocol/whitenoise-rs) |

## Installation

```bash
# 1. Register the marketplace (one-time)
/plugin marketplace add 941design/claude-plugins

# 2. Install a plugin
/plugin install nostr-skills@941design
```

## Adding Plugins

Each plugin lives in its own directory under `plugins/`:

```
plugins/
└── my-new-plugin/
    ├── .claude-plugin/
    │   └── plugin.json
    ├── skills/
    │   └── ...
    └── README.md
```

Register the plugin in `.claude-plugin/marketplace.json` and add a row to
the table above.

## Repository Structure

```
claude-plugins/
├── .claude-plugin/
│   ├── plugin.json              # Marketplace root manifest
│   └── marketplace.json         # Plugin registry
├── plugins/
│   └── nostr-skills/            # Marmot Protocol advisor
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── agents/              # Custom agent (memory: user)
│       ├── skills/              # Read-only reference + skill prompts
│       └── README.md            # Plugin documentation
└── README.md
```

## Development

Load a plugin directly during development:

```bash
claude --plugin-dir ./plugins/nostr-skills
```

## License

MIT
