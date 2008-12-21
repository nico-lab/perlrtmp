
○名称

  perlRTMP - perl rtmp server

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
    実際のファイルパスは <document root> に vod/ 以降を足したものです。

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

  ver 1,0,0,0
    初版

