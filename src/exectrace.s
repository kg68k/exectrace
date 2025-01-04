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
VERSION: .reg '1.0.1'
YEAR:    .reg '2025'
AUTHOR:  .reg 'TcbnErik'
_TITLE: .reg PROGRAM,' ',VERSION,'  Copyright (C)',YEAR,' ',AUTHOR,'.',CRLF


.offset 0
exec_md:      .ds.w 1
exec_file:
exec_address: .ds.l 1
exec_cmdline:
exec_buffer:
exec_load:
exec_target:  .ds.l 1
exec_env:
exec_limit:   .ds.l 1
exec_env2:    .ds.l 1


.offset 0
  .dc.b _TITLE,0
titlelen:
filename_buf: .equ __title+titlelen
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
filename_bufend:

old_vec: .dc.l 0
fileno:  .dc.w 0

new_dos_exec:
  PUSH usereg
  bsr open_logfile
  bne open_logfile_error

  move.l (exec_md,a6),d0  ;module+mode を表示
  lea (md_mes,pc),a1
  lea (7,a1),a0
  moveq #4-1,d1
  bsr print_hex

  moveq #0,d1
  move.b (exec_md+1,a6),d1
  cmpi #5,d1
  bhi unknown_mode  ;mode>=6ならモードと返値だけ表示

  add d1,d1
  move d1,-(sp)
  lea (md_mes_table,pc,d1.w),a1
  adda (a1),a1
  bsr print_str

  move (sp)+,d1
  move (md_table,pc,d1.w),d1
  jmp (md_table,pc,d1.w)

md_mes_table:
  .irpc %MD,012345
    .dc md_mes_%MD-$
  .endm
md_table:
  .irpc %MD,012345
    .dc md_%MD-md_table
  .endm

md_0:
md_1:
  bsr print_file

  lea (cmdline_mes,pc),a1
  lea (12,a1),a0
  move.l (exec_cmdline,a6),d0
  bsr print_hex8
  movea.l (exec_cmdline,a6),a1
  addq.l #1,a1  ;文字列長を飛ばす
  bsr print_str

  bra print_env_ret

md_2:
  bsr print_file

  lea (buffer_mes,pc),a1
  lea (11,a1),a0
  move.l (exec_buffer,a6),d0
  bsr print_hex8

  bra print_env_ret

md_3:
  bsr print_file

  lea (load_mes,pc),a1
  lea (8,a1),a0
  move.l (exec_load,a6),d0
  bsr print_hex8

  lea (limit_mes,pc),a1
  lea (9,a1),a0
  move.l (exec_limit,a6),d0
  bsr print_hex8

  move.l (exec_env2,a6),d0
  bra print_env2_ret

md_4:
  lea (address_mes,pc),a1
  lea (12,a1),a0
  move.l (exec_address,a6),d0
  bsr print_hex8

  movea.l ($1c28),a0  ;PSP 格納ワークへのポインタ
  movea.l (a0),a0     ;PSP
  move.l ($20,a0),d0  ;コマンドラインのアドレス
  lea (cmdline_mes2,pc),a1
  lea (12-1,a1),a0
  move.l d0,-(sp)
  bsr print_hex8
  movea.l (sp)+,a1
  addq.l #1,a1  ;文字列長を飛ばす
  bsr print_str

  lea (newline,pc),a1
  bsr print_str

  bra print_return_value

md_5:
  bsr print_file

  lea (target_mes,pc),a1
  lea (10,a1),a0
  move.l (exec_target,a6),d0
  bsr print_hex8
  movea.l (exec_target,a6),a1
  bsr print_str
unknown_mode:
  lea (newline,pc),a1
  bsr print_str
  bra print_return_value

print_env_ret:
  move.l (exec_env,a6),d0
print_env2_ret:
  lea (env_mes,pc),a1
  lea (8,a1),a0
  bsr print_hex8
print_return_value:
  POP usereg
  bsr call_dos_exec_orig
  PUSH usereg

  lea (ret_mes,pc),a1
  lea (7,a1),a0
  bsr print_hex8

  bsr close_logfile
  POP usereg
  rts

