package TS::AAC;

use strict;

use constant AAC_START_CODE => 0xFFF0;
use constant AAC_START_CODE_MASK => 0xFFF6;
use constant AAC_HEADER_LENGTH => 7;
use constant AAC_PROFILE_MAIN => 0;
use constant AAC_PROFILE_LC => 1;
use constant AAC_PROFILE_SSR => 2;

sub new {
	my($pkg, $buf) = @_;

	my $hash = {
		buf => $buf,
		pos => 0,
		frames => [],
	};

	my $s = bless $hash, $pkg;

	$s->parse();

	return $s;
}

sub parse {
	my($s) = @_;

	my $last_pos = length($s->{buf});

	while($s->{pos} < $last_pos) {

		my $find = $s->find_start_code($s->{pos});

		if (!defined $find) {
			last;
		}

		$find++;

		my $a = vec($s->{buf}, $find++, 8);
		my $protection_absent = $a & 0x01;

		my $a = vec($s->{buf}, $find++, 8);
		my $b = vec($s->{buf}, $find++, 8);
		my $c = vec($s->{buf}, $find++, 8);
		my $d = vec($s->{buf}, $find++, 8);
		my $profile = $a >> 6 & 0x03;
		my $sampling_frequency_index = $a >> 2 & 0x0F;
		my $channel_configuration = ($a & 0x01) << 2 | $b >> 6 & 0x03;
		my $length = ($b & 0x03) << 11 | $c << 3 | $d >> 5;

		$find++;
		$length -= AAC_HEADER_LENGTH;

		if ($protection_absent == 0) {
			$find++;
			$length--;
			$find++;
			$length--;
		}

		if ($last_pos < $find + $length) {
			last;
		}

		my $buf = substr($s->{buf}, $find, $length);

		my $frame = {
			profile => $profile,
			frequency => $sampling_frequency_index,
			channel => $channel_configuration,
			buf => $buf,
		};

		push(@{$s->{frames}}, $frame);

		$s->{pos} = $find + $length;
	}
}

sub find_start_code {
	my($s, $pos) = @_;

	my $last_pos = length($s->{buf});

	while($pos + AAC_HEADER_LENGTH < $last_pos) {
		my $start_code = unpack('n', substr($s->{buf}, $pos, 2));

		if (($start_code & AAC_START_CODE_MASK) == AAC_START_CODE) {
			return $pos;
		}

		$pos++;
	}

	return undef;
}

1;
