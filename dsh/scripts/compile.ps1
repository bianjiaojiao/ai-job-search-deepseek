#requires -Version 5.1
<#
.SYNOPSIS
  ai-job-search LaTeX 编译（DeepSeek / DSH 原生版）

.DESCRIPTION
  统一编译入口，并在编译后可选地做页数 + 文本层校验。
  - CV：lualatex（moderncv 的 fontawesome5 在 pdflatex 下常炸）
  - 求职信：xelatex（cover.cls 需要 fontspec）
  - 中文模板：xelatex（ctexart + xeCJK）
  编译在临时目录进行，只把 PDF 拷回源目录，不在仓库里留 .aux/.log/.out。

.PARAMETER Tex
  相对仓库根或绝对路径的 .tex 文件。

.PARAMETER Pages
  >0 时编译完立刻校验页数（CV 2 页 / 求职信 1 页 / 应届生中文简历 1 页）。

.EXAMPLE
  ./compile.ps1 -Repo C:\code\ai-job-search -Tex "cv\main_acme_ml-engineer.tex" -Engine lualatex -Pages 2

.EXAMPLE
  ./compile.ps1 -Tex "cover_letters\cover_acme_ml-engineer.tex" -Engine xelatex -Pages 1

.EXAMPLE
  ./compile.ps1 -Tex "templates\cjk-cv\template.tex" -Engine xelatex -Pages 1
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Tex,
  [ValidateSet('lualatex','xelatex','pdflatex')]
  [string]$Engine = 'lualatex',
  [int]$Pages = 0,
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
  # ① 安装成 DSH 技能后：技能目录里的 repo.txt 记录仓库位置（install 脚本写入）
  $repoFile = Join-Path $PSScriptRoot '..\repo.txt'
  if (Test-Path $repoFile) {
    $p = (Get-Content $repoFile -Raw -ErrorAction SilentlyContinue)
    if ($p) {
      $p = $p.Trim()
      if ((Test-Path $p) -and (Test-Path (Join-Path $p 'tools\verify_pdf.py'))) { return (Resolve-Path $p).Path }
    }
  }
  # ② 直接运行仓库里的脚本：从脚本自身位置 / 当前目录向上找
  foreach ($start in @($PSScriptRoot, (Get-Location).Path)) {
    if (-not $start) { continue }
    $d = $start
    while ($d) {
      if (Test-Path (Join-Path $d 'tools\verify_pdf.py')) { return $d }
      $parent = Split-Path $d -Parent
      if (-not $parent -or $parent -eq $d) { break }
      $d = $parent
    }
  }
  throw "找不到 ai-job-search 仓库根。请用 -Repo 指定，或设置环境变量 AI_JOB_SEARCH_REPO=<仓库路径>，或 cd 到仓库目录再运行。"
}

$repo = Resolve-RepoPath $Repo
if (-not $env:PYTHONUTF8) { $env:PYTHONUTF8 = '1' }

function Resolve-Engine([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) {
    $p = if ($cmd.Path) { $cmd.Path } elseif ($cmd.Definition) { $cmd.Definition } else { $null }
    if ($p -and (Test-Path $p)) { return $p }
  }
  $roots = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\MiKTeX\miktex\bin\x64'),
    'C:\Program Files\MiKTeX\miktex\bin\x64',
    (Join-Path $env:USERPROFILE 'AppData\Local\Programs\MiKTeX\miktex\bin\x64')
  )
  foreach ($r in $roots) {
    $cand = Join-Path $r "$name.exe"
    if (Test-Path $cand) { return $cand }
  }
  throw "找不到 $name。装 MiKTeX（winget install MiKTeX.MiKTeX）或 TeX Live 后重试。"
}

function Resolve-Target([string]$p, [string]$root) {
  if ([System.IO.Path]::IsPathRooted($p)) { return $p }
  return (Join-Path $root $p)
}

$texPath = Resolve-Target $Tex $repo
if (-not (Test-Path $texPath)) { throw "找不到 tex 文件: $texPath" }
$texDir  = Split-Path $texPath -Parent
$texName = Split-Path $texPath -Leaf
$base    = [System.IO.Path]::GetFileNameWithoutExtension($texName)

$exePath = Resolve-Engine $Engine
Write-Verbose "engine = $exePath"

$buildDir = Join-Path $env:TEMP "ai-job-search-build\$base"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Write-Host "==> $Engine $texName  (输出到 $buildDir)"
$runLog = Join-Path $buildDir "$base.runlog"
Push-Location $texDir
try {
  # PS 5.1：原生程序写 stderr 在 EAP=Stop 下会被当成终止错误，故降级并用 *> 落盘
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $exePath -interaction=nonstopmode -halt-on-error "-output-directory=$buildDir" $texName *> $runLog
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prevEap
}
finally { Pop-Location }

$pdf = Join-Path $buildDir "$base.pdf"
if ($code -ne 0 -or -not (Test-Path $pdf)) {
  $log = Join-Path $buildDir "$base.log"
  if (Test-Path $log) {
    Write-Host "---- 最后 25 行日志 ----"
    Get-Content $log -Tail 25
    Write-Host "------------------------"
  }
  throw "编译失败（退出码 $code）。修正 .tex 后重试。"
}

$dest = Join-Path $texDir "$base.pdf"
Copy-Item -Path $pdf -Destination $dest -Force
Write-Host "PDF 已生成: $dest ($([math]::Round((Get-Item $dest).Length/1KB,1)) KB)"

if ($Pages -gt 0) {
  Write-Host "==> 页数与文本层校验（要求 $Pages 页）"
  & python (Join-Path $repo 'tools\verify_pdf.py') $dest --pages $Pages
  if ($LASTEXITCODE -ne 0) { throw "页数/文本层校验未通过" }
}

exit 0