open_logfile_error:
  bsr close_logfile
  POP usereg
call_dos_exec_orig:
  move.l (old_vec,pc),-(sp)
  rts

print_file:
  lea (file_mes,pc),a1
  lea (9,a1),a0
  move.l (exec_file,a6),d0
  bsr print_hex8
  movea.l (exec_file,a6),a1
  bra print_str

hextable: .dc.b '0123456789abcdef'
.even

print_hex8:
  moveq #8-1,d1
print_hex:
  @@:
    rol.l #4,d0
    moveq #$f,d2
    and d0,d2
    move.b (hextable,pc,d2.w),(a0)+
  dbra d1,@b
  bra print_str

print_str:
  move.b (filename_buf,pc),d0
  beq print_str_console

  PUSH_A6
  move (fileno,pc),-(sp)
  move.l a1,-(sp)
  DOS_ _FPUTS
  addq.l #6,sp
  POP_A6
  rts

print_str_console:
  .ifdef __CRLF__
    cmpi.b #LF,(a1)
    bne @f
      addq.l #1,a1  ;先頭のLFは代わりにCRLFを表示する
      bsr print_crlf
    @@:

    move.l a1,d1
    @@:
      move.b (a1)+,d0
      beq @f
      cmpi.b #LF,d0
      bne @b
    @@:
    movea.l d1,a1
    tst.b d0
    bne print_str_con_lf  ;文字列内にLFがあれば特別に処理する
  .endif

  IOCS_ _B_PRINT
  rts

.ifdef __CRLF__
print_crlf:
  move.l a1,d1
  lea (crlf,pc),a1
  IOCS _B_PRINT
  movea.l d1,a1
  rts

@@:
  bsr print_crlf
print_str_con_lf:
  moveq #0,d1
  bra 2f
  1:
    cmpi #LF,d1
    beq @b
    IOCS_ _B_PUTC
  2:
  move.b (a1)+,d1
  bne 1b
  rts
.endif

open_logfile:
  lea (filename_buf,pc),a1
  tst.b (a1)
  beq open_logfile_ok

  PUSH_A6
  move #OPENMODE_WRITE,-(sp)
  move.l a1,-(sp)
  DOS_ _OPEN
  addq.l #6,sp
  POP_A6
  lea (fileno,pc),a1
  move d0,(a1)
  bmi @f

  PUSH_A6
  move #SEEKMODE_END,-(sp)
  clr.l -(sp)
  move d0,-(sp)
  DOS_ _SEEK
  addq.l #8,sp
  POP_A6
  tst.l d0
  bmi @f
open_logfile_ok:
  moveq #0,d0
@@:
  rts

close_logfile:
  move.b (filename_buf,pc),d0
  beq close_logfile_ok

  PUSH_A6
  move (fileno,pc),-(sp)
  bmi @f
  DOS_ _CLOSE
@@:
  addq.l #2,sp
  POP_A6
close_logfile_ok:
  rts


* 常駐部 データ ------------------------------- *

md_mes: .dc.b LF,'MD',TAB,'= $0000',0

md_mes_0: .dc.b '(loadexec)',0
md_mes_1: .dc.b '(load)',0
md_mes_2: .dc.b '(pathchk)',0
md_mes_3: .dc.b '(loadonly)',0
md_mes_4: .dc.b '(execonly)',0
md_mes_5: .dc.b '(bindno)',0

file_mes:     .dc.b LF,'FILE',   TAB,'= $00000000 : ',0

cmdline_mes:  .dc.b LF
cmdline_mes2: .dc.b    'CMDLINE',TAB,'= $00000000 : ',0

env_mes:      .dc.b LF,'ENV',    TAB,'= $00000000',LF,0

buffer_mes:   .dc.b LF,'BUFFER', TAB,'= $00000000',0

load_mes:     .dc.b LF,'LOAD',   TAB,'= $00000000',LF,0
limit_mes:    .dc.b    'LIMIT',  TAB,'= $00000000',0

address_mes:  .dc.b LF,'ADDRESS',TAB,'= $00000000',LF,0

target_mes:   .dc.b    'TARGET', TAB,'= $00000000 : ',0

