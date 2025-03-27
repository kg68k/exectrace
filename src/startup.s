;スタートアップルーチン

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
.include process.mac


;スタートアップ処理
;in a0/a1/a2 プログラム起動時の値
;out
;  d7.l = 引数の数(argc:0～32767)
;  a0.l = 引数列の先頭アドレス(=スタック上限)
;  a6.l = プログラム末尾
;  sp.l = ユーザスタック上限
;  他のレジスタは不定。

;スタック容量
.ifndef STACK_SIZE
  STACK_SIZE: .equ 8192
.endif
.fail (STACK_SIZE.and.3).or.(STACK_SIZE<4096)


.text

Initialize::
  lea (a1),a6

  movea.l (MEMBLK_End,a0),a3
  bsr decode_hupair

  move.l a1,d0
  addq.l #3,d0
  andi #.not.3,d0
  movea.l d0,a1  ;4バイト境界に合わせる
  adda.l #STACK_SIZE,a1
  bsr setblock

  movea.l (sp)+,a4  ;スタックを差し替えるのでリターンアドレスを取り出しておく
  lea (a1),sp

  lea (a6),a0  ;引数列のアドレス
  jmp (a4)


;引数の HUPAIR デコード
;in a1.l バッファアドレス
;   a2.l コマンドライン
;   a3.l バッファ末尾のアドレス
;out d7.l 引数の数
;    a1.l 引数列の末尾アドレス
decode_hupair:
  moveq #0,d7  ;argc
  addq.l #1,a2
dechupair_loop:
  move.b (a2)+,d2
  beq dechupair_end
  cmpi.b #' ',d2
  beq dechupair_loop

  addq #1,d7
dechupair_no_quot_loop:
  cmpi.b #'"',d2
  beq dechupair_quot
  cmpi.b #"'",d2
  beq dechupair_quot

  cmpa.l a3,a1
  bcc not_enough_memory
  move.b d2,(a1)+
dechupair_quot_end:
  move.b (a2)+,d2
  beq dechupair_stop  ;0を書き込んで終わり
  cmpi.b #' ',d2
  bne dechupair_no_quot_loop

  cmpa.l a3,a1
  bcc not_enough_memory
  clr.b (a1)+
  bra dechupair_loop

dechupair_quot:
  move.b d2,d1
dechupair_quot_loop:
  move.b (a2)+,d2
  cmp.b d2,d1
  beq dechupair_quot_end
dechupair_stop:
  cmpa.l a3,a1
  bcc not_enough_memory
  move.b d2,(a1)+
  bne dechupair_quot_loop
dechupair_end:
  rts


;メモリブロックの大きさを変更する
;in  a0.l メモリ管理ポインタ
;    a1.l 変更後のメモリの末尾+1
setblock:
  PUSH a0-a1
  lea (sizeof_MEMBLK,a0),a0
  suba.l a0,a1
  pea (a1)
  pea (a0)
  DOS _SETBLOCK
  addq.l #8,sp
  POP a0-a1
  tst.l d0
  bmi not_enough_memory
  rts


not_enough_memory:
  move #STDERR,-(sp)
  clr -(sp)
  DOS _IOCTRL
  addq.l #2,sp
  andi.b #0b1010_0000,d0
  cmpi.b #0b1000_0000,d0  ;char && cooked か?
  beq @f
    lea (memory_error_mes2,pc),a0
    subq.b #CR-LF,(a0)+  ;それ以外のファイルなら LF 改行にする
    clr.b (a0)
@@:
  pea (memory_error_mes,pc)
  DOS _FPUTS
  move #EXIT_FAILURE,(sp)
  DOS _EXIT2


memory_error_mes:
  .dc.b 'not enough memory.'
memory_error_mes2:
  .dc.b CR,LF,0
  .even


.end
