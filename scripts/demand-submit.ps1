param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DemandId,

    [Parameter(Mandatory = $true, Position = 1)]
    [Alias("Title")]
    [string]$Message,

    [string]$BaseBranch = "master",
    [string]$Remote = "origin",
    [string]$BranchPrefix = "",
    [string]$BranchName = "",
    [string]$RepoPath = "",
    [switch]$NoPush,
    [switch]$AllowEmpty,
    [switch]$StagedOnly,
    [switch]$All
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Run-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs
    )
    $output = & git -c core.quotepath=false @GitArgs 2>&1
    $exitCode = $LASTEXITCODE
    $output |
        Where-Object { $_ -is [string] -and $_ -notmatch 'LF will be replaced by CRLF' } |
        ForEach-Object { Write-Host $_ }
    $output |
        Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -and $_.Exception.Message -notmatch 'LF will be replaced by CRLF' } |
        ForEach-Object { Write-Host $_.Exception.Message }
    if ($exitCode -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $exitCode"
    }
}

function Git-Output {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs
    )
    $output = & git -c core.quotepath=false @GitArgs 2>&1
    $exitCode = $LASTEXITCODE
    $output |
        Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -and $_.Exception.Message -notmatch 'LF will be replaced by CRLF' } |
        ForEach-Object { Write-Host $_.Exception.Message }
    if ($exitCode -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $exitCode"
    }
    return @($output | Where-Object { $_ -is [string] })
}

function Has-Ref {
    param([string]$Ref)
    & git show-ref --verify --quiet $Ref
    return $LASTEXITCODE -eq 0
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "== $Text =="
}

function Rename-LocalBranchIfExists {
    param(
        [string]$Branch,
        [string]$Stamp
    )
    $localRef = "refs/heads/$Branch"
    if (-not (Has-Ref $localRef)) {
        return
    }

    $backupBranch = "$Branch-backup-$Stamp"
    Write-Host "Local target branch already exists. Renaming it to: $backupBranch"
    Run-Git @("branch", "-m", $Branch, $backupBranch)
}

# --- Repo alias resolution ---
function Resolve-RepoAlias {
    param([string]$InputPath)
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return ""
    }
    # If it's an absolute path that exists, use it directly
    if ([System.IO.Path]::IsPathRooted($InputPath) -and (Test-Path -LiteralPath $InputPath)) {
        return $InputPath
    }
    # Try alias lookup from user config
    $aliasFile = Join-Path $env:USERPROFILE ".claude\repo-aliases.json"
    if (Test-Path -LiteralPath $aliasFile) {
        try {
            $aliases = Get-Content -LiteralPath $aliasFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $resolved = $aliases.PSObject.Properties | Where-Object {
                $_.Name -eq $InputPath
            } | Select-Object -First 1
            if ($resolved -and (Test-Path -LiteralPath $resolved.Value)) {
                Write-Host "Resolved alias '$InputPath' -> $($resolved.Value)"
                return $resolved.Value
            }
        } catch {
            Write-Host "Warning: Failed to parse $aliasFile : $($_.Exception.Message)"
        }
    }
    # Not an absolute path and not a known alias
    return ""
}

$resolvedRepo = Resolve-RepoAlias -InputPath $RepoPath
if (-not [string]::IsNullOrWhiteSpace($resolvedRepo)) {
    Set-Location -LiteralPath $resolvedRepo
}

$repoRoot = (Git-Output @("rev-parse", "--show-toplevel") | Select-Object -First 1)
Set-Location -LiteralPath $repoRoot

$targetBranch = if ([string]::IsNullOrWhiteSpace($BranchName)) {
    "$BranchPrefix$DemandId"
} else {
    $BranchName
}

$cleanDemandId = $DemandId.Trim()
$cleanDemandId = $cleanDemandId.TrimStart("[").TrimEnd("]")
$cleanTitle = $Message.Trim()
$commitMessage = if ($cleanTitle.StartsWith("[$cleanDemandId]")) {
    $cleanTitle
} else {
    "[$cleanDemandId] $cleanTitle"
}

Write-Section "Repository"
Write-Host "Root: $repoRoot"
Write-Host "Base: $Remote/$BaseBranch"
Write-Host "Target branch: $targetBranch"
Write-Host "Commit message: $commitMessage"
Write-Host "Staged only: $StagedOnly"
Write-Host "Submit all: $All"

$existingUnmerged = @(Git-Output @("diff", "--name-only", "--diff-filter=U"))
if ($existingUnmerged.Count -gt 0) {
    throw "Repository already has unresolved conflicts. Resolve them before running demand-submit."
}

$originalStaged = @(Git-Output @("diff", "--cached", "--name-only"))
if ($StagedOnly -and $All) {
    throw "Use either -StagedOnly or -All, not both."
}

if ($StagedOnly -and $originalStaged.Count -eq 0 -and -not $AllowEmpty) {
    throw "StagedOnly was set, but there are no staged files. Put files in IDEA/WebStorm Staged first or remove -StagedOnly."
}

$originalUnstaged = @(Git-Output @("diff", "--name-only"))
$originalUntracked = @(Git-Output @("ls-files", "--others", "--exclude-standard"))
$hasMixedSelection = $originalStaged.Count -gt 0 -and (($originalUnstaged.Count + $originalUntracked.Count) -gt 0)
if ($hasMixedSelection -and -not $StagedOnly -and -not $All) {
    Write-Host ""
    Write-Host "Detected both staged and unstaged/untracked changes."
    Write-Host "Staged files:"
    $originalStaged | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "This usually means IDEA/WebStorm Staged is being used for a partial submit."
    Write-Host "Rerun with one explicit mode:"
    Write-Host "  -StagedOnly   submit only files currently in Staged"
    Write-Host "  -All          submit every local change with git add -A"
    throw "Refusing to guess between staged-only and all-files submit."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$toolRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$backupRoot = Join-Path $toolRoot "demand-skill-logs"
$backupDir = Join-Path $backupRoot "$stamp-$($targetBranch -replace '[\\/:*?""<>|]', '_')"
$stagedPathFile = Join-Path $backupDir "staged-files.txt"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Write-Section "Log"
Git-Output @("branch", "--show-current") | Set-Content -LiteralPath (Join-Path $backupDir "branch.txt") -Encoding UTF8
Git-Output @("status", "--short") | Set-Content -LiteralPath (Join-Path $backupDir "status.txt") -Encoding UTF8
Git-Output @("diff", "--binary") | Set-Content -LiteralPath (Join-Path $backupDir "working-tree.patch") -Encoding UTF8
Git-Output @("diff", "--cached", "--binary") | Set-Content -LiteralPath (Join-Path $backupDir "staged.patch") -Encoding UTF8
$originalStaged | Set-Content -LiteralPath $stagedPathFile -Encoding UTF8
Write-Host "Log written to: $backupDir"

$statusBefore = @(Git-Output @("status", "--porcelain"))
$createdStash = $false
$stashRef = ""
if ($statusBefore.Count -gt 0) {
    Write-Section "Stash Current Work"
    $stashMessage = "demand-submit:${targetBranch}:${stamp}"
    Run-Git @("stash", "push", "-u", "-m", $stashMessage)
    $createdStash = $true
    $stashRef = "stash@{0}"
} else {
    Write-Host "Working tree is clean."
}

try {
    Write-Section "Update Base"
    Run-Git @("fetch", $Remote, "--prune")

    Write-Section "Checkout Target Branch"
    Rename-LocalBranchIfExists -Branch $targetBranch -Stamp $stamp
    Run-Git @("checkout", "-b", $targetBranch, "$Remote/$BaseBranch")

    if ($createdStash) {
        Write-Section "Restore Work"
        $popOutput = & git -c core.quotepath=false stash pop $stashRef 2>&1
        $popExitCode = $LASTEXITCODE
        $popOutput |
            Where-Object { $_ -is [string] -and $_ -notmatch 'LF will be replaced by CRLF' } |
            ForEach-Object { Write-Host $_ }
        $popOutput |
            Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -and $_.Exception.Message -notmatch 'LF will be replaced by CRLF' } |
            ForEach-Object { Write-Host $_.Exception.Message }
        if ($popExitCode -ne 0) {
            Write-Host ""
            Write-Host "Conflict or restore failure occurred during stash pop."
            Write-Host "The repository has been left for manual/AI conflict resolution."
            Write-Host "After resolving, run:"
            if ($StagedOnly) {
                Write-Host "  git add -- <files from $stagedPathFile>"
            } else {
                Write-Host "  git add -A"
            }
            Write-Host "  git commit -m `"$commitMessage`""
            Write-Host "  git push -u $Remote $targetBranch"
            exit 2
        }
    }

    $unmerged = @(Git-Output @("diff", "--name-only", "--diff-filter=U"))
    if ($unmerged.Count -gt 0) {
        Write-Host "Unresolved conflicts:"
        $unmerged | ForEach-Object { Write-Host "  $_" }
        exit 2
    }

    Write-Section "Commit"
    if ($StagedOnly) {
        Write-Host "Restaging files that were staged before running demand-submit:"
        foreach ($path in $originalStaged) {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }
            Write-Host "  $path"
            Run-Git @("add", "--", $path)
        }
    } else {
        if (-not $All -and $originalStaged.Count -gt 0) {
            Write-Host "No unstaged/untracked changes were detected at start; submitting the existing staged selection."
        }
        Run-Git @("add", "-A")
    }
    $staged = @(Git-Output @("diff", "--cached", "--name-only"))
    if ($staged.Count -eq 0 -and -not $AllowEmpty) {
        Write-Host "No staged changes after moving to target branch. Nothing to commit."
        exit 0
    }

    if ($staged.Count -eq 0 -and $AllowEmpty) {
        Run-Git @("commit", "--allow-empty", "-m", $commitMessage)
    } else {
        Run-Git @("commit", "-m", $commitMessage)
    }

    if (-not $NoPush) {
        Write-Section "Push"
        Run-Git @("push", "-u", $Remote, $targetBranch)
    } else {
        Write-Host "NoPush was set; skipping push."
    }

    Write-Section "Done"
    Run-Git @("status", "--short")
    Write-Host "Demand branch is ready: $targetBranch"
} catch {
    Write-Host ""
    Write-Host "demand-submit stopped: $($_.Exception.Message)"
    if ($createdStash) {
        Write-Host "If your work was not restored, check: git stash list"
        Write-Host "Log directory: $backupDir"
    }
    exit 1
}
