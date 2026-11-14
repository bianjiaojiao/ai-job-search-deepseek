<p align="center">
  <img src="assets/readme/hero.svg" alt="AI Job Search — DeepSeek 版" width="100%">
</p>

<p align="center">
  <a href="https://github.com/bianjiaojiao/ai-job-search-deepseek/actions/workflows/ci.yml"><img src="https://github.com/bianjiaojiao/ai-job-search-deepseek/actions/workflows/ci.yml/badge.svg" alt="CI" height="20"></a>
  &nbsp;
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2A9D8F?style=flat" alt="MIT license" height="20"></a>
  &nbsp;
  <a href="docs/VERIFICATION.md"><img src="https://img.shields.io/badge/verified-948%20tests%20passed-2A9D8F?style=flat" alt="verified" height="20"></a>
</p>
<h1 align="center">ai-job-search · DeepSeek 版</h1>

<p align="center">
  <b>不用 Claude Code，也能跑完整个 AI 求职流水线</b><br>
  在 <a href="https://github.com/ai-job-search-dev/ai-job-search">ai-job-search</a> 框架上做的
  <b>DeepSeek Harness（DSH）原生适配版</b>，并补齐了上游缺的<b>中文求职链路</b>。
</p>

<p align="center">
  <a href="#-纯-ai-生成声明">AI 生成声明</a> ·
  <a href="#为什么做这个版本">为什么做</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#中文求职怎么做">中文求职</a> ·
  <a href="#与上游的差异">与上游差异</a> ·
  <a href="docs/VERIFICATION.md">验证报告</a>
</p>

---

## ⚠️ 纯 AI 生成声明

