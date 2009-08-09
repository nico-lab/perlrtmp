package RTMP::Serializer;

use strict;
use Scalar::Util qw(weaken);
use RTMP::Packet;
use RTMP::FrameBuffer;

use constant DEFAULT_CHANK_SIZE => 128;
use constant DEFAULT_CHANK_MARKER => 0xC3;
use constant PLAY_CHANK_SIZE => 4096;
use constant PLAY_CHANK_MARKER => 0xC5;

sub new {
	my($pkg, $rtmp) = @_;

	my $hash = {
		rtmp => $rtmp,
		chank_size => DEFAULT_CHANK_SIZE,
		chank_marker => DEFAULT_CHANK_MARKER,
	};

	my $s = bless $hash, $pkg;

	$s->{frame_buffer} = RTMP::FrameBuffer->new();
	weaken($s->{rtmp});

	return $s;
}

sub setChankSize {
	my($s, $size) = @_;
	$s->{chank_size} = $size;
}

sub setChankMarker {
	my($s, $marker) = @_;
	$s->{chank_marker} = $marker;
}

sub send {
	my($s, $packet) = @_;
	$s->{rtmp}->send($s->serialize($packet));
}

sub serialize {
	my($s, $packet) = @_;

	my $buffer = Binary->new($packet->{data});

	my $put = Binary->new();
	$put->setInt($packet->{frame});
	my $packet_type = $packet->{frame} >> 6;
	my $frame_number = $packet->{frame} & 0x3F;

	if ($frame_number == 0) {
		$put->setInt($frame_number);
	} elsif ($frame_number == 1) {
		$put->setShort($frame_number);
	}

	my $timer = $packet->{timer};

	if (0xFFFFFF <= $packet->{timer}) {
		$timer = 0xFFFFFF;
	}

	if ($packet_type == 0) {
		$put->setMedium($timer);
		$put->setMedium($buffer->{length});
		$put->setInt($packet->{data_type});
		$put->setLong($packet->{obj});
	} elsif ($packet_type == 1) {
		$put->setMedium($timer);
		$put->setMedium($buffer->{length});
		$put->setInt($packet->{data_type});
	} elsif ($packet_type == 2) {
		$put->setMedium($timer);
	}

	if (0xFFFFFF <= $packet->{timer}) {
		$put->setLong($packet->{timer});
	}

	my $len = $buffer->{length};

	while($len > 0) {
		my $r = $s->min($len, $s->{chank_size});

		$put->setBytes($buffer->getBytes($r));
		$len -= $r;

		if ($len > 0) {
			$put->setInt($s->{chank_marker});
		}
	}

	return $put->{buf};
}

sub receive {
	my($s) = @_;
	return $s->deserialize();
}

sub deserialize {
	my($s) = @_;

	my $first_number = $s->{rtmp}->{buffer}->getInt();
	my $packet_type = $first_number >> 6;
	my $frame_number = $first_number & 0x3F;

	if ($frame_number == 0) {
		$frame_number = $s->{rtmp}->{buffer}->getInt();
	} elsif ($frame_number == 1) {
		$frame_number = $s->{rtmp}->{buffer}->getShort();
	}

	if (!$s->{frame_buffer}->exists($frame_number)) {
		if ($packet_type != 0) {
			warn "[ERROR] rtmp packet error\n";
		}
	}

	my $frame = $s->{frame_buffer}->getFrame($frame_number);

	if ($packet_type == 0) {
		$frame->{timer} = $s->{rtmp}->{buffer}->getMedium();
		$frame->{size} = $s->{rtmp}->{buffer}->getMedium();
		$frame->{data_type} = $s->{rtmp}->{buffer}->getInt();
		$frame->{obj} = $s->{rtmp}->{buffer}->getLong();
	} elsif ($packet_type == 1) {
		$frame->{timer} = $s->{rtmp}->{buffer}->getMedium();
		$frame->{size} = $s->{rtmp}->{buffer}->getMedium();
		$frame->{data_type} = $s->{rtmp}->{buffer}->getInt();
	} elsif ($packet_type == 2) {
		$frame->{timer} = $s->{rtmp}->{buffer}->getMedium();
	}

	my $put = Binary->new();
	my $len = $frame->{size};

	while($len > 0) {
		my $r = $s->min($len, $s->{chank_size});

		$put->setBytes($s->{rtmp}->{buffer}->getBytes($r));
		$len -= $r;

		if ($len > 0) {
			$s->{rtmp}->{buffer}->getBytes(1);
		}
	}

	return RTMP::Packet->new($frame_number,$frame->{timer},$put->{buf},$frame->{data_type},$frame->{obj});
}

sub min {
	my($s, $a, $b) = @_;
	return $a if ($a < $b);
	return $b;
}

1;
