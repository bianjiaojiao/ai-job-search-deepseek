#requires -Version 5.1
<#
.SYNOPSIS
  ai-job-search PDF 校验（DeepSeek / DSH 原生版）：页数 + ATS 文本层 + 排版

.DESCRIPTION
  verify_pdf    : 页数硬限制 + 文本层可提取性（pypdf 优先，pdftotext 兜底）
  verify_layout : 每页文字起止、底部空白占比、最大纵向空洞、孤立标题

  注意：--dump-text 只能写到仓库内 cv/ 或 cover_letters/（仓库安全守卫）。

.PARAMETER Pdf
  相对仓库根或绝对路径的 PDF。

.PARAMETER DumpText
  可选。把文本层写出到 .txt，用于逐步核对 ATS 实际读到的内容。必须位于 cv/ 或 cover_letters/ 内。

.EXAMPLE
  ./verify.ps1 -Repo C:\code\ai-job-search -Pdf "cv\main_acme_ml-engineer.pdf" -Pages 2 -DumpText "cv\main_acme_ml-engineer.txt"

.EXAMPLE
  ./verify.ps1 -Pdf "cover_letters\cover_acme_ml-engineer.pdf" -Pages 1

.EXAMPLE
  ./verify.ps1 -Pdf "templates\cjk-cv\template.pdf" -Pages 1 -SkipLayout
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Pdf,
  [int]$Pages = 0,
  [string]$DumpText,
  [switch]$SkipLayout,
  [string]$Repo
)

# PS 5.1 下原生程序写 stderr 会被当成终止错误，这里用 Continue + 退出码判定
$ErrorActionPreference = 'Continue'

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

if (-not $env:PYTHONUTF8) { $env:PYTHONUTF8 = '1' }

# verify_layout 需要 pdftotext（MiKTeX 自带一份；找不到就是降级 WARN，不是失败）
$miktexRoots = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\MiKTeX\miktex\bin\x64'),
  'C:\Program Files\MiKTeX\miktex\bin\x64'
)
foreach ($r in $miktexRoots) {
  if ((Test-Path $r) -and (($env:PATH -split ';') -notcontains $r)) { $env:PATH = "$r;$env:PATH"; break }
}

$repo = Resolve-RepoPath $Repo
if (-not ([System.IO.Path]::IsPathRooted($Pdf))) { $Pdf = Join-Path $repo $Pdf }
if (-not (Test-Path $Pdf)) { throw "找不到 PDF: $Pdf" }

$failed = @()

Write-Host "==> verify_pdf.py  $([System.IO.Path]::GetFileName($Pdf))"
$vArgs = @((Join-Path $repo 'tools\verify_pdf.py'), $Pdf)
if ($Pages -gt 0) { $vArgs += @('--pages', "$Pages") }
if ($DumpText) {
  if (-not ([System.IO.Path]::IsPathRooted($DumpText))) { $DumpText = Join-Path $repo $DumpText }
  $vArgs += @('--dump-text', $DumpText)
}
& python @vArgs
if ($LASTEXITCODE -ne 0) { $failed += 'verify_pdf' }

if (-not $SkipLayout) {
  Write-Host "==> verify_layout.py $([System.IO.Path]::GetFileName($Pdf))"
  & python (Join-Path $repo 'tools\verify_layout.py') $Pdf
  $layoutCode = $LASTEXITCODE
  if ($layoutCode -eq 2) {
    Write-Host "WARN: 排版检测被跳过（缺 Poppler pdftotext 或提取器不支持 -bbox）。页数/文本层不受影响。" -ForegroundColor Yellow
  }
  elseif ($layoutCode -ne 0) { $failed += 'verify_layout' }
}

Write-Host ''
if ($failed.Count -gt 0) {
  Write-Host "结果: FAIL ($($failed -join ', '))" -ForegroundColor Red
  Write-Host "常见处置："
  Write-Host "  - 页数不对      → 按 05-cv-templates.md 的相关性加权裁剪/补足"
  Write-Host "  - 孤立 cventry  → 条目前加 \needspace{5\baselineskip}"
  Write-Host "  - 底部空洞      → \enlargethispage{2-3\baselineskip}"
  Write-Host "  - (cid:*) / 乱码 → 换字体或改 fontspec；重编后重新提取"
  exit 1
}

Write-Host "结果: PASS" -ForegroundColor Green
exit 0
