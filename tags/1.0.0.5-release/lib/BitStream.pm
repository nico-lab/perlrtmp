package BitStream;

use strict;

sub new {
	my($pkg, $buf, $pos, $bit) = @_;

	my $hash = {
		pos => $pos || 0,
		bit => $bit || 0,
		buf => '',
		length => 0,
	};

	my $s = bless $hash, $pkg;

	$s->append($buf);

	return $s;
}

sub append {
	my($s, $buf) = @_;
	$s->{buf} .= $buf;
	$s->{length} = length($s->{buf});
}

sub bits_remain {
	my($s) = @_;
	return (($s->{length} - $s->{pos}) * 8) - $s->{bit};
}

sub peekBits {
	my($s, $length, $update) = @_;

	my $pos = $s->{pos};
	my $bit = $s->{bit};
	my $ret = 0;

	while(0 < $length) {
		my $a = vec($s->{buf}, $pos, 8);
		my $remain = 8 - $bit;

		if ($length <= $remain) {
			my $over = $remain - $length;
			$ret |= ($a & (0xff >> $bit)) >> $over;

			$bit += $length;
			$length = 0;

			if (8 <= $bit) {
				$bit = 0;
				$pos++;
			}
		} else {
			my $under = $length - $remain;
			$ret |= ($a & (0xff >> $bit)) << $under;

			$bit = 0;
			$pos++;
			$length -= $remain;
		}
	}

	if ($update) {
		$s->{pos} = $pos;
		$s->{bit} = $bit;
	}

	return $ret;
}

sub getBits {
	my($s, $length) = @_;
	return $s->peekBits($length, 1);
}

1;
