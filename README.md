# git-demand-skills

一个可复用的 Codex Skill + PowerShell 脚本集合，用来处理公司 GitLab 里的两类高频流程：

- `demand-submit`：把当前本地改动快速提交到需求分支。
- `demand-merge`：把 `master` 上某个需求按 cherry-pick 方式归并到 `release` 分支。

它适合这种工作流：

```text
当前目录开发代码
基于最新 master / release 分支创建需求分支
自动生成 [需求号] 标题 的 commit message
自动 commit 并 push 到远程需求分支
如果有冲突就停下来，不提交、不推送
```

提交信息格式固定为：

```text
[需求号] 标题
```

例如：

```text
[197462] 壮医诊断改造，诊断类型选择壮医诊断时，只显示壮医目录下的内容
```

## 安装

推荐使用引导安装。它会弹窗选择安装目录，优先从 Gitee 拉取项目，失败时自动切换到 GitHub，然后安装到 `.codex\skills`。

### Release 双击安装

从 GitHub Releases 或 Gitee Releases 下载对应版本的安装脚本，双击运行即可。

例如：

```text
git-demand-skills-install-v0.2.0.bat
```

Release 里的安装脚本会锁定对应版本：下载 `v0.2.0` 的安装脚本，就会安装 `v0.2.0` 的项目代码。

仓库根目录里的 `git-demand-skills-current-install.bat` 用于安装当前最新版，适合自己调试或始终想跟随最新代码的人使用。

固定版本安装脚本作为 Release 附件保存，不需要长期提交在 `main` 分支里。需要发布新版本时，用下面的发布脚本生成对应版本的 bat，再上传到对应 Release。

历史版本不会受 main 分支改动影响。比如之前 Release 里已经发布的旧版本安装脚本，仍然只会安装它对应 tag 里的 `demand-submit` 能力，不会自动混入新版本的 `demand-merge`。

安装脚本只是安装入口。它会自动拉取完整项目，并把 skill 安装到：

```text
%USERPROFILE%\.codex\skills\demand-submit
%USERPROFILE%\.codex\skills\demand-merge
```

不要求必须安装 Codex。安装入口只是写入用户目录下的 `.codex\skills`；只要你的 AI 工具支持扫描 `.codex\skills`，就可以加载这个 skill。

真正执行 Git 流程的脚本仍然留在当前项目里：

```text
<clone-path>\scripts\demand-submit.ps1
<clone-path>\scripts\demand-merge.ps1
```

安装时会自动把 Skill 里的脚本路径替换成你本机的真实 clone 路径，所以这个项目可以放在任意目录。

## 发布新版本

以后发新版本时，不需要手写固定版本安装器。

维护这个工具仓库时，提交到 GitHub / Gitee 的 commit message 建议使用中文，并在标题里说明本次推送修改或补充了哪些能力，方便回看历史。

例如要发布 `v0.2.0`：

```powershell
git tag v0.2.0
git push origin v0.2.0
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-release-installer.ps1 v0.2.0
```

脚本会生成：

```text
release-installers\git-demand-skills-install-v0.2.0.bat
```

把这个 bat 上传到 `v0.2.0` 的 Release 附件里即可。用户双击这个安装器时，会安装 `v0.2.0` 对应的项目代码，而不是安装 `main` 最新代码。

仓库里的 `git-demand-skills-current-install.bat` 只用于安装当前最新版，不建议作为固定版本 Release 附件使用。

## 卸载

如果不再使用，打开安装时选择的项目目录，在 `git-demand-skills` 根目录里双击：

```text
git-demand-skills-uninstall.bat
```

卸载脚本不会再反复询问，会直接删除：

- `%USERPROFILE%\.codex\skills\demand-submit`
- `%USERPROFILE%\.codex\skills\demand-merge`
- clone 下来的 `git-demand-skills` 项目目录
- 项目目录里的 `demand-skill-logs`
- 旧版本遗留在 `%USERPROFILE%\.codex` 下的提交保护记录

如果只想清理日志，不卸载工具，可以在 `git-demand-skills` 根目录里双击：

```text
git-demand-skills-clear-logs.bat
```

如果编辑器或终端还打开在项目目录里，Windows 可能会暂时删不干净；关闭占用后重新执行卸载即可。

## 在 Codex 中使用

安装后，新开一个 Codex 会话，然后直接说：

```text
用 demand-submit 提交当前仓库，需求号 197462，标题“壮医诊断改造”
```

Codex 会根据 Skill 自动调用脚本，不需要你每次手动找脚本路径。

如果要把 `master` 上某个需求归并到 11 分支，可以直接说：

```text
用 demand-merge 把电子病历前端 2063657 合并到 11 分支，标题“AI病历智能辅写AI按钮逻辑调整”
```

`11` 会按 `release-1.11` 理解，默认创建 `2063657-11` 分支，最终提交信息仍是 `[2063657] 标题`。

## 给 AI 工具的终端提醒

