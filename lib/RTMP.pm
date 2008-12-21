package RTMP;

use strict;
use Scalar::Util qw(weaken);
use RTMP::Handshake;
use RTMP::Serializer;
use RTMP::Method;
use RTMP::AMF;
use TS;
use Binary;

sub new {
	my($pkg, $sock, $dir) = @_;

	my $hash = {
		sock => $sock,
		dir => $dir,
		handshake => undef,
		serializer => undef,
		method => undef,
		buffer => undef,
		file => undef,
	};

	my $s = bless $hash, $pkg;

	$s->{handshake} = RTMP::Handshake->new($s);
	$s->{serializer} = RTMP::Serializer->new($s);
	$s->{method} = RTMP::Method->new($s);
	$s->{buffer} = Binary->new();
	weaken($s->{sock});

	return $s;
}

sub receive {
	my($s, $buf) = @_;

	$s->{buffer}->append($buf);

	while($s->{buffer}->{pos} < $s->{buffer}->{length}) {
		if (!$s->{handshake}->complete) {
			$s->{handshake}->execute();
			next;
		}

		my $packet = $s->{serializer}->receive();

		if ($packet->{data_type} == 20) {
			my($method, $request_id, $args, $option) = RTMP::AMF::loadArray($packet->{data});

			if ($method eq 'connect') {
				$s->{method}->connect();
				warn "[rtmp] connect\n";
			} elsif ($method eq 'createStream') {
				$s->{method}->createStream();
				warn "[rtmp] createStream\n";
			} elsif ($method eq 'play') {
				$s->play($option);
				warn "[rtmp] play $option\n";
			} elsif ($method eq 'seek') {
				$s->seek($option);
				warn "[rtmp] seek $option\n";
			} elsif ($method eq 'pause') {
				$s->pause($option);
				warn "[rtmp] pause $option\n";
			} elsif ($method eq 'closeStream') {
				warn "[rtmp] closeStream\n";
			} elsif ($method eq 'deleteStream') {
				warn "[rtmp] deleteStream\n";
			} else {
				warn "[NOTICE] no support method: $method\n";
			}
		}

		$s->{buffer}->slide();
	}
}

sub play {
	my($s, $file) = @_;

	my $path = $s->{dir} . '/' . $file;

	if (!-f $path) {
		warn "[ERROR] file not found: $path\n";
	}

	$s->{file} = TS->new($s);
	$s->{file}->open($path);

	$s->{serializer}->setChankSize(RTMP::Serializer::PLAY_CHANK_SIZE);
	$s->{serializer}->setChankMarker(RTMP::Serializer::PLAY_CHANK_MARKER);

	$s->{method}->setChankSize();
	$s->{method}->commandAAA();
	$s->{method}->commandBBB();
	$s->{method}->playStart(0);
}

sub seek {
	my($s, $time) = @_;

	$time = $s->{file}->seek($time);

	$s->{serializer}->setChankSize(RTMP::Serializer::PLAY_CHANK_SIZE);
	$s->{serializer}->setChankMarker(RTMP::Serializer::PLAY_CHANK_MARKER);

	$s->{method}->commandCCC();
	$s->{method}->setChankSize();
	$s->{method}->commandAAA();
	$s->{method}->commandBBB();
	$s->{method}->seekNotify($time);
	$s->{method}->playStart(1);
}

sub pause {
	my($s, $flag) = @_;

	if ($flag) {
		$s->{file}->pause($flag);

		$s->{method}->commandCCC();
		$s->{method}->pauseNotify(1);
	} else {
		$s->{serializer}->setChankSize(RTMP::Serializer::PLAY_CHANK_SIZE);
		$s->{serializer}->setChankMarker(RTMP::Serializer::PLAY_CHANK_MARKER);

		$s->{method}->setChankSize();
		$s->{method}->commandAAA();
		$s->{method}->commandBBB();

		$s->{file}->pause($flag);
	}
}

sub complete {
	my($s) = @_;

	$s->{method}->commandCCC();
	$s->{method}->playStop(1);
}

sub execute {
	my($s) = @_;

	if ($s->{file}) {
		$s->{file}->execute();
	}
}

sub close {
	my($s) = @_;

	if ($s->{file}) {
		$s->{file}->close();
	}

	delete $s->{file};
}

sub send {
	my($s, $buf) = @_;
	my $sock = $s->{sock};

	if ($sock->connected) {
		print $sock $buf;
		$sock->flush();
	}
}

sub checkReceive {
	my($s) = @_;
	my $fileno = fileno($s->{sock});
	my $rin = pack('C', 1 << $fileno);
	return select($rin, undef, undef, 0);
}

1;
