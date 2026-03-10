# Engram Skills Collection

A curated collection of agent skills that can be installed across different projects with a single command.

## Quick Install

Download and run the interactive installer:

```bash
curl -fsSL https://raw.githubusercontent.com/sagewarehq/engram-ansible/master/install.sh -o install.sh && bash install.sh
```

The installer will show you a menu where you can:
- Enter `0` to install all skills
- Enter specific numbers (e.g., `1 3 5`) to install selected skills

## Included Skills

- `vercel-labs/agent-browser` - Browser automation capabilities
- `anthropics/skills/frontend-design` - Frontend design best practices
- `anthropics/skills/pptx` - PowerPoint file handling
- `anthropics/skills/docx` - Word document handling
- `anthropics/skills/xlsx` - Excel spreadsheet handling

## Manual Installation

If you prefer to install skills individually:

```bash
npx skills add vercel-labs/agent-browser -y
npx skills add anthropics/skills/frontend-design -y
npx skills add anthropics/skills/pptx -y
npx skills add anthropics/skills/docx -y
npx skills add anthropics/skills/xlsx -y
```

## Adding New Skills

1. Edit `skills.txt` to add new skills (one per line)
2. Run `./install.sh` to install all skills
3. Commit and push changes

## Skills Format

Each line in `skills.txt` should follow the format:
```
owner/repo/skill-name
```
