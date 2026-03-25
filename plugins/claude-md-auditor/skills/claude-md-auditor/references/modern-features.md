# Modern Claude Code Features

## Table of Contents

- [Rules Directory](#rules-directory)
- [Path-Specific Rules](#path-specific-rules)
- [File Imports](#file-imports)
- [claudeMdExcludes](#claudemdexcludes)
- [Organization-Managed CLAUDE.md](#organization-managed-claudemd)
- [Auto Memory vs CLAUDE.md](#auto-memory-vs-claudemd)
- [CLAUDE.md vs Hooks vs Skills](#claudemd-vs-hooks-vs-skills)
- [Size Guidelines](#size-guidelines)

---

## Rules Directory

For projects where a single CLAUDE.md grows beyond ~200 lines, split instructions into modular files under `.claude/rules/`:

```
.claude/
├── CLAUDE.md              # Core project context (concise)
└── rules/
    ├── code-style.md      # Naming, formatting, patterns
    ├── testing.md         # Test conventions and commands
    ├── api-design.md      # API endpoint standards
    └── frontend/
        └── components.md  # UI component patterns
```

Rules without `paths` frontmatter load at session start (same as CLAUDE.md). Rules with `paths` frontmatter load on-demand only when Claude reads matching files, saving context space.

When to recommend `.claude/rules/`:

- CLAUDE.md is over 200 lines and covers multiple distinct domains
- Different team members own different sections (rules can be reviewed independently)
- Some instructions only apply to specific file types (use path-specific rules)

## Path-Specific Rules

Rules can be scoped to file patterns using YAML frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/routes/**/*.ts"
---

# API Development Rules

- Include input validation for all endpoints
- Use standard error response format from `src/lib/errors.ts`
- Include OpenAPI documentation comments on handler functions
```

Claude only loads this rule when reading files matching those patterns. This is more efficient than putting everything in root CLAUDE.md, because API rules don't consume context when working on frontend code.

Multiple patterns use glob syntax: `*` matches within a directory, `**` matches recursively.

## File Imports

CLAUDE.md can reference external files with `@path` syntax to pull in content without duplicating it:

```markdown
# Project Overview

See @README.md for full project description.

## Commands

See @docs/development-guide.md for all available commands.

## Personal Overrides

@~/.claude/my-project-prefs.md
```

Paths resolve relative to the importing file's directory. Maximum import depth is 5 hops (to prevent circular references). This keeps CLAUDE.md concise while allowing:

- Personal overrides via user-home paths
- Reuse of existing documentation (README, contributing guides)
- Team members to customize without changing shared files

When to recommend `@imports`:

- The CLAUDE.md is repeating content that exists in other files
- There's a README or contributing guide that already documents commands/architecture
- Team members want personal additions without forking shared CLAUDE.md

## claudeMdExcludes

In large monorepos, Claude auto-discovers CLAUDE.md files in all ancestor and child directories. This can load irrelevant context. Use `claudeMdExcludes` in `.claude/settings.json` to exclude specific paths:

```json
{
  "claudeMdExcludes": ["packages/legacy-app/**", "archived/**", "vendor/**"]
}
```

When to recommend:

- Monorepo with many packages, some irrelevant to current work
- Legacy directories with outdated CLAUDE.md files
- Third-party code with its own CLAUDE.md

## Organization-Managed CLAUDE.md

Organizations can deploy centralized CLAUDE.md files that apply to all users:

| OS        | Path                                                |
| --------- | --------------------------------------------------- |
| Linux/WSL | `/etc/claude-code/CLAUDE.md`                        |
| macOS     | `/Library/Application Support/ClaudeCode/CLAUDE.md` |

These have the highest priority and are typically managed by IT/platform teams for organization-wide standards (security policies, approved tools, compliance requirements).

When auditing, check for the presence of org-managed files — they may explain constraints that aren't visible in the project's own CLAUDE.md.

## Auto Memory vs CLAUDE.md

|                 | CLAUDE.md                               | Auto Memory                                                                |
| --------------- | --------------------------------------- | -------------------------------------------------------------------------- |
| **Who writes**  | Human (developer/team)                  | Claude (automatically)                                                     |
| **Contains**    | Instructions, standards, commands       | Learnings, preferences, discoveries                                        |
| **Loaded**      | Full file, every session                | First 200 lines of index                                                   |
| **Use for**     | Coding standards, architecture, gotchas | Build commands discovered in session, debugging insights, user preferences |
| **Managed via** | Direct editing                          | `/memory` command                                                          |

They complement each other: CLAUDE.md is the team's intentional instructions, auto memory is Claude's accumulated knowledge about the project and user.

When auditing, check if information that belongs in CLAUDE.md has ended up in auto memory instead (or vice versa). Standards and commands should be in CLAUDE.md; one-off learnings should be in memory.

## CLAUDE.md vs Hooks vs Skills

Three mechanisms for influencing Claude's behavior, ordered by certainty:

| Mechanism     | Certainty                                        | Use When                                                                                 |
| ------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| **Hooks**     | 100% — shell commands that execute automatically | Actions that must happen with zero exceptions (pre-commit formatting, post-edit linting) |
| **CLAUDE.md** | High — instructions Claude follows               | Project standards, conventions, commands that apply every session                        |
| **Skills**    | On-demand — loaded when triggered                | Reusable workflows, domain knowledge that's only sometimes relevant                      |

When auditing, look for misplaced instructions:

- If a CLAUDE.md rule says "always run X before committing" — that's a hook, not a CLAUDE.md instruction
- If a CLAUDE.md section describes a complex workflow used only for specific tasks — that's a skill
- If auto memory has project standards — those belong in CLAUDE.md

## Size Guidelines

Target: **under 200 lines** per CLAUDE.md file. Maximum: **300 lines**.

Every line in CLAUDE.md consumes context in every session. The litmus test for each line:

> **"Would Claude make mistakes without this instruction?"**

If the answer is no — if Claude would do the right thing anyway — the line is wasting context. Delete it.

Signs a CLAUDE.md is too long:

- Claude stops following instructions near the bottom of the file
- Multiple sections cover the same topic with slight variations
- Generic best practices that any competent developer knows
- Style rules that a linter already enforces
- Detailed API documentation instead of a link

Remedies:

- Split into `.claude/rules/` with path-specific scoping
- Use `@imports` to reference existing docs instead of duplicating
- Move infrequent workflows to skills
- Move deterministic checks to hooks
- Delete lines that fail the litmus test