ret_mes:      .dc.b    'RET',    TAB,'= $00000000',LF,0

crlf:         .dc.b CR
newline:      .dc.b LF,0

.even
keep_size: .equ $-__main


* 非常駐部 ------------------------------------ *

_main:
  moveq #0,d6  ;0=ファイル無指定 1=指定あり -1=-r
  lea (filename_buf,pc),a1
  move.b d6,(a1)
get_argument_next:
  dbra d7,argument_loop

  lea (__main-$100,pc),a0
  lea (__title,pc),a1
  bsr keepchk
  tst d6
  bmi release

  tst.l d0
  beq already_keeped

  ;logfile をオープンする
  tst d6
  beq opentest_skip  ;consoleに出力

  move #1<<FILEATR_ARCHIVE,-(sp)
  pea (filename_buf,pc)
  DOS _NEWFILE  ;新規作成
  tst.l d0
  bpl opentest_ok

  move #OPENMODE_WRITE,(4,sp)
  DOS _OPEN  ;既に存在する場合は書き込みオープン
  tst.l d0
  bpl opentest_ok

  pea (fopen_error_mes,pc)
  bra print_exit_error

opentest_ok:
  addq.l #6,sp
  DOS _ALLCLOSE
opentest_skip:
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

already_keeped:
  bsr print_progname
  pea (already_keeped_mes,pc)
  bra print_exit_error

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

overhooked:
  bsr print_progname
  pea (overhooked_mes,pc)
  bra print_exit_error
not_keeped:
  bsr print_progname
  pea (not_keeped_mes,pc)
  bra print_exit_error

argument_loop:
  move.b (a0)+,d1

  cmpi.b #'-',d1
  beq check_option

  tst d6
  bne print_usage
  moveq #1,d6  ;ファイル指定あり

  subq.l #1,a0
  ;lea (filename_buf,pc),a1
  moveq #filename_bufend-filename_buf-1,d0
@@:
  move.b (a0)+,(a1)+
  dbeq d0,@b
  beq get_argument_next

  bsr print_progname
  pea (too_long_mes,pc)
  bra print_exit_error

check_option:
  moveq #-1,d6  ;-r

  move.b (a0)+,d1
  beq print_usage
  ori.b #$20,d1
  cmpi.b #'v',d1
  beq print_proginfo

  tst.b (a0)+
  bne print_usage
  cmpi.b #'r',d1
  beq get_argument_next
print_usage:
  bsr print_title
  pea (usage_mes,pc)
print_exit_error:
  DOS _PRINT
  move #EXIT_FAILURE,(sp)
  DOS _EXIT

print_proginfo:
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


* Data Section -------------------------------- *

.data

usage_mes:
  .dc.b 'usage: exectrace [-r] [logfile]',CRLF,0
progname:
  .dc.b 'exectrace: ',0
too_long_mes:
  .dc.b 'ファイル名が長すぎます。',CRLF,0

keep_mes:
  .dc.b '常駐しました。',CRLF,0
already_keeped_mes
  .dc.b '既に常駐しています。',CRLF,0

released_mes:
  .dc.b '常駐解除しました。',CRLF,0
overhooked_mes:
  .dc.b 'ベクタが書き換えられています。',CRLF,0
not_keeped_mes:
  .dc.b '常駐していません。',CRLF,0

fopen_error_mes:
  .dc.b 'ログファイルがオープン出来ません。',CRLF,0


.end __main

* End of Source ------------------------------- *


MD = 0,1
FILE = $???????? : foo.x
CMDLINE = $???????? : bar
ENV = $????????
RET = $????????

MD = 2
FILE = $???????? : foo.x
BUFFER = $????????
ENV = $????????
RET = $????????

MD = 3
FILE = $???????? : foo.x
LOAD = $????????
LIMIT = $????????
ENV = $????????
RET = $????????

MD = 4
ADDRESS = $????????
CMDLINE = $???????? : bar (引数には無いが表示した方が便利)
RET = $????????

MD = 5
FILE = $???????? : foo.x
TARGET = $???????? : bar.x
RET = $????????


* End of File --------------------------------- *
