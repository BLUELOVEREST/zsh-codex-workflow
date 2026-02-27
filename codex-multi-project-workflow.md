# Codex 多项目并行开发工作流（iTerm2 + SSH + tmux）

## 1. 目标

1. 多项目并行时，能快速识别当前项目。
2. 不再频繁 `exit codex -> cd -> codex`。
3. 非代码目录也能快速进入 Codex。
4. iTerm2 tab 尽量显示项目名或路径。

## 2. 当前方案（三模式入口）

1. `dev <目录>`：项目模式（一个目录一个 tmux session）
2. `cx [目录]`：临时模式（固定 `codex-temp`）
3. `cwa [目录]`：自动模式（git 仓库走 `dev`，非仓库走 `cx`）

说明：每个新会话默认上下分屏，上面 shell，下面自动启动 `codex`。

## 3. 插件状态（已落地）

仓库路径：`/home/zhangzhicheng/workspace/zsh-codex-workflow`

核心文件：

1. `codex-workflow.plugin.zsh`
2. `README.md`
3. `codex-multi-project-workflow.md`

当前可用命令：

1. `dev <目录>`
2. `cx [目录]`
3. `cwa [目录]`
4. `cxx`（重置临时会话）
5. `cwl`（列出 tmux sessions，含路径）

接入状态：

1. 已创建软链接：`~/.oh-my-zsh/custom/plugins/codex-workflow -> /home/zhangzhicheng/workspace/zsh-codex-workflow`
2. 已在 `~/.zshrc` 的 `plugins=(...)` 中加入 `codex-workflow`

## 4. 安装方式（oh-my-zsh）

```bash
ln -s /home/zhangzhicheng/workspace/zsh-codex-workflow ~/.oh-my-zsh/custom/plugins/codex-workflow
```

在 `~/.zshrc`：

```bash
plugins=(... codex-workflow)
source ~/.zshrc
```

## 5. 自动判定规则（`cwa`）

1. 目标目录在 git 工作树内：走 `dev`
2. 目标目录不在 git 工作树内：走 `cx`

默认行为：在 git 工作树里时使用仓库根目录作为项目目录。

可选配置：

```bash
# 1: 使用仓库根目录（默认）
# 0: 使用你传入的当前目录
export CODEX_WORKFLOW_SMART_REPO_ROOT=1

# 临时会话名
export CODEX_WORKFLOW_TEMP_SESSION="codex-temp"

# session 命名策略
# basename（默认）: household_inventory_manager
# parent_basename: workspace_household_inventory_manager
export CODEX_WORKFLOW_SESSION_NAME_MODE="basename"
```

## 6. iTerm2 tab 显示项目名/路径（已实现）

可以做到。插件会自动设置 tmux 标题联动，并默认使用短标题（避免多 tab 时被截断）：

```tmux
set -g set-titles on
set -g set-titles-string '#S | #{b:pane_current_path}'
set -wg automatic-rename on
set -wg automatic-rename-format '#{b:pane_current_path}'
```

你还需要在 iTerm2 中确认：Tab Title 包含 Terminal/Session Title（具体字段名随版本略有差异）。

如果你不希望插件改标题：

```bash
export CODEX_WORKFLOW_ITERM_TITLE=0
```

标题模式可调：

```bash
# 默认: compact（推荐，多 tab 不易截断）
export CODEX_WORKFLOW_TITLE_MODE="compact"  # session | 当前目录名

# 需要完整路径时
export CODEX_WORKFLOW_TITLE_MODE="full"     # session | 完整路径

# 只显示项目名（最短）
export CODEX_WORKFLOW_TITLE_MODE="session"  # 仅 session
```

## 7. 推荐日常流程

1. Mac iTerm2 打开一个 tab，SSH 到 Ubuntu。
2. 优先执行 `cwa [目录]` 自动分流。
3. 只有你明确要强制模式时，再用 `dev` 或 `cx`。
4. tmux 内用 `Ctrl+b s` 切会话，`Ctrl+b d` 暂离。

## 8. 常见问题

1. `tmux: command not found`
   - 在远端 Ubuntu 安装 tmux。
2. `codex-workflow: missing required command: codex`
   - 确认远端 `codex` 在 PATH 内。
3. `cwa` 没走 `dev`
   - 用 `git -C <dir> rev-parse --is-inside-work-tree` 检查目录是否在仓库内。
4. iTerm2 tab 仍不显示项目信息
   - 检查 iTerm2 tab title 配置是否包含 Terminal/Session Title。
   - 检查 `echo $CODEX_WORKFLOW_ITERM_TITLE` 是否为 `1`。
5. iTerm2 tab 显示不全（多 tab 截断）
   - 设为短标题：`export CODEX_WORKFLOW_TITLE_MODE=\"compact\"`（默认）。
   - 还不够时用：`export CODEX_WORKFLOW_TITLE_MODE=\"session\"`。
6. `F2 s` 列表还是默认样式
   - 这是 tmux 交互选择器的兼容性差异，建议用两层兜底：
   - 先用 `cwl`（现已默认显示 session + path）确认目标会话。
   - 再用 `tmux switch-client -t <session>` 切过去。
7. 同名项目在不同目录难区分
   - 使用父目录命名策略：
   - `export CODEX_WORKFLOW_SESSION_NAME_MODE=\"parent_basename\"`
   - 例如 `workspace_household_inventory_manager`。

## 9. 后续可扩展

1. `cwa` + `fzf`：交互选择目录后自动分流。
2. 会话名策略升级：目录冲突时用“父目录+目录名”。
3. 增加常用项目目录池（快速检索并进入）。

---

当前结论：**主入口用 `cwa`，手动覆盖用 `dev/cx`；iTerm2 tab 用 compact/session 缓解截断；会话区分优先用 `parent_basename` + `cwl` 路径列表。**
