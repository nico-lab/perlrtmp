package TS;

use strict;
use Scalar::Util qw(weaken);
use base qw(TS::File);
use Fcntl;
use IO::Seekable;
use TS::Header;
use TS::Writer;
use TS::H264;
use TS::AAC;
use TS::PTS;
use TS::PESBuffer;

use constant BUFFER_LENGTH => 10;

sub new {
	my($pkg, $rtmp) = @_;

	my $s = $pkg->SUPER::new();

	$s->{rtmp} = $rtmp;
	$s->{writer} = TS::Writer->new($s);
	$s->{header} = TS::Header->new($s);
	$s->{pes_buffer} = TS::PESBuffer->new();
	$s->{duration} = 0;
	$s->{bytes} = 0;
	$s->{pause} = 0;
	$s->reset();
	weaken($s->{rtmp});

	return $s;
}

sub reset {
	my($s) = @_;
	$s->{play} = 1;
	$s->{start_pts} = undef;
	$s->{start_time} = undef;
	$s->{pes_buffer}->reset();
	$s->{frames} = [];
}

sub open {
	my($s, $file) = @_;
	$s->SUPER::open($file);
	$s->{bytes} = $s->{header}->bytes();
	$s->{duration} = $s->{header}->duration();
}

sub seek {
	my($s, $time) = @_;

	$s->reset();
	$s->{writer}->reset(1);

	if (0 < $s->{duration}) {
		my $seek = $s->{bytes} * ($time / 1000 / $s->{duration});
		sysseek($s->{handle}, $seek, SEEK_SET);
	}

	my $current = $s->{header}->current();

	return $current * 1000;
}

sub pause {
	my($s, $flag) = @_;
	$s->{pause} = $flag;

	if (!$flag) {
		$s->{start_pts} = $s->{frames}->[0]->{pts};
		$s->{start_time} = time() + BUFFER_LENGTH;
	}
}

sub complete {
	my($s) = @_;
	$s->{play} = 0;
	$s->{writer}->playStatus();
	$s->{rtmp}->complete();
}

sub execute {
	my($s) = @_;

	if ($s->{play} && !$s->{pause}) {
		$s->parse();
	}
}

sub video {
	my($s, $ts, $buffer) = @_;

	my $b = $s->{pes_buffer}->getPES($ts->{pid});

	$b->{buffering} = 1;
	my $pes = $s->parsePES($buffer);

	if ($pes->{packet_start_code_prefix} == TS::File::PES_START_CODE) {
		if (defined $b->{pts}) {
			my $p = TS::H264->new($b->{buffer});
			$b->{buffer}->slide();
			$s->parsePayload($ts, $b, $pes, $p);
		}

		$b->{pts} = $pes->{pts};
		$s->sendFrame();
	}
}

sub audio {
	my($s, $ts, $buffer) = @_;

	my $b = $s->{pes_buffer}->getPES($ts->{pid});

	$b->{buffering} = 1;
	my $pes = $s->parsePES($buffer);

	if ($pes->{packet_start_code_prefix} == TS::File::PES_START_CODE) {
		if (defined $b->{pts}) {
			my $p = TS::AAC->new($b->{buffer});
			$b->{buffer}->slide();
			$s->parsePayload($ts, $b, $pes, $p);
		}

		$b->{pts} = $pes->{pts};
		$s->sendFrame();
	}
}

sub payload {
	my($s, $ts, $buffer) = @_;

	my $b = $s->{pes_buffer}->getPES($ts->{pid});

	if ($b->{buffering}) {
		$b->{buffer}->append($buffer->getBytes($buffer->bytes_remain()));
	}

	if ($s->{rtmp}->checkReceive()) {
		$s->{break} = 1;
	}
}

sub parsePayload {
	my($s, $ts, $b, $pes, $p) = @_;

	my $pts_length = TS::PTS::length($pes->{pts}, $b->{pts});

	my $frames = @{$p->{frames}};
	my $pts = $b->{pts};

	for (my $i = 0; $i < $frames; $i++) {
		my $frame = {
			pid => $ts->{pid},
			pts => $pts,
			frame => $p->{frames}->[$i],
		};

		if (!defined $s->{start_pts} && $p->{frames}->[$i]->{keyframe}) {
			$s->{start_pts} = $pts;
			$s->{start_time} = time();
		}

		if (defined $s->{start_pts} && TS::PTS::lessOrEqual($s->{start_pts}, $pts)) {
			$b->{start} = 1;
		}

		if ($b->{start}) {
			push(@{$s->{frames}}, $frame);
		}

		$pts = TS::PTS::plus($pts, $pts_length / $frames);
	}
}

sub sendFrame {
	my($s) = @_;

	my $video = $s->{pes_buffer}->getPES($s->{video_pid});
	my $audio = $s->{pes_buffer}->getPES($s->{audio_pid});

	if (!defined $video->{pts} || !defined $audio->{pts}) {
		return;
	}

	my $send_pts = TS::PTS::min($video->{pts}, $audio->{pts});

	my $sent_time = time() - $s->{start_time} + BUFFER_LENGTH;
	my $sent_pts = TS::PTS::plus($s->{start_pts}, $sent_time * 90000);

	@{$s->{frames}} = sort {TS::PTS::compare($a->{pts}, $b->{pts})} @{$s->{frames}};

	while (0 < @{$s->{frames}}) {
		if (TS::PTS::lessThan($send_pts, $s->{frames}->[0]->{pts})) {
			last;
		}

		if (TS::PTS::lessThan($sent_pts, $s->{frames}->[0]->{pts})) {
			$s->{break} = 1;
			last;
		}

		if ($s->{rtmp}->checkReceive()) {
			$s->{break} = 1;
			last;
		}

		my $frame = shift @{$s->{frames}};
		$s->{writer}->send($frame);
	}
}

1;
