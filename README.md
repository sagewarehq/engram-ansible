# Engram Skills Collection

A curated collection of agent skills that can be installed across different coding agents with a single command.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/sagewarehq/engram-ansible/master/install.sh -o install.sh && bash install.sh
```

Works with both `bash` and `zsh`:

```bash
zsh install.sh
```

The interactive TUI guides you through two steps:

1. **Select agents** -- choose which coding agents receive the skills (or skip to install without agent targeting)
2. **Select skills** -- choose which skills to install from the remote list

Controls: arrows or `j`/`k` to move, `space` to toggle, `a` to toggle all, `enter` to confirm, `q` or `ctrl+c` to quit.

## Included Skills

| Skill | Description |
|-------|-------------|
| `vercel-labs/agent-browser` | Browser automation capabilities |
| `anthropics/skills/frontend-design` | Frontend design best practices |
| `anthropics/skills/pptx` | PowerPoint file handling |
| `anthropics/skills/docx` | Word document handling |
| `anthropics/skills/xlsx` | Excel spreadsheet handling |

## Supported Agents

antigravity, augment, claude-code, openclaw, codebuddy, command-code, continue, cortex, crush, cursor, droid, gemini-cli, github-copilot, goose, junie, iflow-cli, kilo, kiro-cli, kode, mcpjam, mistral-vibe, mux, opencode, openhands, pi, qoder, qwen-code, roo, trae, trae-cn, windsurf, zencoder, neovate, pochi, adal, amp, kimi-cli, replit, cline, codex

## Manual Installation

If you prefer to install skills individually:

```bash
npx skills add vercel-labs/agent-browser -a claude-code -y
npx skills add anthropics/skills/frontend-design -a claude-code -y
npx skills add anthropics/skills/pptx -a claude-code -y
npx skills add anthropics/skills/docx -a claude-code -y
npx skills add anthropics/skills/xlsx -a claude-code -y
```

Replace `claude-code` with your agent of choice, or omit `-a` to install without targeting a specific agent.

## Adding New Skills

1. Edit `skills.txt` to add new skills (one per line)
2. Run `./install.sh` to install

## Skills Format

Each line in `skills.txt` follows one of these formats:

```
owner/repo
owner/repo/skill-name
```

Lines starting with `#` are treated as comments.
