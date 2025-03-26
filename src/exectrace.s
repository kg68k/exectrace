.title exectrace - trace DOS _EXEC

;This file is part of exectrace
;Copyright (C) 2025 TcbnErik
;
;This program is free software: you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation, either version 3 of the License, or
;(at your option) any later version.
;
;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with this program.  If not, see <https://www.gnu.org/licenses/>.

.include macro.mac
.include dosdef.mac
.include console.mac
.include doscall.mac
.include filesys.mac
.include iocscall.mac

.xref keepchk


PROGRAM: .reg 'exectrace'
VERSION: .reg '1.1.0-beta.1'
YEAR:    .reg '2025'
AUTHOR:  .reg 'TcbnErik'
_TITLE:  .reg PROGRAM,' ',VERSION,'  Copyright (C)',YEAR,' ',AUTHOR,'.',CR,LF


.offset 0
exec_md:
exec_module:  .ds.b 1
exec_mode:    .ds.b 1
exec_file:
exec_address: .ds.l 1
exec_cmdline:
exec_buffer:
exec_load:
exec_target:  .ds.l 1
exec_env:
exec_limit:   .ds.l 1


.offset 0
  .dc.b _TITLE,0
.text


* Macro --------------------------------------- *

IOCS_: .macro callno
  movea.l (callno*4+$400),a0
  jsr (a0)
.endm

DOS_: .macro callno
  lea (sp),a6
  movea.l (.low.callno*4+$1800),a0
  jsr (a0)
.endm

PUSH_A6: .macro
  move.l a6,-(sp)  ;DOS_ 前に実行
.endm

POP_A6: .macro
  movea.l (sp)+,a6  ;DOS_ 後に実行
.endm


* Text Section -------------------------------- *

_IGNORE_NUL_ARG:
.include startup.s


* 常駐部 プログラム --------------------------- *

usereg: .reg d0-d7/a0-a6

.text
.quad

old_vec: .dc.l 0
fileno:  .dc.w 0

new_dos_exec:
  PUSH usereg
  bsr open_logfile
  bmi open_logfile_error

  bsr output_md
  bsr output_each_mode

  POP usereg
  bsr call_dos_exec_orig
  PUSH usereg

  bsr output_return_value
  bsr close_logfile
  POP usereg
  rts

open_logfile_error:
  POP usereg
call_dos_exec_orig:
  move.l (old_vec,pc),-(sp)
  rts


;DOSコールの返り値を表示する
output_return_value:
  lea (text_buffer,pc),a1
  lea (return_mes,pc),a0
  STRCPY a0,a1,-1
  bsr write_hex8
  bsr write_newline
  bra print_buffer


;MD (MODULE + MODE)引数を表示する
output_md:
  lea (text_buffer,pc),a1
  bsr write_newline
  lea (md_mes,pc),a0
  STRCPY a0,a1,-1
  move (exec_md,a6),d0
  bsr write_hex4

  moveq #0,d0
  move.b (exec_mode,a6),d0
  cmpi #EXECMODE_BINDNO,d0
  bls @f
    moveq #EXECMODE_BINDNO+1,d0  ;mode > 5 なら未定義のモード
  @@:
  lea (md_mes_table,pc),a0
  move.b (a0,d0.w),d0
  adda.l d0,a0
  STRCPY a0,a1,-1

  bsr write_newline
  bra print_buffer


;MODE ごとの処理に振り分ける
output_each_mode:
  moveq #0,d0
  move.b (exec_mode,a6),d0
  cmpi #EXECMODE_BINDNO,d0
  bhi 9f

  add d0,d0
  lea (text_buffer,pc),a1
  jsr (output_each_mode_table,pc,d0.w)

  lea (text_buffer,pc),a0
  cmpa.l a0,a1
  bne print_buffer  ;最後の行の改行を表示していなければ表示する
9:
  rts

output_each_mode_table:
  bra.s output_md0
  bra.s output_md1
  bra.s output_md2
  bra.s output_md3
  bra.s output_md4
  bra   output_md5

output_md0:
output_md1:
  bsr output_file
  bsr output_cmdline
  bra output_envptr

