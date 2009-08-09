package TS::Header;

use strict;
use Scalar::Util qw(weaken);
use base qw(TS::File);
use IO::Seekable;
use TS::PTS;

use constant SCAN_FILE_END => -1000000;

sub new {
	my($pkg, $ts) = @_;

	my $s = $pkg->SUPER::new();

	$s->{ts} = $ts;
	$s->{bytes} = 0;
	$s->{duration} = 0;
	$s->{_first_pts} = undef;
	$s->{_last_pts} = undef;
	$s->{_pts} = undef;
	$s->{_first} = 0;
	weaken($s->{ts});

	return $s;
}

sub execute {
	my($s) = @_;

	$s->parse();
	$s->{ts}->{video_pid} = $s->{video_pid};
	$s->{ts}->{audio_pid} = $s->{audio_pid};

	$s->{ts}->fileSeek(0, SEEK_SET);
	$s->{_first_pts} = $s->pts(1);

	$s->{ts}->fileSeek(SCAN_FILE_END, SEEK_END);
	$s->{_last_pts} = $s->pts(0);

	my $pts_length = TS::PTS::length($s->{_last_pts}, $s->{_first_pts});
	$s->{duration} = $pts_length / 90000;

	$s->{ts}->fileSeek(0, SEEK_END);
	$s->{bytes} = $s->{ts}->fileTell();

	$s->{ts}->fileSeek(0, SEEK_SET);
}

sub read {
	my($s) = @_;
	return $s->{ts}->fileRead($_[1], $_[2]);
}

sub seek {
	my($s, $time) = @_;

	if (0 < $s->{duration}) {
		my $seek = int($s->{bytes} * ($time / 1000 / $s->{duration}));
		$s->{ts}->fileSeek($seek, SEEK_SET);
	}

	return $s->current() * 1000;
}

sub current {
	my($s) = @_;

	my $current_pts = $s->pts(1);

	my $time = TS::PTS::minus($current_pts, $s->{_first_pts});
	return $time / 90000;
}

sub pts {
	my($s, $first) = @_;

	$s->{_first} = $first;
	$s->parse();
	return $s->{_pts};
}

sub pmt {
	my($s, $ts, $buffer) = @_;
	$s->SUPER::pmt($ts, $buffer);
	$s->{break} = 1;
}

sub video {
	my($s, $ts, $buffer) = @_;

	my $pes = $s->parsePES($buffer);

	if ($pes->{packet_start_code_prefix} == TS::File::PES_START_CODE) {
		$s->{_pts} = $pes->{pts};

		if ($s->{_first}) {
			$s->{break} = 1;
		}
	}
}

sub payload {
	my($s, $ts, $buffer) = @_;

	if ($s->{ts}->{rtmp}->checkReceive()) {
		$s->{break} = 1;
	}
}

1;
