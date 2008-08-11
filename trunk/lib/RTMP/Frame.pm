package RTMP::Frame;

use strict;

sub new {
	my($pkg) = @_;

	my $hash = {
		timer => 0,
		size => 0,
		data_type => 0,
		obj => 0,
	};

	my $s = bless $hash, $pkg;

	return $s;
}

1;
