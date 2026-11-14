#requires -Version 5.1
<#
.SYNOPSIS
  ai-job-search 抓岗统一入口（DeepSeek / DSH 原生版）

.DESCRIPTION
  封装 .agents/skills/*/cli 的 bun 调用，避免每次手写长命令。
  默认门户 freehire（全球技术岗，无需登录）；丹麦四门户可显式指定。
  调用哪个门户取决于你装了哪个 skill —— 本脚本只负责组装参数，不做网络请求。

  LinkedIn 在本脚本中**不提供**：linkedin-search 依赖 LinkedIn 公开 jobs-guest 页面，
  在中国大陆等地区会返回 HTTP 451 Unavailable_For_Legal_Reasons（IP 属地限制），
  有境外出口时可自行直接调用 .agents/skills/linkedin-search。

.PARAMETER Repo
  仓库根目录。不填时依次尝试：环境变量 AI_JOB_SEARCH_REPO → 从当前目录向上找
  含 tools/verify_pdf.py 的目录。

.EXAMPLE
  ./scrape.ps1 -Repo C:\code\ai-job-search -Query "machine learning" -Category ml_ai -Remote remote -Limit 10

.EXAMPLE
  ./scrape.ps1 -Query "行政助理" -Region apac -Country CN -Limit 10

.EXAMPLE
  ./scrape.ps1 -Detail "machine-learning-solutions-architect-phdata-2nopqtvs"
#>
[CmdletBinding()]
param(
  [string]$Query,
  [string]$Detail,
  [ValidateSet('freehire','jobindex','jobnet','jobbank','jobdanmark')]
  [string]$Portal = 'freehire',
  [string[]]$Category,
  [string[]]$Skill,
  [string[]]$Region,
  [string[]]$Country,
  [string[]]$City,
  [string]$Seniority,
  [ValidateSet('remote','hybrid','onsite')]
  [string]$Remote,
  [int]$Limit = 10,
  [int]$JobAge,
  [ValidateSet('table','plain','json')]
  [string]$Format = 'table',
  [string]$Repo
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoPath([string]$explicit) {
  if ($explicit) {
    if (-not (Test-Path $explicit)) { throw "指定的仓库不存在: $explicit" }
    return (Resolve-Path $explicit).Path
  }
  $envRepo = $env:AI_JOB_SEARCH_REPO
  if ($envRepo -and (Test-Path $envRepo)) { return (Resolve-Path $envRepo).Path }
  $d = (Get-Location).Path
  while ($d) {
    if (Test-Path (Join-Path $d 'tools\verify_pdf.py')) { return $d }
    $p = Split-Path $d -Parent
    if (-not $p -or $p -eq $d) { break }
    $d = $p
  }
  throw "找不到 ai-job-search 仓库根。请用 -Repo 指定，或设置环境变量 AI_JOB_SEARCH_REPO=<仓库路径>，或先 cd 到仓库目录再运行。"
}

function Resolve-Bun {
  $cmd = Get-Command bun -ErrorAction SilentlyContinue
  if ($cmd) {
    $p = if ($cmd.Path) { $cmd.Path } elseif ($cmd.Definition) { $cmd.Definition } else { $null }
    if ($p -and (Test-Path $p)) { return $p }
  }
  $candidates = @(
    (Join-Path $env:APPDATA 'npm\bun.exe'),
    (Join-Path $env:USERPROFILE '.bun\bin\bun.exe'),
    'C:\Program Files\nodejs\bun.exe'
  )
  foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
  throw "找不到 bun。安装：https://bun.sh （Windows: powershell -c `"irm bun.sh/install.ps1 | iex`"），或 npm i -g bun。"
}

$repo = Resolve-RepoPath $Repo
$cli  = Join-Path $repo ".agents\skills\${Portal}-search\cli\src\cli.ts"
if (-not (Test-Path $cli)) {
  throw "找不到门户 CLI: $cli`n先安装依赖：python tools\install_portal_clis.py（在仓库根执行）"
}

$bun = Resolve-Bun
$code = 0

Push-Location $repo
try {
  if ($Detail) {
    $cliArgs = @('run', $cli, 'detail', $Detail, '--format', $Format)
  }
  else {
    if (-not $Query) { throw "需要 -Query 或 -Detail" }
    $cliArgs = @('run', $cli, 'search', '-q', $Query, '--limit', "$Limit", '--format', $Format)
    if ($Portal -eq 'freehire') {
      if ($Category)  { $cliArgs += @('--category',  ($Category -join ',')) }
      if ($Skill)     { $cliArgs += @('--skill',     ($Skill -join ',')) }
      if ($Region)    { $cliArgs += @('--region',    ($Region -join ',')) }
      if ($Country)   { $cliArgs += @('--country',   ($Country -join ',')) }
      if ($City)      { $cliArgs += @('--city',      ($City -join ',')) }
      if ($Seniority) { $cliArgs += @('--seniority', $Seniority) }
      if ($Remote)    { $cliArgs += @('--remote',    $Remote) }
      if ($JobAge)    { $cliArgs += @('--jobage',    "$JobAge") }
    }
  }
  Write-Verbose ("bun " + ($cliArgs -join ' '))
  & $bun @cliArgs
  $code = $LASTEXITCODE
}
finally {
  Pop-Location
}

if ($code -ne 0) { throw "CLI 退出码 $code（查看上面的 error 字段）" }
exit 0
