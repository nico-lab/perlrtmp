package TS::PES;

use strict;

sub new {
	my($pkg) = @_;

	my $hash = {
		pts => undef,
		start => 0,
		buffering => 0,
		buffer => undef,
	};

	my $s = bless $hash, $pkg;

	$s->{buffer} = Binary->new();

	return $s;
}

1;
