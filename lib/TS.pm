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

use constant BUFFER_LENGTH => 10;

sub new {
	my($pkg, $rtmp) = @_;

	my $s = $pkg->SUPER::new();

	$s->{rtmp} = $rtmp;
	$s->{writer} = TS::Writer->new($s);
	$s->{header} = TS::Header->new($s);
	$s->{duration} = 0;
	$s->reset();
	weaken($s->{rtmp});

	return $s;
}

sub reset {
	my($s) = @_;
	$s->{start_pts} = undef;
	$s->{send_pts} = undef;
	$s->{send_time} = undef;
	$s->{pes_buffer}->reset();
	$s->{frames} = [];
}

sub open {
	my($s, $file) = @_;
	sysopen($s->{handle}, $file, O_RDONLY | O_LARGEFILE);
	$s->{duration} = $s->{header}->duration();
}

sub seek {
	my($s, $time) = @_;

	$s->reset();
	$s->{writer}->reset(1);

	my $end = sysseek($s->{handle}, 0, SEEK_END);
	my $seek = $end * (($time / 1000) / $s->{duration});
	sysseek($s->{handle}, $seek, SEEK_SET);

	my $current = $s->{header}->current();

	return $current * 1000;
}

sub execute {
	my($s) = @_;
	$s->parse();
}

sub video {
	my($s, $ts, $b) = @_;

	$b->{buffering} = 1;
	my $pes = $s->parsePES($ts);

	if (defined $b->{pts}) {
		my $p = TS::H264->new($b->{buf});
		$b->{buf} = substr($b->{buf}, $p->{pos});
		$s->parsePayload($ts, $b, $pes, $p);
	}

	$b->{pts} = $pes->{pts};
	$s->sendFrame();
}

sub audio {
	my($s, $ts, $b) = @_;

	$b->{buffering} = 1;
	my $pes = $s->parsePES($ts);

	if (defined $b->{pts}) {
		my $p = TS::AAC->new($b->{buf});
		$b->{buf} = substr($b->{buf}, $p->{pos});
		$s->parsePayload($ts, $b, $pes, $p);
	}

	$b->{pts} = $pes->{pts};
	$s->sendFrame();
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

	@{$s->{frames}} = sort {TS::PTS::compare($a->{pts}, $b->{pts})} @{$s->{frames}};

	while (0 < @{$s->{frames}}) {
		if (TS::PTS::lessThan($send_pts, $s->{frames}->[0]->{pts})) {
			last;
		}

		my $frame = shift @{$s->{frames}};
		$s->{writer}->send($frame);
	}

	if (!defined $s->{send_pts}) {
		$s->{send_pts} = $send_pts;
	}

	if (!defined $s->{send_time}) {
		$s->{send_time} = time - BUFFER_LENGTH;
	}

	my $sent_time = time - $s->{send_time};
	my $sent_pts = TS::PTS::length($send_pts, $s->{send_pts}) / 90000;

	if ($sent_time <= $sent_pts) {
		$s->{send_pts} = $send_pts;
		$s->{send_time} = time;
		$s->{break} = 1;
	}
}

1;
