# 1.1.0-beta.1

* 表示処理を作り直した。
  * 一組ごとのまとまりが分かりやすいよう、左端に└─┘で枠を表示する。
  * コンソールに表示する際の改行をCRLFに変更。
  * bindnoで改行の不足により表示が乱れる不具合を修正。
* ログファイル名を相対パスで指定するとカレントディレクトリ変更時に書き込まれない不具合を修正。


# 1.0.2 (2025-01-09)

* loadonlyでロードアドレスの表示が乱れる不具合を修正
  ([#2](https://github.com/kg68k/exectrace/pull/2) by [iwadon](https://github.com/iwadon))。
* loadonlyで環境変数アドレスを表示する不具合を修正。


# 1.0.1 (2025-01-04)

* loadonlyで改行の過不足により表示が乱れる不具合を修正
  ([#1](https://github.com/kg68k/exectrace/pull/1) by [iwadon](https://github.com/iwadon))。


# 1.0.0 (2024-10-18)

* プロジェクト名をchkexecからexectraceに変更。
* 改行モードをCRLFに変更。
