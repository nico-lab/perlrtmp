
○名称

  perlRTMP - perl rtmp server

  http://code.google.com/p/perlrtmp/

○機能

  H264/AAC の MPEG-2 TS、MP4 ファイルを Flash プレーヤーへストリーミングする。

  ※FLV ファイルは未対応です。

  『24時間ワンセグ野郎』のファイル形式 (.ts & .idx) にも対応しています。

○必要なもの

  おそらく追加インストールが必要なライブラリが下記です。

    Digest::SHA

  yum 環境であれば下記コマンドでインストールしてください。

    # yum install perl-Digest-SHA

○使い方

  展開したディレクトリで、

    $ perl server.pl <document root>

  <document root> はファイルのあるディレクトリを指定。
  ここで指定したディレクトリ + NetStream.play() のファイル名が
  実際のファイルパスになります。

  Flash プレーヤーは JW FLV MEDIA PLAYER を推奨。

  JW FLV MEDIA PLAYER
  http://www.jeroenwijering.com/?item=JW_FLV_Media_Player

  下記の HTML を作成してブラウザで開く。

  192.168.xxx.xxx の部分は perlRTMP を走らせているマシンの IP アドレスを記述。
  test.ts は存在するファイル名を記述。

  ※JW FLV MEDIA PLAYER 4.2 からファイルの指定の仕方が変わったようです。
    RTMP サーバとファイル名を別々に指定するようになり、
    さらに不明な拡張子は JW FLV MEDIA PLAYER 自体がエラーを出してしまうので
    ダミーの拡張子を付け足す必要があります。（例：test.ts.flv）
    MP4 の場合はそのままで OK です。（例：test.mp4）

  ※ファイル名が 000000-000000-000000-00.flv もしくは 000000-000000-00.flv
    というフォーマットの場合、『24時間ワンセグ野郎』のファイル形式と
    判断します。（例：081201-210000-215400-21.flv）
    この場合の実際のファイルパスは、
    <document root>/yymmdd/yymmddhh_Chnn.ts と .idx です。

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
s1.addParam('flashvars','streamer=rtmp://192.168.xxx.xxx&file=test.ts.flv');
s1.write('preview');
</script>
</body>
</html>
-------------------------------------------------------------

  セキュリティ警告が出る場合は JW FLV MEDIA PLAYER を置いたディレクトリを
  許可してください。

○注意事項

  H264/AAC の MPEG-2 TS、MP4 ファイルをストリーミングするために
  必要な部分しか実装されていません。
  RTMP、AMF などで未対応なファンクションがたくさんあります。

  perl の実行速度上、おそらく５ストリーム同時くらいが限界です。

  1 ファイルで 25 時間以上ある MPEG-2 TS ファイルはうまく再生できません。
  これは約 26 時間 30 分で巡回してしまう PTS をつかった計算を
  比較対象が 25 時間以上離れていたら巡回したとみなす方法で行っているためです。

  MP4 ファイルのシークが遅いです（特に VFR の場合）。
  誰か書き直してください…

○参考＆感謝

  24時間ワンセグ野郎 by MIRO
  http://mobilehackerz.jp/contents/OneSeg24

  RubyIZUMI by Takuma Mori
  http://code.google.com/p/rubyizumi/

  TSConverter by テルミン
  http://theremin.890m.com/oneseg.htm

  mplex13818
  http://www.scara.com/~schirmer/o/mplex13818/

  mpeg4ip
  http://www.mpeg4ip.net/

  ARIB STD-B10
  http://www.arib.or.jp/tyosakenkyu/kikaku_hoso/hoso_kikaku_number.html

○更新履歴

  ver 1,0,1,0
    『24時間ワンセグ野郎』のファイル形式 (.ts & .idx) にネイティブ対応。
    MP4 フォーマットに対応。
    PLAYSTATION 3 の Flash 9 に対応。
    本家 FMS で再生できない MP4 ファイルも再生できたりします。

  ver 1,0,0,8 未公開
    データの送信間隔を「5 秒ごとに 5 秒分のデータ」から
    「1 秒ごとに 1 秒分のデータ」に変更。
    PPC など big endian 環境で動かなかったのを修正。

  ver 1,0,0,7
    壊れた TS ファイルを読ませるとしばらく反応がなくなるのを引き続き修正。
    duration を調べる前にシークを行うと 0 除算エラーになるのを修正。
    RTMP 関係と MPEG2-TS 関係でバイナリデータの扱い方が違っていたのを統一。
    H264 のパースで index 関数を使うようにして高速化。
    書き込み中のファイル（次第に容量が増えていくファイル）を再生すると
    シーク位置がどんどんずれて行くのを修正。

  ver 1,0,0,6
    壊れた TS ファイルを読ませるとしばらく反応がなくなるのを修正。
    最初の duration を調べるときにわかった映像と音声の PID を
    以降使いまわすようにした。
    これによって TS ファイルによっては 2 秒近く頭切れしていたのの改善と、
    シークがちょっと速くなったかも。

  ver 1,0,0,5
    O_LARGEFILE が使えない環境でもエラーが出ないようにした。
    再生完了で NetStream.Play.Stop と NetStream.Play.Complete を
    送信するようにした。
    pause 命令に対応。
    ※Flash Player が実際に pause 命令を送ってくるのは NetStream.pause() 後、
      NetStream.bufferLength が 60 を超えてからのようです。

  ver 1,0,0,4
    メモリーリークしていたのを解消。
    4 時間 40 分（16777 秒）以降にシークすると
    再生タイムがおかしくなるのを修正。
    PTS の巡回判定を 25 時間以上離れていたらに変更。
    （変更前は約 13 時間 15 分以上離れていたら）
    音声情報が二ヶ国語放送のときにチャンネル数を強制的に 2 にするようにした。

  ver 1,0,0,0
    初版

