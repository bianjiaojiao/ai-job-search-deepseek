# 环境搭建与中国区适配（Windows 为主）

> 本文件记录的是**实测结论**，不是推测。数据采集环境：Windows 11 + Python 3.13 + Bun 1.4.4 + MiKTeX 25.12，中国区网络。
> 命令示例里的 `<REPO>` 指仓库根（解析方式见 SKILL.md §0）。

---

## 1. 依赖安装

| 组件 | 用途 | 安装方式 | 验证 |
|---|---|---|---|
| Python 3.10+ | `tools/` 全部 | 官网安装包 / `winget install Python.Python.3.13` | `python --version` |
| pypdf | ATS 文本层提取（首选） | `python -m pip install pypdf` | `python -c "import pypdf; print(pypdf.__version__)"` |
| pytest | 跑仓库测试（可选） | `python -m pip install pytest` | `python -m pytest --version` |
| **Bun** | 6 个抓岗 CLI | `powershell -c "irm bun.sh/install.ps1 | iex"` 或 `npm i -g bun` | `bun --version` |
| **LaTeX** | 出 PDF | `winget install MiKTeX.MiKTeX --silent`（或 TeX Live） | `lualatex --version`、`xelatex --version` |
| PowerShell | 便捷脚本 | 系统自带 5.1 够用；7+ 更好 | `$PSVersionTable.PSVersion` |

装完在仓库根装门户依赖：

```powershell
cd <REPO>
python tools\install_portal_clis.py          # 按需
python tools\install_portal_clis.py --dry-run # 先看要装什么
```

> npm 安装 bun 在某些网络下会卡在下载二进制。卡住时改用官方 zip：
> `https://github.com/oven-sh/bun/releases/latest/download/bun-windows-x64.zip`，解压出 `bun.exe` 放到 `%APPDATA%\npm\`（该目录通常已在 PATH）。

---

## 2. 四个必踩的坑（附处置）

### 2.1 GBK 编码导致 Python 测试与子进程输出炸掉

**症状**：`pytest` 出现 `UnicodeDecodeError: 'gbk' codec can't decode byte 0xa7`，若干测试失败。
**原因**：中国区 Windows 默认代码页 `cp936`，子进程读取输出时按 GBK 解码 UTF-8 内容。
**处理**（用户级持久化，新终端生效）：

```powershell
[Environment]::SetEnvironmentVariable("PYTHONUTF8","1","User")
```

临时用法：`$env:PYTHONUTF8='1'`。行内：

```powershell
$env:PYTHONUTF8='1'; python -m pytest tests -q
```

### 2.2 git 的 schannel TLS 失败

**症状**：

```
fatal: unable to access 'https://github.com/...': schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS (0x8009030e)
# 或
fatal: unable to access '...': Recv failure: Connection was reset
```

**原因**：Windows 自带 schannel 后端在当前环境取不到凭据句柄；改用 OpenSSL 后端即可，但它的 CA 包路径可能带非 ASCII 字符而加载失败。

**处理**：把 CA 包复制到纯 ASCII 路径，再对仓库写入本地配置：

```powershell
# 1) 找 git 自带的 CA 包（Git for Windows 的 ucrt64/mingw64 两种布局都有可能）
$ca = "C:\Program Files\Git\ucrt64\etc\ssl\certs\ca-bundle.crt"
# 便携版则类似 <GitDir>\ucrt64\etc\ssl\certs\ca-bundle.crt

# 2) 复制到 ASCII 路径
New-Item -ItemType Directory -Force -Path "C:\git-ca" | Out-Null
Copy-Item $ca "C:\git-ca\ca-bundle.crt" -Force

# 3) 写入仓库本地配置（只影响这个仓库）
git -C <REPO> config http.sslBackend openssl
git -C <REPO> config http.sslCAInfo  C:/git-ca/ca-bundle.crt
git -C <REPO> config http.version    HTTP/1.1
```

之后 `git -C <REPO> pull` 直接可用。一次性克隆可用：

```powershell
git -c http.sslBackend=openssl -c http.sslCAInfo=C:/git-ca/ca-bundle.crt -c http.version=HTTP/1.1 clone <url> <dir>
```

> 若 `git` 连 `github.com:443` 直接超时，先确认 `api.github.com` / `codeload.github.com` 是否可达；必要时用 Python 的 `urllib` 下载 zip 解压（Python 走自己的 OpenSSL 栈，往往能通）。

### 2.3 `verify_pdf.py --dump-text` 的目录守卫

只允许写到仓库内 `cv/` 或 `cover_letters/`，写别处直接报错退出。这是仓库的**安全设计**，不是 bug。

### 2.4 PowerShell 5.1 把无 BOM 的 UTF-8 脚本按 GBK 解析

**后果**：含中文的 `.ps1` 如果保存为「UTF-8 无 BOM」，在 `powershell.exe` 5.1 里会乱码甚至语法报错（`pwsh` 7 没这个问题）。
**本适配层的脚本已写成 UTF-8 with BOM**。自己加脚本时补 BOM：

```powershell
$enc = New-Object System.Text.UTF8Encoding($true)
$t = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($path, $t, $enc)
```

另外 PS 5.1 两个坑（本适配层脚本已规避）：

