#requires -Version 5.1
<#
.SYNOPSIS
  把 DeepSeek(DSH) 适配层安装成用户级技能（Windows / PowerShell）

.DESCRIPTION
  本脚本只做三件事：拷贝技能文件、记录仓库路径、做一次环境自检。
  它不修改你的仓库、不删除任何文件、不联网。

  安装位置：%USERPROFILE%\.dsh\skills\ai-job-search
  装上之后，DSH 会话在任意目录都能发现并使用该技能。

.PARAMETER Repo
  ai-job-search 仓库根目录。默认取本脚本所在目录（dsh/）的上一级。

.PARAMETER Target
  技能安装目录。默认 %USERPROFILE%\.dsh\skills\ai-job-search

.PARAMETER Force
  目标已存在时覆盖同名文件（只覆盖，不删除多余文件）。

.PARAMETER SetEnvVar
  额外把 AI_JOB_SEARCH_REPO 写入用户环境变量（脚本自动定位不到仓库时有用）。

.EXAMPLE
  ./dsh/install.ps1

.EXAMPLE
  ./dsh/install.ps1 -Repo D:\code\ai-job-search -SetEnvVar
#>
[CmdletBinding()]
param(
  [string]$Repo,
  [string]$Target,
  [switch]$Force,
  [switch]$SetEnvVar
)

$ErrorActionPreference = 'Stop'

# ---- 定位仓库 ----
if (-not $Repo) { $Repo = Split-Path $PSScriptRoot -Parent }
if (-not (Test-Path $Repo)) { throw "仓库不存在: $Repo" }
$Repo = (Resolve-Path $Repo).Path
if (-not (Test-Path (Join-Path $Repo 'tools\verify_pdf.py'))) {
  throw "这个目录看起来不是 ai-job-search 仓库（缺 tools\verify_pdf.py）: $Repo"
}

# ---- 定位安装目录 ----
if (-not $Target) {
  if (-not $env:USERPROFILE) { throw "无法确定用户目录，请用 -Target 指定" }
  $Target = Join-Path $env:USERPROFILE '.dsh\skills\ai-job-search'
}
if (Test-Path $Target) {
  if (-not $Force) {
    Write-Host "目标已存在: $Target" -ForegroundColor Yellow
    Write-Host "重装请加 -Force（只覆盖同名文件，不删除其它文件）。"
    exit 1
  }
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null

# ---- 拷贝 ----
$items = @('SKILL.md')
foreach ($dir in @('references','scripts')) {
  $src = Join-Path $PSScriptRoot $dir
  if (Test-Path $src) { $items += $dir }
}

foreach ($item in $items) {
  $src = Join-Path $PSScriptRoot $item
  $dst = Join-Path $Target $item
  if (-not (Test-Path $src)) { Write-Host "WARN 缺少: $src" -ForegroundColor Yellow; continue }
  Copy-Item -Path $src -Destination $dst -Recurse -Force
  Write-Host "  + $item"
}

# ---- 记录仓库路径（技能运行时据此定位 .claude/commands 与 tools/）----
$repoFile = Join-Path $Target 'repo.txt'
Set-Content -Path $repoFile -Value $Repo -Encoding UTF8
Write-Host "  + repo.txt -> $Repo"

if ($SetEnvVar) {
  [Environment]::SetEnvironmentVariable('AI_JOB_SEARCH_REPO', $Repo, 'User')
  Write-Host "  + 用户环境变量 AI_JOB_SEARCH_REPO=$Repo（新开终端生效）"
}

# ---- 环境自检（只报，不阻断）----
Write-Host ""
Write-Host "环境自检：" -ForegroundColor Cyan
function Probe([string]$name, [scriptblock]$check, [string]$hint) {
  try { $ok = & $check } catch { $ok = $false }
  if ($ok) { Write-Host ("  [OK]   " + $name) -ForegroundColor Green }
  else { Write-Host ("  [MISS] " + $name + "  → " + $hint) -ForegroundColor Yellow }
}
Probe 'python' { $null -ne (Get-Command python -ErrorAction SilentlyContinue) } '安装 Python 3.10+ 并加入 PATH'
Probe 'pypdf'  { python -c "import pypdf" 2>$null; $LASTEXITCODE -eq 0 } 'python -m pip install pypdf'
Probe 'bun'    { $null -ne (Get-Command bun -ErrorAction SilentlyContinue) } 'https://bun.sh  或  npm i -g bun'
# LaTeX 可能刚装好、当前进程的 PATH 还没刷新，所以额外查一遍常见安装目录
function Find-Latex([string]$exe) {
  if ($null -ne (Get-Command $exe -ErrorAction SilentlyContinue)) { return $true }
  foreach ($r in @(
      (Join-Path $env:LOCALAPPDATA 'Programs\MiKTeX\miktex\bin\x64'),
      'C:\Program Files\MiKTeX\miktex\bin\x64')) {
    if (Test-Path (Join-Path $r "$exe.exe")) { return $true }
  }
  return $false
}
Probe 'lualatex' { Find-Latex 'lualatex' } 'winget install MiKTeX.MiKTeX（新开终端后生效）'
Probe 'xelatex'  { Find-Latex 'xelatex' }  '同上（求职信/中文模板需要 xelatex）'
Probe 'PYTHONUTF8=1' { $env:PYTHONUTF8 -eq '1' -or [Environment]::GetEnvironmentVariable('PYTHONUTF8','User') -eq '1' } '中国区 Windows 建议设置，避免 GBK 编码报错'
Probe '门户 CLI 依赖' { Test-Path (Join-Path $Repo '.agents\skills\freehire-search\cli\node_modules') } '在仓库根执行 python tools\install_portal_clis.py'

# ---- 执行策略提醒（很多人卡在这里）----
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Restricted', 'AllSigned')) {
  Write-Host ""
  Write-Host "提示：当前 PowerShell 执行策略是 $policy，直接 & 调用 .ps1 会被拒绝。" -ForegroundColor Yellow
  Write-Host "  两种做法（任选其一）："
  Write-Host "    1) 用 .cmd 包装器：dsh\scripts\scrape.cmd / compile.cmd / verify.cmd"
  Write-Host "    2) 或 powershell -NoProfile -ExecutionPolicy Bypass -File dsh\scripts\scrape.ps1 ..."
  Write-Host "    3) 或一次性放开：Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
}

Write-Host ""
Write-Host "完成。技能已装到: $Target" -ForegroundColor Cyan
Write-Host "DSH 会话里说「用 ai-job-search 帮我…」即可触发；或直接读 $Target\SKILL.md。"
Write-Host "仓库路径已记录在 $repoFile，换仓库位置后重跑本脚本即可。"
