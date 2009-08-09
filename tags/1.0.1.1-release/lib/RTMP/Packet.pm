package RTMP::Packet;

use strict;

sub new {
	my($pkg, $frame, $timer, $data, $data_type, $obj) = @_;

	my $hash = {
		frame => $frame,
		timer => $timer,
		data => $data,
		data_type => $data_type,
		obj => $obj,
	};

	my $s = bless $hash, $pkg;

	return $s;
}

1;
