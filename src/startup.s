;スタートアップルーチン

;This file is part of exectrace
;Copyright (C) 2024 TcbnErik
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

.include console.mac
.include doscall.mac


.text

;ソースファイルの .text セクションの先頭に .include すること。
;メモリ、引数などを初期化してから _main に飛ぶ。

;制御シンボル
;  プログラムの題名            _TITLE
;  メモリ不足時の終了コード    _EXIT_NOMEM
;  ワークバッファの容量        _WORK_SIZE
;  スタックの容量              _STACK_SIZE
;  空引数を無視する場合に定義  _IGNORE_NUL_ARG

;_main 実行時の引数
;  d7.l = 引数の数(argc:0～32767)
;  a0.l = 引数列の先頭アドレス(=スタック上限)
;  a2.l = argv[0](_TAKE_ARGV0 定義時のみ)
;  a6.l = ワーク先頭(=プロクラム末尾)
;  a7.l = ユーザスタック上限
;  他のレジスタは不定。

;メモリイメージ
;  __main
;  _main
;  data
;  work : a6
;  stack
;  arg_buf : sp


.ifndef _TITLE
  _TITLE: .reg "Erik's StartUp"
.endif

.ifndef _EXIT_NOMEM
  _EXIT_NOMEM: .equ 32767
.endif

.ifndef _WORK_SIZE
  _WORK_SIZE: .equ 0
.endif
.fail (_WORK_SIZE.and.3).or.(_WORK_SIZE<0)

.ifndef _STACK_SIZE
  _STACK_SIZE: .equ 8192
.endif
.fail (_STACK_SIZE.and.3).or.(_STACK_SIZE<4096)

_ARGBUF_SIZE: .equ 32768  ;32KB 固定


.text
.even
__main:
  bra.s __main1
  .dc.b '#HUPAIR',0
__title:
  .dc.b _TITLE,0
__setblock_error_mes:
  .dc.b 'startup: setblock failed.'
__setblock_error_mes_2:
  .dc.b CR,LF,0
  .even

__main1:
  lea (16,a0),a0  ;MEMTOP
  lea (a1),a6     ;WORK
  adda.l #(_WORK_SIZE+_STACK_SIZE+_ARGBUF_SIZE),a1
  pea (-_ARGBUF_SIZE,a1)  ;STACK

  bsr __setblock_myself

  movea.l (sp)+,sp

  ;引数の HUPAIR デコード
  moveq #0,d3  ;argc
  lea (sp),a1  ;書き込みポインタ
  addq.l #1,a2
__dechupair_loop:
  move.b (a2)+,d2
  beq __dechupair_end
  bsr __is_space
  beq __dechupair_loop

  .ifdef _IGNORE_NUL_ARG
    bsr __is_quate
    bne @f
    cmp.b (a2)+,d2
    beq __dechupair_loop
    subq.l #1,a2
  @@:
  .endif

  addq #1,d3
__dechupair_no_quate_loop:
  bsr __is_quate
  beq __dechupair_quate
__dechupair_no_quate:
  move.b d2,(a1)+
__dechupair_quate_end:
  move.b (a2)+,d2
  beq __dechupair_stop  ;0を書き込んで終わり
  bsr __is_space
  bne __dechupair_no_quate_loop

  clr.b (a1)+
  bra __dechupair_loop

__is_space:
  cmpi.b #$20,d2
  rts
__is_quate:
  cmpi.b #'"',d2
  beq @f
    cmpi.b #"'",d2
  @@:
  rts

;in  a0.l メモリブロックのアドレス
;    a1.l 変更後のメモリの末尾+1
;out a1.l 変更後のメモリブロックの大きさ
__setblock_myself:
  suba.l a0,a1
  move.l a1,-(sp)
  move.l a0,-(sp)
  DOS _SETBLOCK
  addq.l #8,sp
  tst.l d0
  bmi __setblock_error
  rts
__setblock_error:
  move #2,-(sp)  ;STDERR
  clr -(sp)
  DOS _IOCTRL
  addq.l #2,sp
  andi.b #0b1010_0000,d0
  cmpi.b #0b1000_0000,d0  ;char && cooked か?
  beq @f

  lea (__setblock_error_mes_2,pc),a0
  subq.b #3,(a0)+  ;それ以外のファイルなら LF 改行にする
  clr.b (a0)
@@:
  pea (__setblock_error_mes,pc)
  DOS _FPUTS
  move #_EXIT_NOMEM,(sp)
  DOS _EXIT2

__dechupair_quate:
  move.b d2,d1
__dechupair_quate_loop:
  move.b (a2)+,d2
  cmp.b d2,d1
  beq __dechupair_quate_end
__dechupair_stop:
  move.b d2,(a1)+
  bne __dechupair_quate_loop
__dechupair_end:

  bsr __setblock_myself  ;必要な分だけにする.

  lea (sp),a0  ;引数列のアドレス
  move d3,d7
  bra _main

;.end __main
