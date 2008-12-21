
○名称

  perlRTMP - perl rtmp server

  http://code.google.com/p/perlrtmp/

○機能

  MPEG-2 TS ファイルを Flash プレーヤーへストリーミングする。
  対応しているのは映像 H264、音声 AAC の TS ファイルのみ。

  ※ワンセグの TS ファイルでしか動作テストしていません。

○必要なもの

  おそらく追加インストールが必要なライブラリが下記です。

    Digest::SHA

  yum 環境であれば下記コマンドでインストールしてください。

    # yum install perl-Digest-SHA

○使い方

  展開したディレクトリで、

    $ perl server.pl <document root>

  <document root> は TS ファイルのあるディレクトリを指定。
  ここで指定したディレクトリ + NetStream.play() のファイル名が実際のファイルパスになります。

  Flash プレーヤーは JW FLV MEDIA PLAYER 4.0 を推奨。

  JW FLV MEDIA PLAYER 4.0
  http://www.jeroenwijering.com/?item=JW_FLV_Media_Player

  下記の HTML を作成してブラウザで開く。

  192.168.xxx.xxx の部分は perlRTMP を走らせているマシンの IP アドレスを記述。
  test.ts は存在するファイル名を記述。

  ※vod 部分（アプリケーション名）は perlRTMP では必要ありませんが、
    JW FLV MEDIA PLAYER の仕様上なにか記述する必要があるため書いてあります。
    実際のファイルパスは <document root> に vod/ のあとを足したものです。

-------------------------------------------------------------
<html>
<body>
<script type='text/javascript' src='swfobject.js'></script>
<div id='preview'>This div will be replaced</div>
<script type='text/javascript'>
var s1 = new SWFObject('player.swf','player','320','200','9','#ffffff');
s1.addParam('allowfullscreen','true');
s1.addParam('allowscriptaccess','always');
s1.addParam('wmode','opaque');
s1.addParam('flashvars','file=rtmp://192.168.xxx.xxx/vod/test.ts');
s1.write('preview');
</script>
</body>
</html>
-------------------------------------------------------------

  セキュリティ警告が出る場合は JW FLV MEDIA PLAYER を置いたディレクトリを
  許可してください。

○注意事項

  ワンセグの TS ファイルをストリーミングするために必要な部分しか実装されていません。
  RTMP、AMF など未対応なファンクションがたくさんあります。

  perl の実行速度上、おそらく５ストリーム同時くらいが限界です。

  1 ファイルで 25 時間以上ある動画はうまく再生できません。
  これは約 26 時間 30 分で巡回してしまう PTS をつかった計算を
  比較対象が 25 時間以上離れていたら巡回したとみなす方法で行っているためです。

○参考＆感謝

  RubyIZUMI by Takuma Mori
  http://code.google.com/p/rubyizumi/

  TSConverter by テルミン
  http://theremin.890m.com/oneseg.htm

  mplex13818
  http://www.scara.com/~schirmer/o/mplex13818/

  mpeg4ip
  http://www.mpeg4ip.net/

○更新履歴

  ver 1,0,0,7
    壊れた TS ファイルを読ませるとしばらく反応がなくなるのを引き続き修正。
    duration を調べる前にシークを行うと 0 除算エラーになるのを修正。
    RTMP 関係と MPEG2-TS 関係でバイナリデータの扱い方が違っていたのを統一。
    H264 のパースで index 関数を使うようにして高速化。
    書き込み中のファイル（次第に容量が増えていくファイル）を再生すると
    シーク位置がどんどんずれて行くのを修正。

  ver 1,0,0,6
    壊れた TS ファイルを読ませるとしばらく反応がなくなるのを修正。
    最初の duration を調べるときにわかった映像と音声の PID を以降使いまわすようにした。
    これによって TS ファイルによっては 2 秒近く頭切れしていたのの改善と、
    シークがちょっと速くなったかも。

  ver 1,0,0,5
    O_LARGEFILE が使えない環境でもエラーが出ないようにした。
    再生完了で NetStream.Play.Stop と NetStream.Play.Complete を送信するようにした。
    pause 命令に対応。
    ※Flash Player が実際に pause 命令を送ってくるのは NetStream.pause() 後、
      NetStream.bufferLength が 60 を超えてからのようです。

  ver 1,0,0,4
    メモリーリークしていたのを解消。
    4 時間 40 分（16777 秒）以降にシークすると再生タイムがおかしくなるのを修正。
    PTS の巡回判定を 25 時間以上離れていたらに変更（変更前は約 13 時間 15 分以上離れていたら）。
    音声情報が二ヶ国語放送のときにチャンネル数を強制的に 2 にするようにした。

  ver 1,0,0,0
    初版

