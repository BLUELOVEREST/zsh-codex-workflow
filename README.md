# zsh-codex-workflow

一个用于远程服务器上的 `codex + zellij` 工作流的轻量 zsh 插件。

## 这个插件做什么

这个插件提供两种快速入口：

- 项目会话：每个项目目录对应一个独立的 zellij session
- 临时会话：一个可复用的临时 scratch session

每个新 session 默认都会创建固定的上下双 pane 布局：

- 上方 pane：位于目标目录的普通 shell
- 下方 pane：位于同一目录并自动启动的 `codex`

它的主要目标是让多项目切换更快，不需要每次手动重建同样的 zellij 布局。

## 命令

- `pj <dir>`：进入或创建某个目录对应的项目 zellij session
- `px [dir]`：进入或创建共享的临时 zellij session
- `pjs`：列出已知项目 session 和对应目录
- `pjp`：通过选择器进入某个已知项目 session
- `pxr`：重置共享临时 session

## 依赖

- `zsh`
- `zellij`
- `codex` 在 `PATH` 中
- `fzf`：`pjp` 默认使用的项目选择器

如果你使用 Ubuntu/Debian，可以这样安装基础依赖：

```bash
sudo apt update
sudo apt install zsh fzf
```

`zellij` 建议使用官方 release 或 Cargo 安装，避免系统包版本过旧：

```bash
cargo install --locked zellij
```

确认命令可用：

```bash
zellij --version
codex --version
fzf --version
```

如果不想使用 `fzf`，可以通过 `CODEX_WORKFLOW_PICKER` 换成其他选择器。

## 安装

克隆到 Oh My Zsh 的自定义插件目录：

```bash
git clone git@github.com:BLUELOVEREST/zsh-codex-workflow.git ~/.oh-my-zsh/custom/plugins/codex-workflow
```

在 `~/.zshrc` 中启用插件：

```bash
plugins=(... codex-workflow)
```

重新加载 shell：

```bash
source ~/.zshrc
```

## 使用

打开或创建一个项目 session：

```bash
pj ~/workspace/project-a
```

打开或创建共享临时 session：

```bash
px
px ~/tmp/scratch-dir
```

列出已知项目 session：

```bash
pjs
```

通过选择器进入某个已知项目 session：

```bash
pjp
```

重置共享临时 session：

```bash
pxr
```

## 配置

临时 session 名称：

```bash
export CODEX_WORKFLOW_TEMP_SESSION="codex-temp"
```

项目元数据和生成的 zellij layout 存放目录：

```bash
export CODEX_WORKFLOW_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/codex-workflow"
```

`pjp` 使用的选择器命令：

```bash
export CODEX_WORKFLOW_PICKER="fzf"
```

Codex pane 默认会使用 `codex --no-alt-screen`，以减少 zellij 中 TUI/滚动/输入相关问题。如果你想恢复 Codex 默认的 alternate screen 模式：

```bash
export CODEX_WORKFLOW_CODEX_NO_ALT_SCREEN=0
```

## 注意事项

- 这个插件是 zellij-first 的工作流，旧的 tmux 命令模型不再是主要使用方式。
- 项目 session 名称会从目录名生成；如果同名目录冲突，会自动追加数字后缀。
- 临时 session 不会自动切换到新目录。如果想用新目录重新创建临时上下文，先执行 `pxr`，再执行 `px <dir>`。
