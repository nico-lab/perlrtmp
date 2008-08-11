package RTMP::FrameBuffer;

use strict;
use RTMP::Frame;

sub new {
	my($pkg) = @_;

	my $hash = {
		frames => {},
	};

	my $s = bless $hash, $pkg;

	return $s;
}

sub getFrame {
	my($s, $key) = @_;

	if (!defined $s->{frames}->{$key}) {
		$s->{frames}->{$key} = RTMP::Frame->new();
	}

	return $s->{frames}->{$key};
}

sub exists {
	my($s, $key) = @_;

	if (defined $s->{frames}->{$key}) {
		return 1;
	}

	return 0;
}

1;
