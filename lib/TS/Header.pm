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
	$s->{_first_pts} = undef;
	$s->{_last_pts} = undef;
	$s->{_pts} = undef;
	$s->{_first} = 0;
	weaken($s->{ts});

	return $s;
}

sub duration {
	my($s) = @_;
	$s->{handle} = $s->{ts}->{handle};

	$s->parse();
	$s->{ts}->{video_pid} = $s->{video_pid};
	$s->{ts}->{audio_pid} = $s->{audio_pid};

	sysseek($s->{handle}, 0, SEEK_SET);
	$s->{_first_pts} = $s->pts(1);

	sysseek($s->{handle}, SCAN_FILE_END, SEEK_END);
	$s->{_last_pts} = $s->pts(0);

	sysseek($s->{handle}, 0, SEEK_SET);

	my $pts_length = TS::PTS::length($s->{_last_pts}, $s->{_first_pts});
	return $pts_length / 90000;
}

sub current {
	my($s) = @_;
	$s->{handle} = $s->{ts}->{handle};

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
	my($s, $ts) = @_;
	$s->SUPER::pmt($ts);
	$s->{break} = 1;
}

sub video {
	my($s, $ts) = @_;

	my $pes = $s->parsePES($ts);

	if ($pes->{packet_start_code_prefix} == TS::File::PES_START_CODE) {
		$s->{_pts} = $pes->{pts};

		if ($s->{_first}) {
			$s->{break} = 1;
		}
	}
}

1;
