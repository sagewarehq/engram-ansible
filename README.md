# Engram Skills Collection

A curated collection of agent skills that can be installed across different projects with a single command.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/sagewarehq/engram-ansible/master/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/sagewarehq/engram-ansible.git
cd engram-ansible
./install.sh
```

## Included Skills

- `vercel-labs/skills/agent-browser` - Browser automation capabilities
- `anthropics/skills/frontend-design` - Frontend design best practices
- `anthropics/skills/pptx` - PowerPoint file handling
- `anthropics/skills/docx` - Word document handling
- `anthropics/skills/xlsx` - Excel spreadsheet handling

## Manual Installation

If you prefer to install skills individually:

```bash
npx skillsadd vercel-labs/skills/agent-browser
npx skillsadd anthropics/skills/frontend-design
npx skillsadd anthropics/skills/pptx
npx skillsadd anthropics/skills/docx
npx skillsadd anthropics/skills/xlsx
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
