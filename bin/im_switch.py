# -*- coding: utf-8 -*-
"""
im_switch.py - 非阻塞切换 Windows 输入法
========================================

由 Vim/Neovim 的 autocmd 异步调用，离开插入模式切到英文输入法，
进入插入模式切回中文输入法。

原理：
    用 PostMessage(WM_INPUTLANGCHANGEREQUEST) 异步切换输入法。
    实测调用本身 ~0ms，脚本启动约 60ms。

    为什么不切「微软拼音的中英文模式」(IMC_SETCONVERSIONMODE)？
    那条路走 SendMessage，微软拼音响应慢且不稳定（0.2~10 秒），
    直接切「输入法」本身则快得多。

用法：
    python im_switch.py en    # 切到英文输入法
    python im_switch.py zh    # 切到中文输入法（微软拼音）

    也可以用 locale id：
    python im_switch.py 1033
    python im_switch.py 2052

依赖：Python 3 + ctypes（标准库，无需 pip install）。
"""

import ctypes
import sys

# Windows 消息常量
WM_INPUTLANGCHANGEREQUEST = 0x0050

# 常见 locale id（可用 --list 查看，或用数字直接传）
LOCALES = {
    "en": 1033,   # 英文输入法 (US Keyboard)
    "zh": 2052,   # 微软拼音 (Simplified Chinese)
}

# 正确声明 ctypes 原型（64 位 Windows 上必须，否则句柄会被截断）
_user32 = ctypes.windll.user32
_user32.GetForegroundWindow.restype = ctypes.c_void_p
_user32.PostMessageW.argtypes = [
    ctypes.c_void_p,   # hWnd
    ctypes.c_uint,     # Msg
    ctypes.c_void_p,   # wParam
    ctypes.c_void_p,   # lParam
]


def get_foreground_window():
    return _user32.GetForegroundWindow()


def switch_im(lang_id):
    """向前台窗口投递切换输入法请求，立即返回，不对 IME 响应做等待。"""
    hwnd = get_foreground_window()
    if not hwnd:
        return False
    _user32.PostMessageW(hwnd, WM_INPUTLANGCHANGEREQUEST, 0, lang_id)
    return True


def resolve(arg):
    arg = arg.lower()
    if arg in LOCALES:
        return LOCALES[arg]
    try:
        return int(arg)
    except ValueError:
        return None


def main(argv):
    if len(argv) != 2:
        sys.stderr.write(__doc__ + "\n")
        return 2
    lang_id = resolve(argv[1])
    if lang_id is None:
        sys.stderr.write("无效参数: %s (可用 en/zh 或 locale id 数字)\n" % argv[1])
        return 2
    ok = switch_im(lang_id)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
