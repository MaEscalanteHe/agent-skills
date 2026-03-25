---
name: claude-md-auditor
description: "Audit and improve CLAUDE.md files in repositories. Use when user asks to check, audit, update, improve, or fix CLAUDE.md files. Scans for all CLAUDE.md files, evaluates quality against templates, outputs quality report, then makes targeted updates. Also use when the user mentions 'CLAUDE.md maintenance' or 'project memory optimization'."
---

# CLAUDE.md Improver

Audit, evaluate, and improve CLAUDE.md files across a codebase to ensure Claude Code has optimal project context.

**This skill can write to CLAUDE.md files.** After presenting a quality report and getting user approval, it updates CLAUDE.md files with targeted improvements.

---

## Workflow

### Phase 1: Discovery

Find all CLAUDE.md files and related configuration in the repository:

```bash
find . \( -name "CLAUDE.md" -o -name ".claude.md" -o -name ".claude.local.md" \) 2>/dev/null | head -50
ls .claude/rules/ 2>/dev/null
```

The `head -50` is a safety limit for extremely large monorepos with many nested CLAUDE.md files.

**File Types & Locations:**

| Type                 | Location                                                                                            | Purpose                                            |
| -------------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Organization-managed | `/etc/claude-code/CLAUDE.md` (Linux) or `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) | Organization-wide policies (highest priority)      |
| Global defaults      | `~/.claude/CLAUDE.md`                                                                               | User-wide defaults across all projects             |
| Project root         | `./CLAUDE.md` or `./.claude/CLAUDE.md`                                                              | Primary project context (shared with team via git) |
| Rules directory      | `./.claude/rules/*.md`                                                                              | Modular, domain-specific instructions              |
| Local overrides      | `./.claude.local.md`                                                                                | Personal/local settings (gitignored, not shared)   |
| Package-specific     | `./packages/*/CLAUDE.md`                                                                            | Module-level context in monorepos                  |
| Subdirectory         | Any nested location                                                                                 | Feature/domain-specific context (loaded on-demand) |

Claude auto-discovers CLAUDE.md files in parent directories at startup. Subdirectory CLAUDE.md files load on-demand when Claude reads files there.

### Phase 2: Quality Assessment

For each CLAUDE.md file, evaluate against quality criteria. See [references/quality-criteria.md](references/quality-criteria.md) for detailed rubrics.

**Quick Assessment Checklist:**

| Criterion                     | Weight | Check                                                                    |
| ----------------------------- | ------ | ------------------------------------------------------------------------ |
| Commands/workflows documented | High   | Are build/test/deploy commands present?                                  |
| Architecture clarity          | High   | Can Claude understand the codebase structure?                            |
| Non-obvious patterns          | Medium | Are gotchas and quirks documented?                                       |
| Conciseness                   | Medium | Under 200 lines? No verbose explanations or obvious info?                |
| Currency                      | High   | Does it reflect current codebase state?                                  |
| Actionability                 | High   | Are instructions executable, not vague?                                  |
| Modern features               | Bonus  | Uses `.claude/rules/`, `@imports`, path-specific rules where beneficial? |

**Quality Scores:**

- **A (90-100)**: Comprehensive, current, actionable
- **B (70-89)**: Good coverage, minor gaps
- **C (50-69)**: Basic info, missing key sections
- **D (30-49)**: Sparse or outdated
- **F (0-29)**: Missing or severely outdated

### Phase 3: Quality Report Output

**Output the quality report BEFORE making any updates.** The user needs to see the assessment before approving changes.

Format:

```
## CLAUDE.md Quality Report

### Summary
- Files found: X
- Average score: X/100
- Files needing update: X

### File-by-File Assessment

#### 1. ./CLAUDE.md (Project Root)
**Score: XX/100 (Grade: X)**

| Criterion | Score | Notes |
|-----------|-------|-------|
| Commands/workflows | X/20 | ... |
| Architecture clarity | X/20 | ... |
| Non-obvious patterns | X/15 | ... |
| Conciseness | X/15 | ... |
| Currency | X/15 | ... |
| Actionability | X/15 | ... |

