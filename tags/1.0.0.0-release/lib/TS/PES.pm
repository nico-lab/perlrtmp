package TS::PES;

use strict;

sub new {
	my($pkg) = @_;

	my $hash = {
		pts => undef,
		start => 0,
		buffering => 0,
		buf => '',
	};

	my $s = bless $hash, $pkg;

	return $s;
}

1;