Windows 上默认按 PowerShell 处理命令，不要把 Bash、CMD、PowerShell 的语法混用。

PowerShell 里应该这样写：

```powershell
Set-Location -LiteralPath "D:\gitProgram\your-repo"
git status --short --branch
```

不要在 PowerShell 里用这些写法：

```text
cd repo && git status
cd /d D:\repo & git status
timeout /t 30 /nobreak >nul
```

如果 AI 工具有 `workdir` / 工作目录参数，优先直接把工作目录设成仓库路径，再单独执行 Git 命令。

## IDEA / WebStorm 只提交部分文件

如果你只想提交某些文件，不想把本地端口配置、IDE 文件、运行服务生成文件一起提交，推荐使用 IDEA / WebStorm 的 `Staged` 区。

在 IDEA / WebStorm 里：

```text
Staged      = 这次要提交的文件
Unstaged    = 继续留在本地、不提交的文件
```

只需要把要提交的文件放进 `Staged`，不需要在 IDEA 里点 commit。

然后让 AI 执行：

```text
用 demand-submit 只提交暂存文件，需求号 197462，标题“需求标题”
```

或直接执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -StagedOnly
```

`-StagedOnly` 会记录脚本运行前已经暂存的文件，切换基础分支并恢复改动后，只重新暂存这些文件并提交。未暂存文件会继续留在本地工作区，不进入 commit。

注意：`-StagedOnly` 是按“文件”处理，不是按“代码块/hunk”处理。如果同一个文件里既有已暂存改动，又有未暂存改动，脚本恢复后会重新暂存这个文件的当前完整改动。建议在 IDEA / WebStorm 里先把要提交的文件整理成“这个文件可以整体提交”的状态。

为了防止 AI 忘记加 `-StagedOnly`，脚本现在有一个强制保护：

```text
如果同时存在 Staged 文件和 Unstaged / Untracked 文件，
并且命令里既没有 -StagedOnly，也没有 -All，
脚本会直接停止，不会自动提交。
```

这种情况通常表示你已经在 IDEA / WebStorm 里选择了本次要提交的文件，所以 AI 应该使用 `-StagedOnly`。只有你明确说“提交全部本地改动”时，才应该使用 `-All`。

对 AI 工具的要求是：看到这种混合状态时，不要再问用户“提交暂存区还是提交全部”。直接按 IDEA / WebStorm 的 Staged 选择执行 `-StagedOnly`。用户明确说“全部提交”“提交所有本地改动”时，才使用 `-All`。

可以用下面的命令确认哪些文件会被提交：

```powershell
git diff --cached --name-only
```

## 在其他本地 AI 工具中使用

如果是 CatPaw、Trae 或其他能执行本地命令的 AI 工具，可以让它执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -All
```

如果你已经在 IDEA / WebStorm 里把文件放进 `Staged`，让它执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -StagedOnly
```

如果脚本遇到冲突并停止，可以继续让 AI：

```text
查看 git status，分析冲突文件，保留两边代码意图后解决冲突，运行 git diff --check，然后按 [197462] 需求标题 的格式提交并推送。
```

## demand-merge：把需求归并到 release 分支

`demand-merge` 用于“把 master 上某个需求补到 11 分支 / release 分支”的场景。它底层使用 `cherry-pick --no-commit`，不是整分支 merge。

典型说法：

```text
电子病历前端 2063657 合并到 11 分支
```

这种写法里，“电子病历前端”只是项目/模块提示，不是提交标题。脚本会从 `master` 上匹配到的 `[2063657]` commit message 自动推断真实标题。

如果同一个需求号在 `master` 上有多次提交，并且提交名很像，可以补充时间：

```text
电子病历前端 2063657 2026-05-21 11:01 以后合并到 11 分支
```

直接执行脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-merge.ps1" 2063657 -TargetBranch 11
```

