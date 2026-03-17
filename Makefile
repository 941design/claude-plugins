.PHONY: release-major release-minor release-patch version

PLUGIN_JSON := plugins/nostr-skills/.claude-plugin/plugin.json
MARKETPLACE_JSON := .claude-plugin/marketplace.json

# Extract current version from the plugin manifest
VERSION := $(shell sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' $(PLUGIN_JSON) | head -1)
MAJOR := $(word 1,$(subst ., ,$(VERSION)))
MINOR := $(word 2,$(subst ., ,$(VERSION)))
PATCH := $(word 3,$(subst ., ,$(VERSION)))

version:
	@echo $(VERSION)

release-major:
	$(eval NEW := $(shell echo $$(($(MAJOR)+1))).0.0)
	@$(MAKE) _release NEW_VERSION=$(NEW)

release-minor:
	$(eval NEW := $(shell echo $(MAJOR).$$(($(MINOR)+1)).0))
	@$(MAKE) _release NEW_VERSION=$(NEW)

release-patch:
	$(eval NEW := $(shell echo $(MAJOR).$(MINOR).$$(($(PATCH)+1))))
	@$(MAKE) _release NEW_VERSION=$(NEW)

_release:
ifndef NEW_VERSION
	$(error NEW_VERSION is not set)
endif
	@echo "Releasing nostr-skills v$(NEW_VERSION) (was $(VERSION))"
	@# Update plugin manifest
	@sed -i 's/"version": *"$(VERSION)"/"version": "$(NEW_VERSION)"/' $(PLUGIN_JSON)
	@# Update marketplace registry
	@sed -i 's/"version": *"$(VERSION)"/"version": "$(NEW_VERSION)"/' $(MARKETPLACE_JSON)
	@# Stage, commit, tag
	@git add $(PLUGIN_JSON) $(MARKETPLACE_JSON)
	@git commit -m "Release nostr-skills v$(NEW_VERSION)"
	@git tag -a "nostr-skills/v$(NEW_VERSION)" -m "nostr-skills v$(NEW_VERSION)"
	@echo "Tagged nostr-skills/v$(NEW_VERSION)"
	@echo "Run 'git push && git push --tags' to publish."
