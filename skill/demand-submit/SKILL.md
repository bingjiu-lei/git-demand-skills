---
name: demand-submit
description: Fast GitLab demand submit workflow. Use when the user gives a demand/ticket id and title and wants current repo changes committed to a clean demand branch from latest master/release, with IDEA/WebStorm Staged files honored automatically.
---

# Demand Submit

## Demand Title Integrity (Mandatory)

- Treat the title supplied by the user as immutable input.
- Pass it to the script and use it in the commit message exactly as provided, character for character.
- Do not shorten, rewrite, correct, normalize, translate, add, remove, or change any character in the title, including spaces and punctuation.
- If no title was provided, ask for it; never infer or generate one.

Run the standalone script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" <demandId> "<title>" <mode>
```

Uninstall from the cloned project root with `git-demand-skills-uninstall.bat`. Clear only logs with `git-demand-skills-clear-logs.bat`.

Commit message is always:

```text
[demandId] title
```

When maintaining this git-demand-skills repository itself, use a Chinese commit message title and describe what this push changed or added.

## Fast Path

Do this with minimal explanation. Do not write a long analysis before running commands.

1. Resolve the target repository:
   - If the user mentions a project alias (e.g. "护士前端", "医生后端", "common包"), pass it as `-RepoPath`. The script will look it up from `~/.claude/repo-aliases.json`.
   - If the user gives an explicit path, pass it as `-RepoPath`.
   - If neither, the script uses the current working directory.
2. Check status:

```powershell
git status --short --branch
git diff --cached --name-only
```

3. Choose mode:
   - If `git diff --cached --name-only` returns any file, run with `-StagedOnly`.
   - Do not ask for confirmation when staged files exist. IDEA/WebStorm Staged is the user's selection.
   - Use `-All` only when there are no staged files, or when the user explicitly says to submit all local changes.
4. Run the script.
5. If the script stops with conflict exit code `2`, inspect `git status`, resolve conflicts, run `git diff --check`, then finish commit/push.

## Commands

Staged files exist, or user says to submit selected/staged files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -StagedOnly
```

Submit all local changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -All
```

Only commit, do not push:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -StagedOnly -NoPush
```

Different base branch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -BaseBranch release-1.44 -StagedOnly
```

Specify repo path (absolute path or alias from `~/.claude/repo-aliases.json`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -StagedOnly -RepoPath "D:\gitProgram\onelink-web-doctor"
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -StagedOnly -RepoPath "医生前端"
```

## Repo Aliases

The `-RepoPath` parameter supports aliases defined in `~/.claude/repo-aliases.json`. Example:

```json
{
  "护士前端": "D:/gitProgram/onelink-web-nurse",
  "医生前端": "D:/gitProgram/onelink-web-doctor",
  "医生后端": "D:/gitProgram/onelink-micro-cis-doctor"
}
```

Each user creates their own file locally. The script ignores it if the file does not exist. When the user mentions a project by alias (e.g. "护士前端", "医生后端", "common包"), pass it as `-RepoPath` — the script will resolve it automatically.

## Windows Terminal Rules

Assume Windows PowerShell unless the tool explicitly says otherwise.

Prefer using `-RepoPath` over `Set-Location`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "{{DEMAND_SUBMIT_SCRIPT_PATH}}" 197462 "demand title" -StagedOnly -RepoPath "医生前端"
```

Only use `Set-Location` when `-RepoPath` is not available:

```powershell
Set-Location -LiteralPath "D:\path\repo"
git status --short --branch
```

Do not use Bash/CMD syntax in PowerShell:

```text
cd repo && git status
cd /d D:\repo & git status
timeout /t 30 /nobreak >nul
```

## Safety Rules

- Never commit to `master`.
- Never create or merge a GitLab merge request unless the user asks.
- Never use `git add -A` manually when staged files exist; use script `-StagedOnly`.
- If staged and unstaged/untracked changes both exist, run `-StagedOnly` directly. Do not ask the user to choose.
- Use `-All` only when the user explicitly wants all local changes, or when there are no staged files.
- Do not auto-merge, reset, rebase, or force-push when base branch pull fails.
- If the script stops on conflict, preserve both sides' intent; do not blindly choose current/incoming changes.
- If the original run used `-StagedOnly`, finish conflicts by re-staging only intended files, not `git add -A`.
- When the user mentions a project by alias (e.g. "护士前端", "医生后端", "common包"), pass it as `-RepoPath`. Do not manually `Set-Location` first.
