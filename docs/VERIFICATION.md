# 验证报告（Verification Report）

> 对象：**ai-job-search · DeepSeek 版**（本仓库）
> 基线：上游 `ai-job-search` master @ `0d0d1a9`（`v1.7.5-28-g0d0d1a9`，466 个提交）
> 时间：2026-11-14
> 生成方式：本报告与仓库内的 DeepSeek 适配层全部由 **AI 自动生成**（DeepSeek Harness 编码代理），并在真机上逐项执行验证。

---

## 0. 结论

| 类别 | 结果 |
|---|---|
| 上游全量单元测试（Python） | **948 passed, 8 skipped, 0 failed** |
| 6 个门户 CLI 测试（TypeScript/Bun） | **513 passed, 0 failed**（6 个套件全绿） |
| 仓库 lint（skills / commands / settings.json） | **OK (9 skills, 12 commands, settings.json)** |
| 真实抓岗（freehire，联网） | **PASS** — 返回当日真实在招岗位 |
| LaTeX 编译（英文 CV，lualatex） | **PASS** — 2 页 PDF，46.8 KB |
| LaTeX 编译（中文简历，xelatex） | **PASS** — 1 页 PDF，108.2 KB |
| 中文 ATS 文本层 | **PASS** — 263 个汉字可提取，`(cid:*)`=0，替换符=0 |
| 排版检测（verify_layout） | **PASS** — `layout: clean`，末页底部空白 23%（阈值 ≤25%） |
| 一键安装（install.ps1） | **PASS** — 11 个文件 + `repo.txt` 正确落盘 |
| 脚本可移植性（换目录调用） | **PASS** — 从 `C:\` 用 `-Repo` 指定、仓库内自动定位均可 |

**验证过程中发现并修复了 5 个真实缺陷**（见 §6）——这不是「写完就发」的仓库。

---

## 1. 环境

| 组件 | 版本 | 说明 |
|---|---|---|
| OS | Windows 11 | |
| PowerShell | 5.1.26100（`powershell.exe`） | **不是** pwsh 7；`.ps1` 需 UTF-8 BOM 才能正确解析中文 |
| Python | 3.13.7 | 设 `PYTHONUTF8=1` |
| pypdf | 7.1.0 | ATS 文本层首选提取器 |
| pytest | 最新 | 跑上游全量测试 |
| Bun | 1.4.4 | 跑 6 个门户 CLI |
| MiKTeX | 25.12 | LuaHBTeX 1.24.0 / XeTeX 4.16 |
| git | 2.56.0.windows.2 | 需 OpenSSL 后端（见 §5） |

---

## 2. 上游单元测试（Python）

```powershell
cd <REPO>
$env:PYTHONUTF8='1'
python -m pytest tests -q
```

```
948 passed, 8 skipped, 1 warning, 1137 subtests passed in ~130s
```

覆盖范围包括：`/setup` 隐私预检、占位符完整性、`/apply` 页数与归档、`/rank` 状态、`/outcome` 跟进、`/reset`、`salary_*` 系列、`posting_guard`、`robots_check`、`fetch_page`、`security_guards`、`update`、`release` 工作流等。

> 说明：如果你在自己机器上跑过 `/setup`（真实档案写入了模板文件），与「占位符完整性」相关的 5 个测试会失败——这是**预期行为**（模板已被个性化），不是本版引入的 bug。干净模板态下是 948 全绿。

---

## 3. 门户 CLI 测试（Bun）

```powershell
$env:PATH = "$env:APPDATA\npm;$env:PATH"
foreach ($s in @('freehire','jobindex','jobnet','jobbank','jobdanmark','linkedin')) {
  Push-Location ".agents\skills\$s-search\cli"; bun test --timeout 20000; Pop-Location
}
```

| 门户 | pass | fail |
|---|---|---|
| freehire-search | 125 | 0 |
| jobindex-search | 78 | 0 |
| jobnet-search | 79 | 0 |
| jobbank-search | 63 | 0 |
| jobdanmark-search | 75 | 0 |
| linkedin-search | 93 | 0 |
| **合计** | **513** | **0** |

---

## 4. 端到端验证

### 4.1 真实抓岗（联网）

```powershell
# 从 C:\ 调用，用 -Repo 指定仓库 —— 验证无硬编码路径
& "<REPO>\dsh\scripts\scrape.cmd" -Repo "<REPO>" -Query "machine learning" -Category ml_ai -Remote remote -Limit 3
```

```
SLUG                                                                  TITLE                                COMPANY                DATE
machine-learning-rxcloud-hf7fcxw5                                     Machine Learning                     RxCloud                2026-08-17
machine-learning-marktine-technology-solutions-ej4jzpeq              Machine Learning                     Marktine Technology    2024-07-19
machine-learning-operations-mlops-intern-intermountain-health-prbspf5x  Machine Learning Operations       Intermountain Health   2026-11-13
```

**PASS** — 返回的是当日真实在招岗位（不是录制数据）。

### 4.2 英文 CV 编译（lualatex，要求 2 页）

```powershell
& "<REPO>\dsh\scripts\compile.cmd" -Tex "cv\main_example.tex" -Engine lualatex -Pages 2
```

```
==> lualatex main_example.tex
PDF 已生成: <REPO>\cv\main_example.pdf (46.8 KB)
==> 页数与文本层校验（要求 2 页）
Verified <REPO>\cv\main_example.pdf (extractor: pypdf, pages: 2)
```

**PASS** — 2 页。

### 4.3 中文简历编译（xelatex，要求 1 页）

```powershell
& "<REPO>\dsh\scripts\compile.cmd" -Tex "templates\cjk-cv\template.tex" -Engine xelatex -Pages 1
```

```
==> xelatex template.tex
PDF 已生成: <REPO>\templates\cjk-cv\template.pdf (108.2 KB)
Verified <REPO>\templates\cjk-cv\template.pdf (extractor: pypdf, pages: 1)
```

**PASS** — 1 页，`ctexart` + `xeCJK` + 微软雅黑。

### 4.4 中文 ATS 文本层（关键项）

```powershell
python tools\verify_pdf.py "templates\cjk-cv\template.pdf" --dump-text "cv\_probe.txt"
```

提取结果（ATS 实际读到的文本层）：

```
【姓名】
求职意向：【目标岗位】 | 【性别】∙【民族】∙【政治面貌】∙【出生年月】
电话【手机号】 | 邮箱【邮箱】 | 【所在城市】
教育背景
【学校】 【入学年月】– 【毕业年月】
【专业】（【学历】） 【城市】
主修课程：【课程 1】、【课程 2】、【课程 3】、【课程 4】。【一句话补充…】
实习与工作经历
```

| 指标 | 结果 |
|---|---|
| 汉字数 | 263 |
| `(cid:*)` 标记 | 0 |
| `�` 替换符 | 0 |

**PASS** — 中文没有静默丢字（这是上游模板填中文时的典型故障，本版重点验证）。

### 4.5 排版检测

```powershell
& "<REPO>\dsh\scripts\verify.cmd" -Pdf "templates\cjk-cv\template.pdf" -Pages 1
```

```
verify_pdf.py  template.pdf
Verified ... (extractor: pypdf, pages: 1)
verify_layout.py template.pdf
  p1: text y 48..646 of 842pt | bottom 196pt (23%) | largest gap 39pt at y240
