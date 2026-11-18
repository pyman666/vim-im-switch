" autoload/vim_im_switch.vim - 核心逻辑（懒加载）
" vim-im-switch: 用 Python + PostMessage 非阻塞切换 Windows 输入法

if exists('g:autoloaded_vim_im_switch')
  finish
endif
let g:autoloaded_vim_im_switch = 1

" 必须在脚本顶层取 <sfile>：在函数里 <sfile> 指向「调用方」而不是本文件，
" 会导致路径算错（例如算成当前目录/bin/im_switch.py）。
let s:plugin_root = expand('<sfile>:p:h:h')

" 默认配置
if !exists('g:vim_im_switch_python')
  let g:vim_im_switch_python = 'python'
endif
if !exists('g:vim_im_switch_en')
  let g:vim_im_switch_en = 'en'   " 英文输入法（也可写 1033）
endif
if !exists('g:vim_im_switch_zh')
  let g:vim_im_switch_zh = 'zh'   " 中文输入法（微软拼音，也可写 2052）
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

" 定位脚本路径：优先用用户显式指定的，否则相对本插件目录找 ../bin/im_switch.py
function! s:ScriptPath() abort
  if exists('g:vim_im_switch_script')
    return expand(g:vim_im_switch_script)
  endif
  return s:plugin_root . '/bin/im_switch.py'
endfunction

" 运行切换脚本。默认后台（不阻塞 Vim）；退出时传 1 用同步调用，
" 因为 Vim 退出会杀掉 job，而且反正都要退出了，等 60ms 无所谓。
function! vim_im_switch#Switch(target, ...) abort
  let l:sync = a:0 ? a:1 : 0
  let l:py = g:vim_im_switch_python
  let l:script = s:ScriptPath()

  if !executable(l:py)
    return
  endif
  if !filereadable(l:script)
    echom '[vim-im-switch] 找不到脚本: ' . l:script
    return
  endif

  let l:args = [l:py, l:script, a:target]
  if l:sync
    call system(l:args)
    return
  endif
  if exists('*job_start')
    " Vim 8+
    call job_start(l:args, {
          \ 'in_io': 'null', 'out_io': 'null', 'err_io': 'null' })
  elseif exists('*jobstart')
    " Neovim
    call jobstart(l:args, {'detach': v:true})
  else
    " 极老 Vim 兜底
    silent call system('start "" /b ' . l:py . ' "' . l:script
          \ . '" ' . a:target . ' >nul 2>&1')
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

" 退出 Vim 时切回中文输入法（同步，确保脚本在 Vim 结束前跑完）
function! vim_im_switch#Exit() abort
  if g:vim_im_switch_on_exit
    call vim_im_switch#Switch(g:vim_im_switch_zh, 1)
  endif
endfunction

" 手动切换命令 completion
function! vim_im_switch#Complete(arglead, cmdline, cursorpos) abort
  return ['en', 'zh']
endfunction