output_md2:
  bsr output_file
  bsr output_buffer
  bra output_envptr

output_md3:
  bsr output_file
  bsr output_loadadr
  bra output_limit

output_md4:
  bsr output_execadr
  bra output_cmdline2

output_md5:
  bsr output_file
  bra output_file2


;FILE 引数を表示する(末尾改行なし)
;in a1.l バッファ
;out a1.l 改行を書き込んだバッファ
output_file:
  lea (file_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_file,a6),d0
  bsr write_hex8
  bsr write_separator
  bsr print_buffer

  movea.l (exec_file,a6),a1
  bsr print_a1

  bra write_newline


;FILE2 引数を表示する(末尾改行なし)
;in a1.l バッファ
;out a1.l 改行を書き込んだバッファ
output_file2:
  lea (file2_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_target,a6),d0
  bsr write_hex8
  bsr write_separator
  bsr print_buffer

  movea.l (exec_target,a6),a1
  bsr print_a1

  bra write_newline


;CMDLINE 引数を表示する(末尾改行なし)
;in a1.l バッファ
;out a1.l 改行を書き込んだバッファ
output_cmdline:
  lea (cmdline_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_cmdline,a6),d0
  bsr write_hex8
  bsr write_separator
  bsr print_buffer

  movea.l (exec_cmdline,a6),a1
  addq.l #1,a1  ;文字列長を飛ばす
  bsr print_a1

  bra write_newline


;CMDLINE の値を表示する(末尾改行なし)
;  DOS コールの引数としては渡されないが、表示された方が分かりやすいので
;  PSP 内の値を取得して表示する。
;in a1.l バッファ
;out a1.l 改行を書き込んだバッファ
output_cmdline2:
  lea (cmdline_mes,pc),a0
  STRCPY a0,a1,-1
  movea.l ($1c28),a0  ;PSP 格納ワークへのポインタ
  movea.l (a0),a0     ;PSP
  move.l ($20,a0),d0  ;コマンドラインのアドレス
  move.l d0,-(sp)

  bsr write_hex8
  bsr write_separator
  bsr print_buffer

  movea.l (sp)+,a1
  addq.l #1,a1  ;文字列長を飛ばす
  bsr print_a1

  bra write_newline


;ENVPTR 引数を表示する
;in a1.l バッファ
;out a1.l バッファ先頭
output_envptr:
  lea (env_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_env,a6),d0
  bsr write_hex8
  bsr write_newline
  bra print_buffer


;BUFFER 引数を表示する
;  正式には CMDLINE だが出力バッファのため BUFFER としている。
;in a1.l バッファ
;out a1.l バッファ先頭
output_buffer:
  lea (buffer_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_buffer,a6),d0
  bsr write_hex8
  bsr write_newline
  bra print_buffer


;LOADADR 引数を表示する
;in a1.l バッファ
;out a1.l バッファ先頭
output_loadadr:
  lea (loadadr_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_load,a6),d0
  bsr write_hex8
  bsr write_newline
  bra print_buffer


;LOADADR 引数を表示する
;in a1.l バッファ
;out a1.l バッファ先頭
output_limit:
  lea (limit_mes,pc),a0
  STRCPY a0,a1,-1
  move.l (exec_limit,a6),d0
  bsr write_hex8
  bsr write_newline
  bra print_buffer


;EXECADR 引数を表示する
;in a1.l バッファ
;out a1.l バッファ先頭
output_execadr:
  lea (execadr_mes,pc),a0
  STRCPY a0,a1,-1
  bsr write_hex8
  bsr write_newline
  bra print_buffer


write_newline:
  move.b (log_filename,pc),d0
  bne @f
    move.b #CR,(a1)+
  @@:
  move.b #LF,(a1)+
  clr.b (a1)
  rts

write_separator:
  move.b #':',(a1)+
  move.b #' ',(a1)+
  clr.b (a1)
  rts

write_hex4:
  swap d0
  moveq #4-1,d1
  bra @f
write_hex8:
  moveq #8-1,d1
  @@:
    rol.l #4,d0
    moveq #$f,d2
    and d0,d2
    move.b (hextable,pc,d2.w),(a1)+
  dbra d1,@b
  clr.b (a1)
  rts