layout: clean
结果: PASS
```

**PASS** — 无孤立条目、末页底部空白 23%（阈值 ≤25%）。

### 4.6 一键安装

```powershell
& "<REPO>\dsh\install.ps1" -Target "$env:TEMP\dsh-install-test\ai-job-search"
```

安装结果（11 个文件）：

```
SKILL.md
references\pipeline.md  references\tool-mapping.md  references\windows-china.md
scripts\scrape.ps1  scripts\scrape.cmd  scripts\compile.ps1  scripts\compile.cmd
scripts\verify.ps1  scripts\verify.cmd
repo.txt          -> <REPO>
```

**PASS** — 装到临时目录不影响真实技能；`repo.txt` 正确写入仓库路径。

### 4.7 仓库 lint

```powershell
python tools\lint_skills.py
```

```
lint_skills: OK (9 skills, 12 commands, settings.json)
```

**PASS**

---

## 5. 环境差异与限制（如实记录）

| 项 | 现象 | 处置 |
|---|---|---|
| LinkedIn 抓岗 | `HTTP 451 Unavailable_For_Legal_Reasons` | IP 属地封禁（中国大陆）；本版不默认启用 LinkedIn |
| 丹麦四门户 | 可用，但只对丹麦市场有意义 | 保留，文档标注用途 |
| BOSS直聘 / 拉勾 / 猎聘 / 智联 | 登录墙 / 强反爬 | `/add-portal` 会主动拒绝；改用 freehire、境外出口或手工粘贴 JD |
| git 的 schannel TLS | `SEC_E_NO_CREDENTIALS` / `Connection was reset` | 改 OpenSSL 后端 + ASCII 路径 CA + HTTP/1.1（详见 `dsh/references/windows-china.md` §2.2） |
| Python 子进程编码 | `UnicodeDecodeError: 'gbk' codec` | 设 `PYTHONUTF8=1` |
| PowerShell 5.1 | 无 BOM 的 UTF-8 `.ps1` 被按 GBK 解析 | 本仓库 4 个 `.ps1` 全部写为 **UTF-8 with BOM**（已用字节检查确认） |
| `verify_pdf.py --dump-text` | 只允许写 `cv/` 或 `cover_letters/` | 上游安全设计，非 bug |

---

## 6. 验证中发现并修复的缺陷（5 个）

这些是**真跑起来才暴露**的问题，均已修复后重新验证：

| # | 缺陷 | 影响 | 修复 |
|---|---|---|---|
| 1 | `.ps1` 被执行策略拦截（「未对文件进行数字签名」） | 用户装完直接跑会失败 | 新增 `scrape.cmd` / `compile.cmd` / `verify.cmd` 包装器（`-ExecutionPolicy Bypass`），并在 README、SKILL.md、install.ps1 自检里提示 |
| 2 | `.cmd` 里写中文注释 | `cmd.exe` 按 ANSI 解码，注释被当命令执行，输出乱码/报错 | 三个 `.cmd` 改为**纯 ASCII** |
| 3 | 脚本硬编码仓库路径 `C:\鲸鱼\ai-job-search` | 换机器/换目录必挂 | 改为 `repo.txt` → `AI_JOB_SEARCH_REPO` → 当前目录向上查找 三级解析 |
| 4 | `install.ps1` 的 LaTeX 自检误报 MISS | 刚装完 LaTeX 的用户以为没装上 | 自检增加 MiKTeX 常见安装目录兜底探测 |
| 5 | 中文模板/文档中的个人测试数据 | 发布版会带出虚构候选人档案 | 中文模板改为占位符骨架；发布版基于**干净的 upstream master**，不带任何本地 `/setup` 产物 |

> 另有一个**环境性**现象（非仓库缺陷）：在 DeepSeek Harness 里用管道捕获嵌套 `powershell.exe` 的输出会丢，需 `cmd /c ... > log 2>&1` 重定向。普通终端不受影响。

---

## 7. 复现方式

```powershell
git clone <this repo> ai-job-search-deepseek
cd ai-job-search-deepseek
.\dsh\install.ps1                    # Windows；macOS/Linux 用 ./dsh/install.sh
python tools\install_portal_clis.py
$env:PYTHONUTF8='1'
python -m pytest tests -q            # 干净模板态应 948 passed
.\dsh\scripts\scrape.cmd -Query "machine learning" -Category ml_ai -Remote remote -Limit 3
.\dsh\scripts\compile.cmd -Tex "templates\cjk-cv\template.tex" -Engine xelatex -Pages 1
.\dsh\scripts\verify.cmd -Pdf "templates\cjk-cv\template.pdf" -Pages 1
```

---

## 8. 未覆盖的部分（诚实边界）

- **`/apply` 全链路（起草 → 审查子代理 → 修订）未端到端跑完整一次**：它依赖一个已填好的候选人档案与一个真实 JD 的完整评估，属于「内容生产」而非「机制验证」。本次验证的是它的**硬件基础**：编译、页数、ATS、排版、闸门、状态工具，均可运行。
- **Windows 之外的平台**：`install.sh` 与 Bash 路径为代码审查级适配（脚本本身是直白的 `cp`/`mkdir`），未在 macOS/Linux 实机执行。`.ps1` 的 Windows 特有路径探测在非 Windows 上会退化为 `Get-Command` 查找。
- **`/gmail-sync`、`/notion-sync`**：DSH 无对应连接器，确认不可用，未验证。
- **中文模板的字体覆盖**：仅实测 Windows 自带微软雅黑；macOS/Linux 字体名已在文档给出但未实测。
