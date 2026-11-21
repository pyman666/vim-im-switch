# vim-im-switch

> 在 Vim/Neovim 里进出插入模式时，自动、非阻塞地切换 Windows / macOS 输入法。
> 两个平台都用「直接切输入法/输入源」而不是模拟按键或切 IME 内部模式（后者慢且不稳）。
> VSCodeVim 可复用同一个 Python 脚本；IdeaVim 需用专用扩展（见下文）。
> 按 `Esc` 切到英文输入法，进入插入模式切回中文输入法，退出 Vim 时恢复中文输入法。

## 为什么做这个

在 Vim 里用微软拼音打字，退出插入模式后输入法还停留在中文，按 `h/j/k/l` 会触发候选词，很烦。

已有的方案 [AIMSwitcher](https://github.com/A-23187/AIMSwitcher) 通过 `autocmd InsertLeave * silent !AIMSwitcher.exe --imm 0` 切换，但实测：

| 方式 | 实测耗时 |
| --- | --- |
| AIMSwitcher `--imm 0`（切「微软拼音中英文模式」，`SendMessage`） | 0.7 ~ 10 秒，且让 Vim 卡住、花屏 |
| 本工具（切「输入法」，`PostMessage` + Python） | 脚本启动 ~60ms，`PostMessage` 本身 ~0ms，Vim 零等待 |

根因：

1. `silent !` 是同步 shell 命令，阻塞 Vim、抢前台窗口、破坏重绘
2. AIMSwitcher 用 `SendMessage(IMC_SETCONVERSIONMODE)` 切微软拼音的**模式**，微软拼音响应不稳定，最慢到 10 秒

本工具换成两条更快的路径：

- **用 Vim 的 `job_start` / `jobstart` 异步调用**，Vim 完全不等待
- **用 `PostMessage(WM_INPUTLANGCHANGEREQUEST)` 直接切输入法**，而不是切微软拼音的内部模式，非阻塞、瞬发

## 效果

- 按 `Esc`（离开插入模式）→ 切到英文输入法（如 US Keyboard）
- 进入插入模式 → 切回中文输入法（如微软拼音）
- 退出 Vim（`:q`）→ 恢复中文输入法，不会停留在英文
- Vim 全程不卡、不花屏，输入法切换在后台约 60ms 后生效

## 安装

### 前提

- Vim 8+ 或 Neovim（需要 `job_start` / `jobstart`）
- **Windows**：默认配置针对「US Keyboard + 微软拼音」（`1033` / `2052`）。另需 **Python 3**（只用标准库 `ctypes`，无需 `pip install`）；`python` 不在 `PATH` 时用 `g:vim_im_switch_python` 指定 python.exe 绝对路径
- **macOS**：默认针对「ABC 键盘布局 + 简体拼音」两个输入源，用 `im-select` 直接切换，**不需要 Python、不需要辅助功能权限**（见下方安装）

### 方式一：用 Vim 包管理（推荐）

用 [vim-plug](https://github.com/junegunn/vim-plug) 等插件管理器：

```vim
Plug 'pyman666/vim-im-switch'
```

其他管理器把仓库地址换成 `https://github.com/pyman666/vim-im-switch` 即可。

### 方式二：手动放置

把仓库克隆到 Vim 的 `pack` 目录：

```powershell
git clone https://github.com/pyman666/vim-im-switch `
  "$env:LOCALAPPDATA\nvim-data\site\pack\plugins\start\vim-im-switch"
```

（Neovim 路径如上；Vim 通常把 `vim-data` 换成 `vimfiles`。）

### macOS

和 Windows 同一个思路：**直接切输入源**（`TISSelectInputSource`），不按切换键、不切 IME 内部模式。

装 `im-select`（提供 `im-select` / `im-select <input-source-id>` 两个命令）：

```sh
# 方式 A：Homebrew
brew tap daipeihust/tap && brew install im-select

# 方式 B：直接下载预编译二进制（Intel Mac）
curl -Ls https://raw.githubusercontent.com/daipeihust/im-select/master/macOS/out/intel/im-select \
  -o "$HOME/.local/bin/im-select" && chmod +x "$HOME/.local/bin/im-select"

# Apple Silicon 把上面的 intel 换成 apple
```

然后照常 `Plug 'pyman666/vim-im-switch'`。不需要 Python，也不需要辅助功能权限。

> 两个平台共用同一份代码（同一个 `main` 分支）：插件在运行时用
> `has('win32')` / `has('macunix')` 自动选后端，配置里不需要按平台换来源。

查当前输入源：`im-select`（无参数）；切换：`im-select com.apple.keylayout.ABC`。
macOS 上 `en` / `zh` 默认分别是 `com.apple.keylayout.ABC` / `com.apple.inputmethod.SCIM.ITABC`，
用别的中文输入法时在配置里覆盖 `g:vim_im_switch_zh`（见下）。

> 为什么不用 Caps Lock 模拟按键：实测 `osascript`/`CGEvent` 发的合成按键到不了简体拼音的
> 内部中英文模式，且这正是 README 开头说的「切模式」慢且不稳那条路。系统里本来就启用了
> ABC 和简体拼音两个输入源，直接选中它们就是英文/中文，快且可靠。

## 配置

默认行为通常不用改，按 OS 取不同默认值：

| 平台 | 切换方式 | `en` / `zh` |
| --- | --- | --- |
| Windows | 切输入法：`1033` US Keyboard ↔ `2052` 微软拼音 | 两个不同的 locale id |
| macOS | 切输入源：`ABC` ↔ `简体拼音` | 两个不同的 input source id |

如需调整，在 `_vimrc` / `init.vim` 里（**放在 `Plug` / 插件加载之前**）：

```vim
" Windows 用的 Python 解释器（默认 'python'；macOS 用不到）
let g:vim_im_switch_python = 'python'

" 英文 / 中文输入法，可用 en/zh 别名，也可直接写各平台标识
" Windows:
let g:vim_im_switch_en = 'en'    " 或 1033 (US Keyboard)
let g:vim_im_switch_zh = 'zh'    " 或 2052 (微软拼音)
" macOS（把下面两行注释掉即可用默认值）:
" let g:vim_im_switch_en = 'com.apple.keylayout.ABC'
" let g:vim_im_switch_zh = 'com.apple.inputmethod.SCIM.ITABC'

" macOS 下 im-select 的路径（默认 'im-select'，从 PATH 找）
let g:vim_im_switch_im_select = $HOME . '/.local/bin/im-select'

" 是否自动切换（默认都开）
let g:vim_im_switch_on_leave = 1   " 离开插入模式 -> 英文
let g:vim_im_switch_on_enter = 1   " 进入插入模式 -> 中文
let g:vim_im_switch_on_exit  = 1   " 退出 Vim -> 中文（恢复，避免留在英文）
```

如果不想进插入模式自动切中文（比如主要写英文代码），设：

```vim
let g:vim_im_switch_on_enter = 0
```

自定义 Windows 脚本路径（一般不用）：

```vim
let g:vim_im_switch_script = 'D:\path\to\im_switch.py'
```

## 手动命令

```vim
:IMSwitch en    " 切英文
:IMSwitch zh    " 切中文
:IMSwitch 1033  " Windows: 用 locale id
:IMSwitch com.apple.keylayout.ABC  " macOS: 用 input source id
:IMSwitch get   " 同步查询当前输入法/输入源并显示在消息栏
```

## VSCodeVim（VS Code）

VSCodeVim 是 VS Code 的模拟层，不是真正的 Vim，加载不了本插件。但它有**内置**的 `vim.autoSwitchInputMethod`，可以直接复用本仓库的 Python 脚本，**不需要 im-select.exe**：

在 VS Code 的 `settings.json` 里加（**必须用 python.exe 的绝对路径**，原因见下方）：

```json
{
  "vim.autoSwitchInputMethod.enable": true,
  "vim.autoSwitchInputMethod.defaultIM": "1033",
  "vim.autoSwitchInputMethod.obtainIMCmd": "C:\\Users\\<你>\\AppData\\Local\\anaconda3\\python.exe C:\\Users\\<你>\\Documents\\Scripts\\vim-im-switch\\bin\\im_switch.py get",
  "vim.autoSwitchInputMethod.switchIMCmd": "C:\\Users\\<你>\\AppData\\Local\\anaconda3\\python.exe C:\\Users\\<你>\\Documents\\Scripts\\vim-im-switch\\bin\\im_switch.py {im}"
}
```

- **关键点**：VSCodeVim 会检查命令的**第一个词**是否为存在的文件（取 `cmd.split(' ')[0]`）。写 `python ...` 会找不到叫 `python` 的文件，验证失败后它会**静默关闭**这个功能。用 `where python` 查到绝对路径再填进去。
- `{im}` 是 VSCodeVim 的占位符，会替换成目标 locale id（1033 / 2052）
- 行为：离开插入模式时记录当前输入法（中文）并切到英文（1033）；再进插入恢复中文
- VSCodeVim 没有「关闭编辑器时恢复」的钩子，但下一次进插入会自动恢复中文

**macOS 版**（直接用 `im-select`，同样不用本插件）：

```json
{
  "vim.autoSwitchInputMethod.enable": true,
  "vim.autoSwitchInputMethod.defaultIM": "com.apple.keylayout.ABC",
  "vim.autoSwitchInputMethod.obtainIMCmd": "/Users/<你>/.local/bin/im-select",
  "vim.autoSwitchInputMethod.switchIMCmd": "/Users/<你>/.local/bin/im-select {im}"
}
```

同样要注意第一个词必须是存在的文件，所以用 `im-select` 的绝对路径。

## IdeaVim（JetBrains IDE）

**IdeaVim 不支持 `:!` 执行外部命令**（会报 `E492: Not an editor command`），所以本仓库的 Python 脚本没法在 IdeaVim 里用。IdeaVim 这边走专用扩展：

1. 安装插件 **IdeaVimExtension**（[JetBrains Marketplace](https://plugins.jetbrains.com/plugin/9615-ideavimextension)）
2. 把仓库里的 `ideavimrc.example` 内容复制到 `~/.ideavimrc`，重启 IDE

核心就两行：

```vim
set keep-english-in-normal-and-restore-in-insert
let keep_input_source_in_normal = "0x0409"  " 英文 US Keyboard
let keep_input_source_in_insert = "0x0804"  " 微软拼音 (2052)
```

行为：进插入模式 → 微软拼音；按 `Esc` 离开插入 → 英文；再进插入 → 恢复中文。插件本身还是用 Windows 消息切输入法，响应很快，不需要额外跑 Python。

`ideavimrc.example` 里还给了可选的 `context_aware` 配置（根据插入位置上下文判断是否恢复中文）。

已知限制：IdeaVim 没有 `VimLeavePre`，IdeaVimExtension 也没有「退出 IDE / 关闭 Vim 模式时恢复输入法」的钩子，所以退出时仍可能停留在英文。下一次进插入模式会自动恢复中文。

## 怎么查自己输入法的 locale id

打开一个新输入法，在 PowerShell 里跑：

```powershell
Add-Type -AssemblyName System.Windows.Forms
# 切换输入法后，用下面 Python 片段读当前 locale id
```

或直接用本仓库的查询思路（依赖 Windows API）：

```python
import ctypes
u = ctypes.windll.user32
u.GetForegroundWindow.restype = ctypes.c_void_p
u.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
u.GetWindowThreadProcessId.restype = ctypes.c_uint
u.GetKeyboardLayout.argtypes = [ctypes.c_uint]
u.GetKeyboardLayout.restype = ctypes.c_void_p
h = u.GetForegroundWindow()
t = u.GetWindowThreadProcessId(h, None)
print(int(u.GetKeyboardLayout(t)) & 0xFFFF)
```

常见值：`1033` = US Keyboard（英文），`2052` = 微软拼音（简体中文）。

## 工作原理

两条路径共用同一套 autocmd 和异步 job 调度，只在「真正切换」那一步按 OS 分支：

```
InsertLeave / InsertEnter (Vim autocmd)
        │
        ▼  job_start() / jobstart() 异步启动（Vim 不等待）
   ┌────────────────────────┬──────────────────────────┐
   │ Windows                │ macOS                    │
   │ python bin/im_switch.py│ im-select <input-source> │
   │   ↓ ctypes             │   ↓ TIS API              │
   │ PostMessageW           │ TISSelectInputSource     │
   │ WM_INPUTLANGCHANGEREQUEST│ 切换当前 App 的输入源   │
   └────────────────────────┴──────────────────────────┘
        │
        ▼
   输入法切换完成（Vim 全程不卡）
```

两个平台的关键点相同：切的是**输入法/输入源本身**，不是 IME 的内部模式。
Windows 用 `WM_INPUTLANGCHANGEREQUEST`，macOS 用 `TISSelectInputSource`；
「切模式」那条路（`IMC_SETCONVERSIONMODE` / 模拟切换键）慢且不稳，所以都不走。

## 限制

- 只支持 Windows / macOS；Linux 可另接 `ibus` / `fcitx` / `xkb-switch`（同样的异步 job 思路）
- 切换作用于「当前前台 App」，切到 Vim 之外时 autocmd 不会触发（Vim 没焦点就没有 InsertLeave）
- Windows 上 `python` 启动约 60ms，输入法在这之后才切过去（Vim 本身不卡）；macOS 的 `im-select` 是原生二进制，几乎瞬时
- 两个平台都需要两种输入法/输入源都启用（Windows: US Keyboard + 微软拼音；macOS: ABC + 简体拼音）
- macOS 输入源是按 App 记住的：如果某次切换没生效，检查 `im-select` 能否列出/设置目标 ID

## License

MIT