> **本仓库的 DeepSeek 适配层（`dsh/` 目录）、本 README、中文简历模板（`templates/cjk-cv/`）与验证报告（`docs/VERIFICATION.md`），全部由 AI 自动生成。**
>
> - 生成者：DeepSeek Harness 上的编码代理（模型 `deepseek-flash`）
> - 时间：2026-11-14，单次会话内完成「下载 → 环境搭建 → 功能验证 → 文档编写 → 发布」
> - 方式：无人工逐行编写，人工只给了目标与几条约束（不许编造、不许删除本机文件、中文要突出）
> - 验证：生成后跑了仓库全量测试 + 真机端到端验证，结果见 [docs/VERIFICATION.md](docs/VERIFICATION.md)
>
> **上游框架 `ai-job-search` 不是本仓库产物**：它由原作者（Mads Lorentzen / [ai-job-search-dev](https://github.com/ai-job-search-dev)）用 Claude Code 构建，MIT 许可。本仓库是派生作品，**不是上游官方版本**，不代表上游维护者立场。上游 README 完整保留在 [README-upstream.md](README-upstream.md)。

---

## 为什么做这个版本

上游框架有一个真实的门槛：**它绑定 Claude Code**。工作流写成 `.claude/commands/*.md` 的斜杠命令，依赖 Claude 专属工具（`Read`、`Bash`、`Agent`、`Skill`），并且需要付费订阅。

于是两部分人用不上它：

1. 用 DeepSeek Harness / Codex / 其他代理工具的人；
2. **中文求职者**——上游的模板、门户口径、评分习惯都是丹麦/英文市场的（4 个现成门户全是丹麦的，`moderncv`/`cover.cls` 不含中文字形，直接填中文会静默缺字）。

这个版本解决的就是这两点，而且**不动上游一行规范**：

- 上游 `.claude/commands/*.md`、`.claude/skills/*` 原样保留，是唯一权威依据；
- 我们只加一层「执行机制替换」，`git pull upstream` 后规范自动同步、不会漂移。

---

## 三个卖点

### 1. 中文求职全链路（上游没有）

这是本版最实的差异化。上游面向丹麦市场，中文投递基本无法直接用：

| 中文求职痛点 | 上游情况 | 本版做法 |
|---|---|---|
| 中文简历缺字 | `moderncv` + `cover.cls` **不含中文字形**，中文会静默丢字 | 附带 `templates/cjk-cv/template.tex`：`ctexart` + `xeCJK`，`xelatex` 1 页，实测中文可正常渲染、文本层可检索 |
| 中文字体选择 | 无 | 模板内注释给全 Windows / macOS / Linux 三套字体写法（微软雅黑 / 苹方 / Noto、思源） |
| 中文 ATS 校验 | 通用校验 | 用同一套 `verify_pdf.py` 验证中文文本层：**中文可提取、无 `(cid:*)`、无缺字、无乱码** |
| 中文页数标准 | 「CV 必须 2 页」 | 中文应届生场景按 **1 页**给标准（上游规则是上限不是下限，不为凑页数编造经历） |
| 中文市场指南 | 无 | `dsh/references/windows-china.md`：中国区网络实况、BOSS直聘等平台为何不可直接抓、可用替代路径 |
| 中文文档 | 全英文 | 技能说明与三份参考文档全中文 |

> 中文简历模板是**骨架 + 占位符**，不是某个人的简历。填完 `【...】` 才能投；`templates/cjk-cv/README.md` 有完整用法。

### 2. DeepSeek Harness 原生，不依赖 Claude Code

| 上游写法（Claude Code） | DSH 实际执行 |
|---|---|
| `Read` / `Write` / `Edit` | `read` / `write` / `edit` |
| `Bash(...)` | `pwsh` |
| `Agent(subagent_type: X)` | `subagent` + 显式只读约束 |
| `WebFetch` / `WebSearch` | `web_fetch` / `web_search` |
| `Skill(...)` 自动注入档案 | 执行前主动 `read` 档案文件 |
| `.claude/settings.json` 权限白名单 | 无此机制 → 靠自觉约束（子代理只读） |
| `$ARGUMENTS` | 用户消息去掉触发短语后的剩余部分 |

技能装成 DSH 用户级技能后，在任意目录说「用 ai-job-search 帮我…」即可触发。

### 3. 可移植 + 可验证

- **三条便捷脚本没有硬编码路径**：自动按 `repo.txt` → `AI_JOB_SEARCH_REPO` → 当前目录向上找 解析仓库根，换机器/换目录都能用。
- **一键安装**：Windows `dsh/install.ps1`，macOS/Linux/WSL `dsh/install.sh`，只拷文件、不删任何东西、不联网。
- **不是「写完就发」**：全量测试 + 真机跑抓岗 / 编译 / ATS 校验，结果全部记在 [docs/VERIFICATION.md](docs/VERIFICATION.md)。

---

## 快速开始

### 0) 依赖

| 组件 | 用于 | Windows |
|---|---|---|
| Python 3.10+ | `tools/` 全部 | 官网安装包 |
| `pypdf` | ATS 文本层提取 | `python -m pip install pypdf` |
| Bun | 6 个抓岗 CLI | `powershell -c "irm bun.sh/install.ps1 | iex"` |
| LaTeX（`lualatex` + `xelatex`） | 出 PDF | `winget install MiKTeX.MiKTeX` |
| PowerShell 5.1+ | 便捷脚本（可选） | 系统自带 |

> 中国区 Windows 另设一个环境变量，避免 GBK 编码把 Python 测试和子进程输出搞崩：
> `[Environment]::SetEnvironmentVariable("PYTHONUTF8","1","User")`

### 1) 装技能

```powershell
# Windows
git clone https://github.com/<you>/ai-job-search-deepseek.git
cd ai-job-search-deepseek
.\dsh\install.ps1                     # 装到 %USERPROFILE%\.dsh\skills\ai-job-search
# .\dsh\install.ps1 -SetEnvVar       # 顺便写 AI_JOB_SEARCH_REPO 环境变量
```

```bash
# macOS / Linux / WSL
git clone https://github.com/<you>/ai-job-search-deepseek.git
cd ai-job-search-deepseek
./dsh/install.sh
```

装完在新会话里说「用 ai-job-search 帮我建档」，或直接读 `~/.dsh/skills/ai-job-search/SKILL.md`。

### 2) 装门户依赖

```powershell
cd <仓库根>
python tools\install_portal_clis.py          # 6 个门户 CLI 的 bun 依赖
python tools\install_portal_clis.py --dry-run # 先看它要装什么
```

### 3) 建档 → 搜岗 → 投递

DSH 里没有斜杠命令，直接说意图即可（技能会把上游 `/setup`、`/scrape`、`/apply` 的规范读出来执行）：

```
「帮我建档，我的简历在 documents/cv/」        ≈ /setup
「找杭州的行政助理岗位，最近 7 天」            ≈ /scrape
「这几个岗位哪个值得投，排个序」               ≈ /rank
「帮我投这个岗位：<贴 JD 或 URL>」            ≈ /apply
「帮我准备面试」                              ≈ /interview
「记录一下这个岗位的结果：进二面了」           ≈ /outcome
```

也可以直接跑脚本：

```powershell
& "<REPO>\dsh\scripts\scrape.cmd" -Query "行政助理" -Region apac -Country CN -Limit 10
& "<REPO>\dsh\scripts\scrape.cmd" -Detail "<slug>"          # 拉完整 JD
& "<REPO>\dsh\scripts\compile.cmd" -Tex "cv\main_x.tex" -Engine xelatex -Pages 1
& "<REPO>\dsh\scripts\verify.cmd" -Pdf "cv\main_x.pdf" -Pages 1 -DumpText "cv\main_x.txt"
```

> Windows 上一律用 `python`，不要用 `python3`（会命中 Microsoft Store 别名）。

---

## 中文求职怎么做

完整流程和英文版同一套规范，只有三处不同：

1. **用中文模板起草**：`templates/cjk-cv/template.tex` → 复制成 `cv/main_<公司>_<岗位>.tex`，替换所有 `【...】`。
2. **用 xelatex 编译**（不是 lualatex）：

   ```powershell
   & "<REPO>\dsh\scripts\compile.cmd" -Tex "cv\main_x.tex" -Engine xelatex -Pages 1
   ```

3. **按中文标准校验**：应届生 1 页；`verify_pdf.py` 确认中文文本层可提取、无缺字、无 `(cid:*)`；`verify_layout.py` 确认没有孤立条目、末页底部空白 ≤25%。

字体、页数预算、注册为 `/apply` 默认模板的做法，见 [`templates/cjk-cv/README.md`](templates/cjk-cv/README.md)。

**中文招聘平台的现实**：BOSS直聘 / 拉勾 / 猎聘 / 智联都有登录墙或强反爬，`/add-portal` 遇到登录墙会**主动拒绝**生成（这是设计，不是 bug）。可行路径：

- `freehire-search`：找**外企 / 远程**技术岗（零依赖，实测可用）；
- `linkedin-search`：LinkedIn 公开岗位，**中国大陆 IP 会返回 HTTP 451**（属地封禁），需境外出口；
- `/add-portal`：给**没有登录墙**的本地招聘站生成抓岗 skill；
- 手动：把 JD 原文贴进对话，走 `/apply` 的粘贴路径（最稳）。

---

## 六条主线

| 上游命令 | 做什么 | DSH 里怎么说 |
|---|---|---|
| `/setup` | 建档：读 `documents/`、粘一份 CV，或纯问答访谈 | 「帮我建档」 |
| `/scrape` | 多门户搜岗、去重、按匹配度呈现 | 「找 X 岗位」 |
| `/rank` | 批量打分，出排序短名单 | 「这几个岗位排个序」 |
| `/apply` | 评估 → 起草 CV+求职信 → 审查 → 编译 → ATS 校验 | 「帮我投这个岗位」 |
| `/interview` | 阶段化面试准备包 + 模拟面试 | 「帮我准备面试」 |
| `/outcome` | 记录结果、归档材料、起草跟进信（**只起草不发送**） | 「记录一下结果」 |

另有 `/expand` `/upskill` `/add-template` `/add-portal` `/html-report` `/reset`；`/gmail-sync` `/notion-sync` 在 DSH 下无对应连接器，不可用，改用 `/outcome` 手工记录。

---

## 与上游的差异

**只加了这些，没有改任何上游规范文件：**

| 新增 | 说明 |
|---|---|
| `dsh/SKILL.md` | DSH 技能定义：工具映射、任务路由、六条主线执行骨架、交付自检 |
| `dsh/references/tool-mapping.md` | 逐工具替换契约、子代理派遣模板、只读约束写法 |
| `dsh/references/pipeline.md` | `/apply` 8 步的 DSH 可执行清单 |
| `dsh/references/windows-china.md` | 环境搭建、中国区网络、中文字体、故障排查 |
| `dsh/scripts/{scrape,compile,verify}.ps1` | 可移植便捷脚本（自动定位仓库） |
| `dsh/install.ps1` / `dsh/install.sh` | 一键装成 DSH 用户级技能 |
| `templates/cjk-cv/` | 中文简历模板 + 用法说明 |
| `docs/VERIFICATION.md` | 验证报告（测试 + 真机实测） |
| `README.md` | 本文件；上游原文保留为 `README-upstream.md` |

上游的 `CLAUDE.md`、`.claude/commands/`、`.claude/skills/`、`tools/`、`.agents/skills/`、`cv/`、`cover_letters/` **均为原样**。

---

## 从上游更新

本仓库保留了上游完整 git 历史，可以随时对齐上游新版本：

```bash
git remote add upstream https://github.com/ai-job-search-dev/ai-job-search.git
git fetch upstream --tags
git merge upstream/master          # 或对齐到某个发布 tag
```

`dsh/` 与 `templates/cjk-cv/` 是新增目录，不会和上游冲突。

### 1. Fork and clone

Upstream quick start for getting your own copy. **Read the warning before creating anything.**

**To contribute changes back**, fork instead:

```bash
gh repo fork ai-job-search-dev/ai-job-search --clone
cd ai-job-search
```

> [!IMPORTANT]
> **A fork of this repo is always public** — GitHub does not allow private forks of
> public repositories — and `/setup` writes your **personal data** (name, contact
> details, employment history, salary expectations) into **tracked** files.
> Fork only to contribute. For your own job search, keep a private copy and push it to a
> **private** repository instead; the two-minute private-remote recipe is in
> `SETUP.md` **section 8** (`#8-pulling-upstream-updates-into-your-fork`).
> The same warning applies to this DeepSeek edition: don't publish a copy containing your
> filled-in profile.

---

## 验证

生成完不是直接发：跑了仓库全量测试 + 真机端到端验证。

- 全量测试：`pytest tests -q`、6 个门户 CLI 的 `bun test`、`tools/lint_skills.py`
- 真机验证：真实抓岗（freehire）、LaTeX 编译（英文 CV / 求职信 / 中文模板）、ATS 文本层、排版检测、JD 注入闸门

具体命令、输出与环境记录见 **[docs/VERIFICATION.md](docs/VERIFICATION.md)**。

---

## 已知限制

- **LinkedIn 抓岗在中国大陆不可用**：`HTTP 451 Unavailable_For_Legal_Reasons`（IP 属地封禁），换境外出口才可能通。
- **现成门户以丹麦市场为主**：上游自带 jobindex/jobnet/jobbank/jobdanmark 四个丹麦门户；中国岗位靠 freehire、`/add-portal` 或手工粘贴 JD。
- **中文模板是骨架**：需要自己填内容；字体默认微软雅黑，非 Windows 系统要改一行。
- **`/apply` 不代投**：只产出 PDF + 材料，网申/邮件提交始终由本人完成。
- **上游测试对齐模板态**：如果你在自己机器上跑了 `/setup` 填了真实档案，`pytest` 里检查占位符完整性的几个测试会失败——这是预期行为（模板已被个性化），不是 bug。
- **`/gmail-sync`、`/notion-sync` 在 DSH 下不可用**（无对应连接器）。

---

## 目录结构（新增部分）

```
ai-job-search-deepseek/
├── README.md                    ← 本文件
├── README-upstream.md           ← 上游 README 原文
├── dsh/                         ← DeepSeek(DSH) 适配层（新增）
│   ├── SKILL.md                 ← DSH 技能定义
│   ├── install.ps1 / install.sh ← 一键安装
│   ├── references/              ← 工具映射 / apply 清单 / Windows-中国区
│   └── scripts/                 ← scrape / compile / verify
├── templates/cjk-cv/            ← 中文简历模板（新增）
│   ├── template.tex
│   └── README.md
├── docs/VERIFICATION.md         ← 验证报告（新增）
└── (上游原有目录原样保留)
```

---

## 许可与致谢

- 上游框架：[ai-job-search](https://github.com/ai-job-search-dev/ai-job-search)，MIT，作者 Mads Lorentzen 与贡献者。
- 抓岗 CLI 设计来自 [Mikkel Krogholm 的 skills 仓库](https://github.com/mikkelkrogholm/skills)。
- 本派生版新增部分同样以 **MIT** 发布，见 [LICENSE](LICENSE)。
- AI 生成声明见本文顶部。发现生成内容有问题请开 issue —— 它是自动生成的，值得被复核。
