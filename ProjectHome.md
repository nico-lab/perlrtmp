# perlRTMP #

perlで書かれたRTMPサーバ。

**対応フォーマット**
  * MPEG2-TS (.ts)
  * MP4 (.mp4)
  * 『24時間ワンセグ野郎』(.ts & .idx)

## どうしてperl？ ##

自由に使える言語がperlくらいしかなかった。<br>
rubyで出来るならperlでも出来るんじゃないか、と。<br>
<br>
<h2>どうしてMPEG2-TS？</h2>

『24時間ワンセグ野郎』に触発されて24時間ワンセグ録画サーバを作った。ただしLinuxで。<br>
Windowsから視聴するためにストリーミング（もしくはプログレッシブダウンロード）しようと思うとどうしてもMP4に変換する必要があり時間がかかる。<br>
また、MP4に変換する際、映像と音声を分離してしまうとVFRな局が激しく音ズレしてしまい、それを防ごうとタイムコードの抽出や埋め込みを行うとさらに時間がかかる。<br>
映像と音声を同時に送信するストリーミングなら音ズレの心配はないので、あとはMPEG2-TSが直接扱えるRTMPサーバがあればいいと思った。<br>
<br>
<h3>姉妹サイト</h3>

<ul><li>OneSeg24 for Linux<br>
</li><li><a href='http://code.google.com/p/oneseg24/'>http://code.google.com/p/oneseg24/</a></li></ul>

<h3>参考</h3>

<ul><li>RubyIZUMI<br>
</li><li><a href='http://code.google.com/p/rubyizumi/'>http://code.google.com/p/rubyizumi/</a></li></ul>

<ul><li>24時間ワンセグ野郎<br>
</li><li><a href='http://mobilehackerz.jp/contents/OneSeg24'>http://mobilehackerz.jp/contents/OneSeg24</a></li></ul>

<ul><li>【UOT-100】24時間ワンセグ野郎 Part03【LOG-J200】<br>
</li><li><a href='http://pc11.2ch.net/test/read.cgi/avi/1232374302/'>http://pc11.2ch.net/test/read.cgi/avi/1232374302/</a>