只本地执行、不推送：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-merge.ps1" 2063657 -TargetBranch 11 -NoPush
```

如果用户明确给了真实需求标题，才把标题作为第二个参数传入。

它会做这些事：

1. 要求当前工作区干净，避免混入本地开发改动。
2. 拉取远程分支信息。
3. 把 `11` 转成 `release-1.11`。
4. 基于最新 `origin/release-1.11` 创建 `2063657-11`。
5. 在 `origin/master` 中查找 commit message 包含 `[2063657]` 的提交。
6. 按时间从旧到新 cherry-pick。
7. 没有冲突时，压成一个 `[2063657] 标题` 提交并推送。
8. 有冲突时，停止并输出冲突文件和日志路径，交给 AI/人工分析后继续提交。

冲突时不要直接选 ours/theirs。应该让 AI 查看：

```powershell
git status --short
git diff --name-only --diff-filter=U
git diff --cc -- <file>
git show <source-commit> -- <file>
```

解决后再执行：

```powershell
git add -- <resolved-files>
git diff --check
git commit -m "[2063657] AI病历智能辅写AI按钮逻辑调整"
git push -u origin 2063657-11
```

## demand-submit 会做什么

1. 在 `<clone-path>\demand-skill-logs` 下记录当前状态和 patch。
2. stash 当前已跟踪和未跟踪的改动。
3. fetch 远端并从最新 `origin/<baseBranch>` 直接创建需求分支：
   - 不切到本地基础分支，不执行 `pull`，避免远端频繁推送导致 `--ff-only` 失败；
   - 如果本地已有同名需求分支，先改名备份为 `<需求号>-backup-时间戳`；
   - 不复用远程同名需求分支；
   - 始终从最新 `origin/<baseBranch>` 创建新的需求分支。
4. 恢复刚才 stash 的改动。
5. 如果发生冲突，立即停止，不 commit、不 push。
6. 如果没有冲突：
   - `-All` 模式会执行 `git add -A`，提交全部改动；
   - `-StagedOnly` 模式只提交脚本运行前已经暂存的文件。
   - 如果脚本发现同时存在 `Staged` 和 `Unstaged / Untracked`，但命令里没有显式传 `-StagedOnly` 或 `-All`，它会停止，防止 AI 误提交全部文件。

## 日志和冲突处理

脚本每次执行前会把当前仓库状态写入：

```text
<clone-path>\demand-skill-logs
```

里面通常包含：

```text
branch.txt
status.txt
working-tree.patch
staged.patch
staged-files.txt
```

如果提交失败、冲突没处理好，或者你不确定脚本执行到哪一步，可以把对应日志目录路径复制给 AI，让 AI 根据这些文件分析失败原因和恢复方式。

`demand-skill-logs` 已经加入 `.gitignore`，不会被提交到这个工具仓库。如果日志太多，可以双击 `git-demand-skills-clear-logs.bat` 手动清理。

如果 `stash pop` 或恢复改动时发生冲突，脚本会停止并保留冲突现场。此时不要直接提交或推送，应该让 AI 或 IDE 继续处理：

```text
查看 git status，打开冲突文件，结合上下文合并冲突，运行 git diff --check，必要时运行项目的最小验证，确认无误后再 git add、commit、push。
```

脚本不再切换到本地基础分支或执行 `pull`，而是直接从 `origin/<baseBranch>` 创建需求分支，因此不会因为远端频繁推送而失败。

## 分支策略

脚本默认不会复用本地或远程已有的需求分支。每次提交都会从最新的 `origin/<baseBranch>` 创建一个干净的需求分支。

如果本地已经存在同名需求分支，例如 `190281`，脚本会先把它改名为：

```text
190281-backup-20260518-101500
```

然后重新从 `origin/<baseBranch>` 创建新的 `190281` 分支。这样可以避免旧需求分支、已合并 MR 分支、或本地残留分支影响新提交。

## 常用示例

默认分支名就是需求号：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -All
```

指定仓库路径或别名：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -All -RepoPath "D:\gitProgram\onelink-web-doctor"
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -All -RepoPath "医生前端"
```

`-RepoPath` 支持绝对路径或别名。别名定义在 `~/.claude/repo-aliases.json`，例如：

```json
{
  "护士前端": "D:/gitProgram/onelink-web-nurse",
  "医生前端": "D:/gitProgram/onelink-web-doctor",
  "医生后端": "D:/gitProgram/onelink-micro-cis-doctor"
}
```

每个用户在本地创建自己的别名文件，脚本找不到该文件时会忽略。如果 `-RepoPath` 是绝对路径且目录存在，直接使用；如果是别名，从配置文件解析。

指定基线分支，例如基于 `release-1.44`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -BaseBranch release-1.44 -All
```

只提交 IDEA / WebStorm Staged 里的文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -StagedOnly
```

给需求分支加前缀：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -BranchPrefix "feature/" -All
```

指定完整分支名：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -BranchName "197462-1.44" -All
```

只 commit，不 push：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<clone-path>\scripts\demand-submit.ps1" 197462 "需求标题" -NoPush -All
```

## 安全策略

- 不会往 `master` 提交。
- 不会创建或合并 Merge Request。
- 遇到冲突会停止，不会推送冲突代码。
- 不切到本地基础分支，不执行 `pull`，直接从 `origin/<baseBranch>` 创建需求分支。
- `-StagedOnly` 模式不会提交未暂存文件。
- 如果同时存在已暂存和未暂存/未跟踪文件，AI 应该直接使用 `-StagedOnly`，不要反复询问；只有用户明确要求提交全部时才使用 `-All`。
- 不会复用本地或远程旧需求分支，会从最新 `origin/<baseBranch>` 创建干净分支。
- 执行前会在项目目录生成日志和 patch，便于失败后分析。
- 直接从远端 `origin/<baseBranch>` 创建需求分支，避免本地基础分支落后导致失败。
- 建议同一时间只让一个工具执行 Git 操作，避免 IDEA、Codex、CatPaw 同时切分支。


