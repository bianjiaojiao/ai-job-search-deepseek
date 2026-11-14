# templates/cjk-cv — 中文简历模板

上游自带的 `cv/main_example.tex`（moderncv, banking）和 `cover_letters/cover.cls`
**不含中文字形**，直接填中文会静默缺字（PDF 看着空白，ATS 也提不出文字）。
中文投递需要另一套模板，这个目录就是随 DeepSeek 版附带的最小可用骨架。

## 用法

1. 复制一份改名，放进 `cv/`（产物命名沿用上游约定）：

   ```powershell
   Copy-Item templates\cjk-cv\template.tex cv\main_<company>_<role>.tex
   ```

2. 把所有 `【...】` 占位符替换成真实内容。**不要留着占位符就投。**
3. 用 `xelatex` 编译（不是 lualatex）：

   ```powershell
   # 用适配层脚本（自动定位仓库与 LaTeX，编译后校验页数）
   & <REPO>\dsh\scripts\compile.ps1 -Tex "cv\main_<company>_<role>.tex" -Engine xelatex -Pages 1

   # 或直接
   xelatex -interaction=nonstopmode -halt-on-error cv\main_<company>_<role>.tex
   ```

4. 过 ATS + 排版校验：

   ```powershell
   & <REPO>\dsh\scripts\verify.ps1 -Pdf "cv\main_<company>_<role>.pdf" -Pages 1 -DumpText "cv\main_<company>_<role>.txt"
   ```

## 字体

默认用 Windows 自带的 **微软雅黑**。换系统时改 `template.tex` 里这一行：

```latex
\setCJKmainfont{Microsoft YaHei}[BoldFont=Microsoft YaHei Bold]
```

| 系统 | 推荐写法 |
|---|---|
| Windows | `Microsoft YaHei` / `SimSun`（宋体） |
| macOS | `PingFang SC` / `Songti SC` |
| Linux | `Noto Sans CJK SC` / `Source Han Sans SC` |
| 通用（TeX Live 自带） | `FandolSong` / `FandolHei` |

字体名写错时 xelatex 会直接报 `fontspec error: font not found`，按提示换名即可。

## 页面预算

- **应届生 / 经历少**：1 页。上游"CV 正好 2 页"是**上限**不是下限，不要为凑页数编造经历。
- **有多年履历**：2 页。
- 硬性要求同英文版：无孤立条目、末页底部空白 ≤25%、ATS 中文可检索、无缺字。

## 注册为默认模板（可选）

想让它成为 `/apply` 的默认中文模板，用上游的 `/add-template`（或在
`.claude/skills/job-application-assistant/05-cv-templates.md` 里写 ACTIVE-TEMPLATE 块）：

```
/add-template          # 指向 templates/cjk-cv/template.tex，声明 xelatex + 1 页上限
```

上游 `add-template` 会要求一次强制测试编译，通过后才注册。