- 原生程序写 stderr 时，`$ErrorActionPreference='Stop'` 会把警告当**终止错误**。改为 `Continue` + `$LASTEXITCODE` 判断，或 `*>` 重定向到日志。
- `(Get-Command x).Source` 对外部命令是空值，要用 `.Path`。

### 2.5 `verify_layout.py` 需要 `pdftotext -bbox`

**好消息**：MiKTeX 自带 `pdftotext.exe`（在 `%LOCALAPPDATA%\Programs\MiKTeX\miktex\bin\x64`），不用另装 Poppler。
**注意**：新开进程可能还没继承更新后的 PATH，所以 `compile.ps1` / `verify.ps1` 会**自己把 MiKTeX bin 补进 PATH**。
**降级行为**：找不到 `pdftotext` 时 `verify_layout.py` 打印 `skipped:` 并以退出码 2 结束（不是失败）。`verify.ps1` 把 2 当 **WARN**，只有真正检出布局问题才算 FAIL。

---

## 3. 网络可达性（中国区实测，2026-11）

| 目标 | 结果 | 结论 |
|---|---|---|
| `freehire.me` API | ✅ 通 | **主力抓岗源**（全球技术岗，零依赖） |
| `jobindex.dk` 等丹麦门户 | ✅ 通 | 只在找丹麦岗位时用 |
| `linkedin.com` jobs-guest | ❌ **HTTP 451** `Unavailable_For_Legal_Reasons` | IP 属地封禁，**换境外出口才可能通**，别浪费时间 |
| `github.com` | ✅ 通（需 OpenSSL 后端，见 2.2） | git 可用 |
| `registry.npmjs.org` / `pypi.org` | ✅ 通 | 装包可用 |
| 直接 `curl` / `Invoke-WebRequest` 访问 github | ❌ schannel 失败 | 用 git 或 Python `urllib` |

抓岗优先级：`freehire-search` → 丹麦四门户（仅丹麦）→ `/add-portal` 自建。

---

## 4. 中国求职市场的现实约束

1. **BOSS直聘 / 拉勾 / 猎聘 / 智联**：都有登录墙或强反爬。`/add-portal` 遇到登录墙会**主动拒绝**生成，这是设计而非缺陷。可行路径：用 `freehire-search` 找**外企/远程**岗位，或换境外出口用 `linkedin-search`。
2. **中文简历**：上游自带 `moderncv`（banking）+ `cover.cls`（Lato/Raleway）**不含中文字形**，直接填中文会缺字。本适配层已附带 `templates/cjk-cv/template.tex`（`ctexart` + `xeCJK` + 微软雅黑，`xelatex` 编译）；也可以 `/add-template` 注册你自己的模板。Linux/macOS 上把 `\setCJKmainfont` 换成 Noto Sans CJK / 思源黑体。
3. **中文页数标准**：应届生 1 页为佳；有多年履历者 2 页。上游「正好 2 页」是**上限**不是下限——不得为凑满页数编造经历。
4. **薪资工具**：`salary_lookup.py` 是「自带数据」设计（需要 `salary_data.json`），没有本地数据就整段跳过，不影响主流程。
5. **提交申请**：`/apply` 只产出 PDF + 材料，**从不代替你提交**。网申、邮件、猎头沟通由你本人完成。

---

## 5. 常用诊断命令

```powershell
# 环境自检
bun --version
lualatex --version | Select-Object -First 1
xelatex  --version | Select-Object -First 1
python -c "import sys,pypdf; print('py',sys.version.split()[0],'pypdf',pypdf.__version__)"

# 门户依赖是否齐全（应列出 6 个）
python <REPO>\tools\install_portal_clis.py --dry-run

# 仓库自检
python <REPO>\tools\lint_skills.py
$env:PYTHONUTF8='1'; python -m pytest <REPO>\tests -q     # 干净模板应全绿

# git 是否还能拉
git -C <REPO> fetch --dry-run
```

---

## 6. 故障对照表

| 现象 | 原因 | 处置 |
|---|---|---|
| `lualatex: command not found` | PATH 未刷新 | 新开终端；或用完整路径 |
| `! LaTeX Error: File 'moderncv.cls' not found` | MiKTeX 未自动装包 | `initexmf --set-config-value=[MPM]AutoInstall=1` 后重编 |
| CV 编译出 3 页 | 内容超了 | 按 `05-cv-templates.md` 的相关性加权裁剪，别机械删最旧的 |
| 求职信溢出到第 2 页 | 签名块没放下 | 缩短正文 / `\enlargethispage`，必须压回 1 页 |
| ATS 提取出现 `(cid:*)` 或 `�` | 字体/字形映射问题 | 换字体或改 `fontspec` 映射；重新提文本层验证 |
| `verify_layout` 报某页大面积空白 | 内容太少或截断过度 | 补回高相关内容（样例模板出现属正常） |
| `bun: command not found` | PATH 未刷新 | 用完整路径 `%APPDATA%\npm\bun.exe` |
| `python3` 无输出 / exit 49 | 命中 Microsoft Store 别名 | 改用 `python` |
| LinkedIn 抓岗 451 | IP 属地 | 放弃该源，改 freehire |
| pytest 大片 `gbk codec` 失败 | 编码 | 设 `PYTHONUTF8=1`（见 2.1） |
| `git clone` 报 `SEC_E_NO_CREDENTIALS` | schannel | 改 OpenSSL 后端（见 2.2） |
