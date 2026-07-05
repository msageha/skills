CLAUDE_SKILLS_DIR   := $(HOME)/.claude/skills
CODEX_SKILLS_DIR    := $(HOME)/.codex/skills
AGY_SKILLS_DIR      := $(HOME)/.gemini/antigravity-cli/skills
OPENCLAW_SKILLS_DIR := $(HOME)/.openclaw/workspace/skills

SKILLS := $(patsubst %/SKILL.md,%,$(wildcard */SKILL.md))

define install_skills
	mkdir -p "$(1)"
	for skill in $(SKILLS); do \
		ln -sfn "$(CURDIR)/$$skill" "$(1)/$$skill"; \
		echo "linked $$skill -> $(1)/$$skill"; \
	done
endef

# openclaw の workspace スキルローダーは symlink を辿らないため、コピーで配置する。
define copy_skills
	mkdir -p "$(1)"
	for skill in $(SKILLS); do \
		rm -rf "$(1)/$$skill"; \
		cp -R "$(CURDIR)/$$skill" "$(1)/$$skill"; \
		echo "copied $$skill -> $(1)/$$skill"; \
	done
endef

.PHONY: install-claude install-codex install-agy install-openclaw

install-claude:
	$(call install_skills,$(CLAUDE_SKILLS_DIR))

install-codex:
	$(call install_skills,$(CODEX_SKILLS_DIR))

install-agy:
	$(call install_skills,$(AGY_SKILLS_DIR))

install-openclaw:
	$(call copy_skills,$(OPENCLAW_SKILLS_DIR))
