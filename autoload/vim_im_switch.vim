" autoload/vim_im_switch.vim - 核心逻辑（懒加载）
"
" Windows: Python + PostMessage(WM_INPUTLANGCHANGEREQUEST)，异步切输入法
" macOS:   im-select CLI（底层 TIS API TISSelectInputSource），异步切输入源
" 两条路径都是 job_start/jobstart 后台调用，Vim 全程不等待。
"
" 为什么 mac 不模拟按键：和 Windows 同一个教训——「切模式」慢且不稳，
" 「直接切输入法/输入源」才快且稳。mac 也有两个输入源（ABC / 简体拼音），
" 直接选中它们等价于按切换键，但不用按键、不依赖辅助功能权限。

if exists('g:autoloaded_vim_im_switch')
  finish
endif
let g:autoloaded_vim_im_switch = 1

" 必须在脚本顶层取 <sfile>：在函数里 <sfile> 指向「调用方」而不是本文件，
" 会导致路径算错（例如算成当前目录/bin/im_switch.py）。
let s:plugin_root = expand('<sfile>:p:h:h')
let s:is_win = has('win32') || has('win64')
let s:is_mac = has('macunix')

" ---------- 默认配置（可在 vimrc / init.lua 里覆盖） ----------
if !exists('g:vim_im_switch_python')
  let g:vim_im_switch_python = 'python'
endif
if !exists('g:vim_im_switch_im_select')
  let g:vim_im_switch_im_select = 'im-select'
endif
if !exists('g:vim_im_switch_en')
  let g:vim_im_switch_en = s:is_mac ? 'com.apple.keylayout.ABC' : 'en'
endif
if !exists('g:vim_im_switch_zh')
  let g:vim_im_switch_zh = s:is_mac ? 'com.apple.inputmethod.SCIM.ITABC' : 'zh'
endif
if !exists('g:vim_im_switch_on_enter')
  let g:vim_im_switch_on_enter = 1
endif
if !exists('g:vim_im_switch_on_leave')
  let g:vim_im_switch_on_leave = 1
endif
if !exists('g:vim_im_switch_on_exit')
  let g:vim_im_switch_on_exit = 1
endif

" 定位 Windows 脚本：优先用用户显式指定的，否则相对本插件目录找 ../bin/im_switch.py
function! s:ScriptPath() abort
  if exists('g:vim_im_switch_script')
    return expand(g:vim_im_switch_script)
  endif
  return s:plugin_root . '/bin/im_switch.py'
endfunction

" en/zh 别名展开成各平台实际输入法标识；其他值原样透传（locale id / input source id）
function! s:Resolve(target) abort
  let l:t = tolower(a:target)
  if l:t ==# 'en'
    return g:vim_im_switch_en
  endif
  if l:t ==# 'zh'
    return g:vim_im_switch_zh
  endif
  return a:target
endfunction

" 组装实际执行的命令数组
function! s:Command(target) abort
  if s:is_mac
    let l:bin = expand(g:vim_im_switch_im_select)
    return a:target ==# 'get' ? [l:bin] : [l:bin, a:target]
  endif
  return [expand(g:vim_im_switch_python), s:ScriptPath(), a:target]
endfunction

" 运行切换命令。默认后台（不阻塞 Vim）；退出/get 时传 1 用同步调用，
" 因为 Vim 退出会杀掉 job，而 get 需要拿输出。
function! vim_im_switch#Switch(target, ...) abort
  let l:sync = a:0 ? a:1 : 0
  if a:target ==# 'get'
    let l:sync = 1
  endif

  let l:cmd = s:Command(s:Resolve(a:target))
  let l:bin = l:cmd[0]
  if !executable(l:bin)
    echom '[vim-im-switch] 找不到可执行文件: ' . l:bin
    return
  endif

  if l:sync
    " im-select 输出带 C 字符串结尾的 NUL，用 \%d0 去掉（"\0" 在 Vim 里是 Blob）
    let l:out = substitute(system(l:cmd), '\%d0', '', 'g')
    if a:target ==# 'get'
      echom '[vim-im-switch] 当前输入法: ' . substitute(l:out, '\s\+$', '', '')
    endif
    return
  endif

  if exists('*job_start')
    " Vim 8+
    call job_start(l:cmd, {
          \ 'in_io': 'null', 'out_io': 'null', 'err_io': 'null' })
  elseif exists('*jobstart')
    " Neovim
    call jobstart(l:cmd, {'detach': v:true})
  else
    " 极老 Vim 兜底：后台启动，不等它
    let l:str = join(map(copy(l:cmd), 'shellescape(v:val)'), ' ')
    if s:is_win
      silent call system('start "" /b ' . l:str . ' >nul 2>&1')
    else
      silent call system(l:str . ' >/dev/null 2>&1 &')
    endif
  endif
endfunction

function! vim_im_switch#InsertLeave() abort
  if g:vim_im_switch_on_leave
    call vim_im_switch#Switch(g:vim_im_switch_en)
  endif
endfunction

function! vim_im_switch#InsertEnter() abort
  if g:vim_im_switch_on_enter
    call vim_im_switch#Switch(g:vim_im_switch_zh)
  endif
endfunction

" 退出 Vim 时切回中文输入法（同步，确保命令在 Vim 结束前跑完）
function! vim_im_switch#Exit() abort
  if g:vim_im_switch_on_exit
    call vim_im_switch#Switch(g:vim_im_switch_zh, 1)
  endif
endfunction

function! vim_im_switch#Complete(arglead, cmdline, cursorpos) abort
  return ['en', 'zh', 'get']
endfunction
