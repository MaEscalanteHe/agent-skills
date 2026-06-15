# Personal Agent Skills

A personal collection of agent skills for infrastructure and development workflows. Skills are folders of instructions and resources that AI agents load dynamically to improve performance on specialized tasks.

## Skills

| Skill                                                       | Description                                                                                                                        |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| [**terraform-conventions**](plugins/terraform-conventions/) | Terraform HCL style guide following HashiCorp conventions, with file organization, naming, security, and module best practices     |
| [**dockerfile-builder**](plugins/dockerfile-builder/)       | Multi-stage Dockerfiles with modern BuildKit features, language-specific patterns (Go, Node, Python, Java), and container security |
| [**github-issue-tracker**](plugins/github-issue-tracker/)   | Track edge cases and TODOs as GitHub issues with duplicate detection, TODO file processing, and proactive suggestions              |
| [**claude-md-auditor**](plugins/claude-md-auditor/)         | Audit and improve CLAUDE.md files with quality scoring, targeted updates, and modern Claude Code feature recommendations           |
| [**caveman**](plugins/caveman/)                             | Ultra-compressed communication mode that cuts token usage while keeping full technical accuracy, with lite, full, and ultra levels |
| [**context7**](plugins/context7/)                           | Retrieve up-to-date, version-specific library/framework/API docs and code examples via the Context7 REST API (curl, no key needed) |

## MCPs

Plugins that bundle an MCP server. Installing one auto-configures the server in Claude Code (you'll be prompted to approve it on first use).

| MCP                                   | Description                                                                                                                    |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| [**playwright**](plugins/playwright/) | Browser automation and end-to-end testing — navigate, click, fill forms, take snapshots and screenshots, drive a real browser  |

## Installation

### Claude Code Marketplace

```bash
# Add the marketplace
/plugin marketplace add maescalantehe/agent-skills

# Install a specific plugin
/plugin install terraform-conventions@skala-agent-skills
/plugin install dockerfile-builder@skala-agent-skills
/plugin install github-issue-tracker@skala-agent-skills
/plugin install claude-md-auditor@skala-agent-skills
/plugin install caveman@skala-agent-skills
/plugin install playwright@skala-agent-skills
/plugin install context7@skala-agent-skills
```

### Skills.sh

```bash
# List all the available skills
npx skills add maescalantehe/agent-skills

# Install a specific skill
npx skills add https://github.com/maescalantehe/agent-skills --skill terraform-conventions
npx skills add https://github.com/maescalantehe/agent-skills --skill dockerfile-builder
npx skills add https://github.com/maescalantehe/agent-skills --skill github-issue-tracker
npx skills add https://github.com/maescalantehe/agent-skills --skill claude-md-auditor
npx skills add https://github.com/maescalantehe/agent-skills --skill caveman
npx skills add https://github.com/maescalantehe/agent-skills --skill context7
```

## License

MIT License - see LICENSE file for details
