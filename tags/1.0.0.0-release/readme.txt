
������

  perlRTMP - perl rtmp server

���@�\

  MPEG-2 TS �t�@�C���� Flash �v���[���[�փX�g���[�~���O����B
  �Ή����Ă���͉̂f�� H264�A���� AAC �� TS �t�@�C���̂݁B

  �������Z�O�� TS �t�@�C���ł�������e�X�g���Ă��܂���B

���K�v�Ȃ���

  �����炭�ǉ��C���X�g�[�����K�v�ȃ��C�u���������L�ł��B

    Digest::SHA

  yum ���ł���Ή��L�R�}���h�ŃC���X�g�[�����Ă��������B

    # yum install perl-Digest-SHA

���g����

  �W�J�����f�B���N�g���ŁA

    $ perl server.pl <document root>

  <document root> �� TS �t�@�C���̂���f�B���N�g�����w��B
  �����Ŏw�肵���f�B���N�g�� + NetStream.play() �̃t�@�C���������ۂ̃t�@�C���p�X�ɂȂ�܂��B

  Flash �v���[���[�� JW FLV MEDIA PLAYER 4.0 �𐄏��B

  JW FLV MEDIA PLAYER 4.0
  http://www.jeroenwijering.com/?item=JW_FLV_Media_Player

  ���L�� HTML ���쐬���ău���E�U�ŊJ���B

  192.168.xxx.xxx �̕����� perlRTMP �𑖂点�Ă���}�V���� IP �A�h���X���L�q�B
  test.ts �͑��݂���t�@�C�������L�q�B

  ��vod �����i�A�v���P�[�V�������j�� perlRTMP �ł͕K�v����܂��񂪁A
    JW FLV MEDIA PLAYER �̎d�l��Ȃɂ��L�q����K�v�����邽�ߏ����Ă���܂��B
    ���ۂ̃t�@�C���p�X�� <document root> �� vod/ �ȍ~�𑫂������̂ł��B

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

  �Z�L�����e�B�x�����o��ꍇ�� JW FLV MEDIA PLAYER ��u�����f�B���N�g����
  �����Ă��������B

�����ӎ���

  �����Z�O�� TS �t�@�C�����X�g���[�~���O���邽�߂ɕK�v�ȕ���������������Ă��܂���B
  RTMP�AAMF �Ȃǖ��Ή��ȃt�@���N�V�������������񂠂�܂��B

  perl �̎��s���x��A�����炭�T�X�g���[���������炢�����E�ł��B

���Q�l������

  RubyIZUMI by Takuma Mori
  http://code.google.com/p/rubyizumi/

  TSConverter by �e���~��
  http://theremin.890m.com/oneseg.htm

  mplex13818
  http://www.scara.com/~schirmer/o/mplex13818/

  mpeg4ip
  http://www.mpeg4ip.net/

���X�V����

  ver 1,0,0,0
    ����

