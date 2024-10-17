.title keepchk

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

.include doscall.mac


.offset 0
MSP_PREV:     .ds.l 1
MSP_KEEPFLAG:
MSP_PARENT:   .ds.l 1
MSP_END:      .ds.l 1
MSP_NEXT:     .ds.l 1
MSP_SIZE:
.text


.cpu 68000
.text

keepchk::

;input
;  a0.l = 自分のメモリ管理ポインタ
;  a1.l = 識別用文字列のアドレス

;output
;  d0.l =  0 : 常駐している
;       = -1 : 常駐していない
;  a0.l = メモリ管理ポインタ
;         d0.l = 0 の時、見つけた常駐プロセスのメモリ管理ポインタ
;         d0.l = -1の時、自分のメモリ管理ポインタ

~idlen:  .reg d3
~offset: .reg d4
~idstr:  .reg a1
~mymsp:  .reg a4

usereg: .reg d1-d4/a1-a4
  movem.l usereg,-(sp)

  lea (a0),~mymsp

  move.l ~idstr,~offset
  sub.l a0,~offset  ;識別用文字列までのバイト数

  lea (~idstr),a2
  @@:
    tst.b (a2)+
  bne @b
  subq.l #1,a2
  suba.l a1,a2
  move.l a2,~idlen  ;識別文字列の長さ

  clr.l -(sp)
  DOS _SUPER
  move.l d0,(sp)
@@:
  movea.l (MSP_PARENT,a0),a0
  tst.l (MSP_PARENT,a0)
  bne @b

  moveq #-1,d2  ;常駐フラグ
check_loop:
  cmp.b (MSP_KEEPFLAG,a0),d2
  bne next_msp

  lea (a0,~offset.l),a2
  adda ~idlen,a2

  cmpa.l (MSP_END,a0),a2
  bcc next_msp

  suba ~idlen,a2
  lea (~idstr),a3
  move ~idlen,d0
@@:
  cmp.b (a2)+,(a3)+
  dbne d0,@b
  beq found
next_msp:
  move.l (MSP_NEXT,a0),d0
  movea.l d0,a0
  bne check_loop

  lea (~mymsp),a0
  bra done

found:
  moveq #0,d2
done:
  tst.b (sp)
  bmi @f
    DOS _SUPER
  @@:
  addq.l #4,sp

  move.l d2,d0

  movem.l (sp)+,usereg
  rts


.end