**Issues:**
- [List specific problems]

**Recommended additions:**
- [List what should be added]

#### 2. ./packages/api/CLAUDE.md (Package-specific)
...
```

### Phase 4: Targeted Updates

After outputting the quality report, ask user for confirmation before updating.

Focus on genuinely useful additions — commands, gotchas, package relationships, configuration quirks. Avoid restating what's obvious from the code, generic best practices, or verbose explanations. See [references/update-guidelines.md](references/update-guidelines.md) for detailed guidance on what to add, what to avoid, and anti-patterns to flag.

**Show diffs** for each change:

`````markdown
### Update: ./CLAUDE.md

**Why:** Build command was missing, causing confusion about how to run the project.

````diff
+ ## Quick Start
+
+ ```bash
+ npm install
+ npm run dev  # Start development server on port 3000
+ ```
````
`````

```

For CLAUDE.md files over 200 lines, consider suggesting a migration to `.claude/rules/` — see [references/modern-features.md](references/modern-features.md) for details.

### Phase 5: Apply Updates

After user approval, apply changes using the Edit tool. Preserve existing content structure.

---

## Modern Features

Claude Code has evolved beyond a single CLAUDE.md file. When auditing, consider whether the project would benefit from these features (see [references/modern-features.md](references/modern-features.md) for full details):

- **`.claude/rules/`** — split large CLAUDE.md into modular, domain-specific files. Rules can be scoped to specific file patterns using `paths:` frontmatter
- **`@file` imports** — reference existing docs (`@README.md`, `@docs/guide.md`) instead of duplicating content. Max 5 levels deep
- **`claudeMdExcludes`** — in monorepos, exclude irrelevant CLAUDE.md files from auto-discovery via `.claude/settings.json`

## CLAUDE.md vs Hooks vs Skills

Three mechanisms for influencing Claude's behavior, in order of certainty:

| Mechanism     | Use When                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------- |
| **Hooks**     | Actions that must happen with zero exceptions (pre-commit formatting, post-edit linting) |
| **CLAUDE.md** | Project standards and conventions that apply every session                               |
| **Skills**    | Reusable workflows and domain knowledge only sometimes relevant                          |

When auditing, flag misplaced instructions: "always run X" → hook. Complex infrequent workflow → skill.

## Common Issues to Flag

1. **Stale commands**: Build commands that no longer work
2. **Missing dependencies**: Required tools not mentioned
3. **Outdated architecture**: File structure that's changed
4. **Missing environment setup**: Required env vars or config
5. **Broken test commands**: Test scripts that have changed
6. **Undocumented gotchas**: Non-obvious patterns not captured
7. **Excessive length**: CLAUDE.md over 200 lines losing effectiveness
8. **Linter rules in CLAUDE.md**: Style rules that a deterministic tool should enforce
9. **Stale code snippets**: Embedded code that has drifted from implementation (suggest `file:line` references)

## User Tips to Share

When presenting recommendations, remind users:

- **`/init`**: Auto-generate a starter CLAUDE.md based on the codebase
- **`/memory`**: View and manage all instruction files and auto memory
- **`#` key shortcut**: During a Claude session, press `#` to have Claude auto-incorporate learnings into CLAUDE.md
- **Keep it concise**: Target under 200 lines — dense is better than verbose
- **Actionable commands**: All documented commands should be copy-paste ready
- **Use `.claude.local.md`**: For personal preferences not shared with team (add to `.gitignore`)
- **Global defaults**: Put user-wide preferences in `~/.claude/CLAUDE.md`
- **Auto Memory**: Claude accumulates learnings automatically — standards go in CLAUDE.md, discoveries go in auto memory. Use `/memory` to review both

## Templates

See [references/templates.md](references/templates.md) for CLAUDE.md templates by project type, including templates for `.claude/rules/` directory structure, path-specific rules, and `@file` imports.
```
