" plugin/vim_im_switch.vim - 插件入口
if exists('g:loaded_vim_im_switch')
  finish
endif
let g:loaded_vim_im_switch = 1

if has('win32') || has('win64')
  augroup vim_im_switch
    autocmd!
    autocmd InsertLeave * call vim_im_switch#InsertLeave()
    autocmd InsertEnter * call vim_im_switch#InsertEnter()
    autocmd VimLeavePre * call vim_im_switch#Exit()
  augroup END

  command! -nargs=1 -complete=customlist,vim_im_switch#Complete IMSwitch call vim_im_switch#Switch(<q-args>)
endif