hextable: .dc.b '0123456789abcdef'
.even


print_buffer:
  lea (text_buffer,pc),a1
print_a1:
  move.b (log_filename,pc),d0
  beq @f
    PUSH_A6
    move (fileno,pc),-(sp)
    pea (a1)
    DOS_ _FPUTS
    addq.l #6,sp
    POP_A6
    bra 9f
  @@:
    IOCS_ _B_PRINT
  9:
  lea (text_buffer,pc),a1
  rts


open_logfile:
  moveq #0,d0
  move.b (log_filename,pc),d0
  beq 9f
    PUSH_A6
    move #OPENMODE_WRITE,-(sp)
    pea (log_filename,pc)
    DOS_ _OPEN
    addq.l #6,sp
    POP_A6
    lea (fileno,pc),a1
    move d0,(a1)
    bmi 9f
      PUSH_A6
      move #SEEKMODE_END,-(sp)
      clr.l -(sp)
      move d0,-(sp)
      DOS_ _SEEK
      addq.l #8,sp
      POP_A6
  9:
  tst.l d0
  rts

close_logfile:
  move.b (log_filename,pc),d0
  beq 9f
    PUSH_A6
    move (fileno,pc),-(sp)
    bmi @f
      DOS_ _CLOSE
    @@:
    addq.l #2,sp
    POP_A6
  9:
  rts


* 常駐部 バッファ ----------------------------- *

text_buffer: .ds.b 96

log_filename: .ds.b sizeof_NAMECK


* 常駐部 データ ------------------------------- *

HEADER_A: .reg '┌ '  ;先頭行のヘッダー
HEADER_B: .reg '│ '  ;中間行のヘッダー
HEADER_C: .reg '└ '  ;末尾行のヘッダー

md_mes:      .dc.b HEADER_A,'MD = $',0
file_mes:    .dc.b HEADER_B,'FILE = $',0
file2_mes:   .dc.b HEADER_B,'FILE2 = $',0
cmdline_mes: .dc.b HEADER_B,'CMDLINE = $',0
buffer_mes:  .dc.b HEADER_B,'BUFFER = $',0
env_mes:     .dc.b HEADER_B,'ENV = $',0
loadadr_mes: .dc.b HEADER_B,'LOADADR = $',0
limit_mes:   .dc.b HEADER_B,'LIMIT = $',0
execadr_mes: .dc.b HEADER_B,'EXECADR = $',0
return_mes:  .dc.b HEADER_C,'d0.l = $',0

md_mes_table:
  .irpc %MD,012345u
    .dc.b md_mes_%MD-md_mes_table
  .endm

md_mes_0: .dc.b ' (loadexec)',0
md_mes_1: .dc.b ' (load)',0
md_mes_2: .dc.b ' (pathchk)',0
md_mes_3: .dc.b ' (loadonly)',0
md_mes_4: .dc.b ' (execonly)',0
md_mes_5: .dc.b ' (bindno)',0
md_mes_u: .dc.b ' (???)',0


* 非常駐部 ------------------------------------ *

.even
keep_size: .equ $-__main

_main:
  moveq #0,d6  ;0:常駐 $ff:常駐解除
  suba.l a5,a5  ;ログファイル名
  bsr analyze_arguments

  lea (__main-$100,pc),a0
  lea (__title,pc),a1
  bsr keepchk
  tst.b d6
  bne release

  tst.l d0
  beq already_keeped

  move.l a5,d0
  beq @f  ;ログファイル無指定ならコンソールに出力
    lea (a5),a0
    lea (log_filename,pc),a1
    bsr try_open_logfile
    bmi file_open_error
  @@:
  pea (new_dos_exec,pc)
  move #_EXEC,-(sp)
  DOS _INTVCS
  addq.l #6,sp
  lea (old_vec,pc),a1
  move.l d0,(a1)

  bsr print_progname
  pea (keep_mes,pc)
  DOS _PRINT

  clr -(sp)
  pea (keep_size).w
  DOS _KEEPPR


