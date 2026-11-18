" autoload/vim_im_switch.vim - 核心逻辑（懒加载）
" vim-im-switch: 用 Python + PostMessage 非阻塞切换 Windows 输入法

if exists('g:autoloaded_vim_im_switch')
  finish
endif
let g:autoloaded_vim_im_switch = 1

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

" 定位脚本路径：优先用用户显式指定的，否则相对本插件目录找 ../bin/im_switch.py
function! s:ScriptPath() abort
  if exists('g:vim_im_switch_script')
    return expand(g:vim_im_switch_script)
  endif
  let l:plug_dir = expand('<sfile>:p:h:h')
  return l:plug_dir . '/bin/im_switch.py'
endfunction

" 后台运行切换脚本，Vim 全程不等待
function! vim_im_switch#Switch(target) abort
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

" 手动切换命令 completion
function! vim_im_switch#Complete(arglead, cmdline, cursorpos) abort
  return ['en', 'zh']
endfunction
