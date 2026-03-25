# Personal Agent Skills

A personal collection of agent skills for infrastructure and development workflows. Skills are folders of instructions and resources that AI agents load dynamically to improve performance on specialized tasks.

## Skills

| Skill                                                       | Description                                                                                                                        |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| [**terraform-conventions**](plugins/terraform-conventions/) | Terraform HCL style guide following HashiCorp conventions, with file organization, naming, security, and module best practices     |
| [**dockerfile-builder**](plugins/dockerfile-builder/)       | Multi-stage Dockerfiles with modern BuildKit features, language-specific patterns (Go, Node, Python, Java), and container security |
| [**github-issue-tracker**](plugins/github-issue-tracker/)   | Track edge cases and TODOs as GitHub issues with duplicate detection, TODO file processing, and proactive suggestions              |
| [**claude-md-auditor**](plugins/claude-md-auditor/)         | Audit and improve CLAUDE.md files with quality scoring, targeted updates, and modern Claude Code feature recommendations           |

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
```

## License

MIT License - see LICENSE file for details