release:
  tst.l d0
  bmi not_keeped

  pea (16,a0)  ;DOS _MFREE 用
  lea ($100,a0),a0  ;= __main

  move.l (old_vec-__main,a0),-(sp)
  move #_EXEC,-(sp)
  DOS _INTVCG

  lea (new_dos_exec-__main,a0),a1
  cmp.l a1,d0
  bne overhooked

  DOS _INTVCS
  addq.l #6,sp

  ;move.l a0,-(sp)
  DOS _MFREE

  bsr print_progname
  pea (released_mes,pc)
  DOS _PRINT
  DOS _EXIT


try_open_logfile:
  bsr to_fullpath
  bmi 9f
    move #1<<FILEATR_ARCHIVE,-(sp)
    pea (a1)  ;フルパス化したファイル名
    DOS _NEWFILE  ;新規作成
    addq.l #6,sp
    tst.l d0
    bpl @f
      move #OPENMODE_WRITE,-(sp)
      pea (a1)
      DOS _OPEN  ;既に存在する場合は書き込みオープン
      addq.l #6,sp
      tst.l d0
      bmi 9f
    @@:
    move d0,-(sp)
    DOS _CLOSE
    addq.l #2,sp
    tst.l d0
  9:
  rts

to_fullpath:
  PUSH a0-a2
  pea (a1)  ;バッファ
  pea (a0)  ;ファイル名
  DOS _NAMECK
  addq.l #8,sp
  tst.l d0
  bmi 9f
    ;ドライブ名+パス名の後ろにファイル名と拡張子を繋げる
    lea (NAMECK_Drive,a1),a2
    STREND a2
    lea (NAMECK_Name,a1),a0
    STRCPY a0,a2,-1
    lea (NAMECK_Ext,a1),a0
    STRCPY a0,a2
    moveq #0,d0
  9:
  POP a0-a2
  rts


analyze_arguments:
  bra analyze_arg_next
  analyze_arg_loop:
    move.b (a0)+,d0
    beq analyze_arg_next
    cmpi.b #'-',d0
    beq @f
      subq.l #1,a0
      move.l a5,d0
      bne print_usage  ;すでにファイル名が指定されている
      lea (a0),a5
      STREND a0,+1
      bra analyze_arg_next
    @@:
    moveq #$20,d0
    or.b (a0)+,d0
    cmpi.b #'v',d0
    beq print_version
    cmpi.b #'r',d0
    bne print_usage
      tst.b (a0)+
      bne print_usage
        st d6  ;-r 常駐解除
  analyze_arg_next:
  dbra d7,analyze_arg_loop
  rts


print_usage:
  bsr print_title
  pea (usage_mes,pc)
  DOS _PRINT
  DOS _EXIT

print_version:
  bsr print_title
  DOS _EXIT

print_progname:
  pea (progname,pc)
  bra @f
print_title:
  pea (__title,pc)
@@:
  DOS _PRINT
  addq.l #4,sp
  rts

already_keeped:
  lea (already_keeped_mes,pc),a0
  bra @f
file_open_error:
  lea (fopen_error_mes,pc),a0
  bra @f
overhooked:
  lea (overhooked_mes,pc),a0
  bra @f
not_keeped:
  lea (not_keeped_mes,pc),a0
@@:
  bsr print_progname
  pea (a0)
  DOS _PRINT
  move #EXIT_FAILURE,(sp)
  DOS _EXIT


* Data Section -------------------------------- *

.data

usage_mes:
  .dc.b 'usage: exectrace [-r] [logfile]',CR,LF,0
progname:
  .dc.b 'exectrace: ',0

keep_mes:
  .dc.b '常駐しました。',CR,LF,0
already_keeped_mes
  .dc.b '既に常駐しています。',CR,LF,0

released_mes:
  .dc.b '常駐解除しました。',CR,LF,0
overhooked_mes:
  .dc.b 'ベクタが書き換えられています。',CR,LF,0
not_keeped_mes:
  .dc.b '常駐していません。',CR,LF,0

fopen_error_mes:
  .dc.b 'ログファイルがオープンできません。',CR,LF,0


.end __main
