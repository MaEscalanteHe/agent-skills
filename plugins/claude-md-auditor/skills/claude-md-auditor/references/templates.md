# CLAUDE.md Templates

## Key Principles

- **Concise**: Under 200 lines, dense human-readable content
- **Actionable**: Commands should be copy-paste ready
- **Project-specific**: Document patterns unique to this project, not generic advice
- **Current**: All info should reflect actual codebase state
- **Testable**: Every line should pass: "Would Claude make mistakes without this?"

---

## Recommended Sections

Use only the sections relevant to the project. Not all sections are needed.

### Commands

```markdown
## Commands

| Command             | Description              |
| ------------------- | ------------------------ |
| `<install command>` | Install dependencies     |
| `<dev command>`     | Start development server |
| `<build command>`   | Production build         |
| `<test command>`    | Run tests                |
| `<lint command>`    | Lint/format code         |
```

### Architecture

```markdown
## Architecture

<root>/

  <dir>/    # <purpose>
  <dir>/    # <purpose>
  <dir>/    # <purpose>
```

### Key Files

```markdown
## Key Files

- `<path>` - <purpose>
- `<path>` - <purpose>
```

### Code Style

```markdown
## Code Style

- <convention>
- <preference over alternative>
```

### Environment

```markdown
## Environment

Required:

- `<VAR_NAME>` - <purpose>

Setup:

- <setup step>
```

### Testing

```markdown
## Testing

- `<test command>` - <what it tests>
- <testing convention or pattern>
```

### Gotchas

```markdown
## Gotchas

- <non-obvious thing that causes issues>
- <ordering dependency or prerequisite>
- <common mistake to avoid>
```

---

## Template: Project Root (Minimal)

For small projects or getting started quickly. Use `/init` to auto-generate a starting point.

```markdown
# <Project Name>

<One-line description>

## Commands

| Command     | Description   |
| ----------- | ------------- |
| `<command>` | <description> |

## Architecture

<structure>

## Gotchas

- <gotcha>
```

---

## Template: Project Root (Comprehensive)

For established projects with clear conventions. Target: under 200 lines.

```markdown
# <Project Name>

<One-line description>

## Commands

| Command     | Description   |
| ----------- | ------------- |
| `<command>` | <description> |

## Architecture

<structure with descriptions>

## Key Files

- `<path>` - <purpose>

## Code Style

- <convention>

## Environment

- `<VAR>` - <purpose>

## Testing

- `<command>` - <scope>

## Gotchas

- <gotcha>
```

---

## Template: Project with Rules Directory

For projects where CLAUDE.md approaches 200 lines. Split domain-specific instructions into `.claude/rules/`:

```markdown
# <Project Name>

<One-line description>

## Commands

| Command     | Description   |
| ----------- | ------------- |
| `<command>` | <description> |

## Architecture

<structure>

## Gotchas

- <gotcha>

## Additional Context

- API standards: @.claude/rules/api-design.md
- Frontend patterns: @.claude/rules/frontend.md
- Testing approach: @.claude/rules/testing.md
```

Corresponding rules directory:

```
.claude/
├── CLAUDE.md
├── settings.json
└── rules/
    ├── api-design.md         # Always loaded
    ├── testing.md            # Always loaded
    └── frontend.md           # Path-specific (see below)
```

### Path-Specific Rule Example

```markdown
---
paths:
  - "src/components/**/*.tsx"
  - "src/pages/**/*.tsx"
---

# Frontend Component Rules

- Use functional components with hooks
- Colocate styles in `<Component>.module.css`
- Export types from `types.ts` in each feature directory
```

This rule only loads when Claude reads files matching those patterns, saving context for other work.

---

## Template: Package/Module

For packages within a monorepo or distinct modules.

```markdown
# <Package Name>

<Purpose of this package>

## Usage

<import/usage example>

## Key Exports

- `<export>` - <purpose>

## Dependencies

- `<dependency>` - <why needed>

## Notes

- <important note>
```

---

## Template: Monorepo Root

For monorepos with multiple packages. Consider `claudeMdExcludes` for irrelevant packages.

```markdown
# <Monorepo Name>

<Description>

## Packages

| Package  | Description | Path     |
| -------- | ----------- | -------- |
| `<name>` | <purpose>   | `<path>` |

## Commands

| Command     | Description   |
| ----------- | ------------- |
| `<command>` | <description> |

## Cross-Package Patterns

- <shared pattern>
- <generation/sync pattern>
```

If some packages are legacy or irrelevant, add to `.claude/settings.json`:

```json
{
  "claudeMdExcludes": ["packages/deprecated-*/**", "packages/legacy/**"]
}
```

---

## Template: Using @imports

When CLAUDE.md would duplicate existing documentation:

```markdown
# <Project Name>

See @README.md for project overview.

## Commands

See @docs/development.md for full command reference.

| Command       | Description |
| ------------- | ----------- |
| `npm run dev` | Quick start |

## Gotchas

- <project-specific gotcha>

## Personal Overrides

@~/.claude/my-project-prefs.md
```

Imports resolve relative to the file. Max depth: 5 levels. Use sparingly — each import adds to context. Only import files that Claude genuinely needs.

---

## Update Principles

When updating any CLAUDE.md:

1. **Be specific**: Use actual file paths, real commands from this project
2. **Be current**: Verify info against the actual codebase
3. **Be brief**: One line per concept when possible
4. **Be useful**: Would this help a new Claude session understand the project?
5. **Be modern**: Suggest `.claude/rules/`, `@imports`, or path-specific rules when appropriate
