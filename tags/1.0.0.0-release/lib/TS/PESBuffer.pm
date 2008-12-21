package TS::PESBuffer;

use strict;
use TS::PES;

sub new {
	my($pkg) = @_;

	my $hash = {
		pess => {},
	};

	my $s = bless $hash, $pkg;

	return $s;
}

sub reset {
	my($s) = @_;
	$s->{pess} = {};
}

sub getPES {
	my($s, $key) = @_;

	if (!defined $s->{pess}->{$key}) {
		$s->{pess}->{$key} = TS::PES->new();
	}

	return $s->{pess}->{$key};
}

sub exists {
	my($s, $key) = @_;

	if (defined $s->{pess}->{$key}) {
		return 1;
	}

	return 0;
}

1;
