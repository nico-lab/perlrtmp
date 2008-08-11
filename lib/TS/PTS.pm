package TS::PTS;

use strict;

use constant PTS_MAX => 2 ** 33;
use constant PTS_CONTINUITY => 60 * 60 * 25 * 90000;

sub plus {
	my($a, $b) = @_;

	my $c = $a + $b;

	if (PTS_MAX <= $c) {
		$c -= PTS_MAX;
	}

	return $c;
}

sub minus {
	my($a, $b) = @_;

	my $c = $a - $b;

	if ($c < 0) {
		$c += PTS_MAX;
	}

	return $c;
}

sub length {
	my($a, $b) = @_;

	my $c = $a - $b;

	if ($a < $b) {
		$c = PTS_MAX - $b + $a;
	}

	return $c;
}

sub continuity {
	my($a, $b) = @_;
	return PTS_CONTINUITY < abs($a - $b);
}

sub min {
	my($a, $b) = @_;

	if ($a < $b) {
		return &continuity($a, $b) ? $b : $a;
	}

	return &continuity($a, $b) ? $a : $b;
}

sub max {
	my($a, $b) = @_;

	if ($a < $b) {
		return &continuity($a, $b) ? $a : $b;
	}

	return &continuity($a, $b) ? $b : $a;
}

# <=
sub lessOrEqual {
	my($a, $b) = @_;

	if ($a <= $b) {
		return &continuity($a, $b) ? 0 : 1;
	}

	return &continuity($a, $b) ? 1 : 0;
}

# <
sub lessThan {
	my($a, $b) = @_;

	if ($a < $b) {
		return &continuity($a, $b) ? 0 : 1;
	}

	return &continuity($a, $b) ? 1 : 0;
}

# <=>
sub compare {
	my($a, $b) = @_;

	if ($a < $b) {
		return &continuity($a, $b) ? 1 : -1;
	} elsif ($a > $b) {
		return &continuity($a, $b) ? -1 : 1;
	}

	return 0;
}

1;
