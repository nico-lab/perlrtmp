package TS::AAC;

use strict;
use Scalar::Util qw(weaken);

use constant AAC_START_CODE => 0xFFF0;
use constant AAC_START_CODE_MASK => 0xFFF6;
use constant AAC_HEADER_LENGTH => 7;
use constant AAC_PROFILE_MAIN => 0;
use constant AAC_PROFILE_LC => 1;
use constant AAC_PROFILE_SSR => 2;

sub new {
	my($pkg, $buffer) = @_;

	my $hash = {
		buffer => $buffer,
		frames => [],
	};

	my $s = bless $hash, $pkg;

	weaken($s->{buffer});
	$s->parse();

	return $s;
}

sub parse {
	my($s) = @_;

	while($s->{buffer}->{pos} < $s->{buffer}->{length}) {

		my $buffer = $s->{buffer}->clone();

		my $find = $s->find_start_code($buffer);

		if ($find == -1) {
			last;
		}

		$buffer->getInt();

		my $a = $buffer->getInt();
		my $protection_absent = $a & 0x01;

		my $a = $buffer->getInt();
		my $b = $buffer->getInt();
		my $c = $buffer->getInt();
		my $d = $buffer->getInt();
		my $profile = $a >> 6 & 0x03;
		my $sampling_frequency_index = $a >> 2 & 0x0F;
		my $channel_configuration = ($a & 0x01) << 2 | $b >> 6 & 0x03;
		my $length = ($b & 0x03) << 11 | $c << 3 | $d >> 5;

		$buffer->getInt();
		$length -= AAC_HEADER_LENGTH;

		if ($protection_absent == 0) {
			$buffer->getInt();
			$length--;
			$buffer->getInt();
			$length--;
		}

		if ($buffer->bytes_remain() < $length) {
			last;
		}

		my $buf = $buffer->getBytes($length);

		my $frame = {
			profile => $profile,
			frequency => $sampling_frequency_index,
			channel => $channel_configuration,
			buf => $buf,
		};

		push(@{$s->{frames}}, $frame);

		$s->{buffer}->{pos} = $buffer->{pos};
	}
}

sub find_start_code {
	my($s, $buffer) = @_;

	while($buffer->{pos} + AAC_HEADER_LENGTH < $buffer->{length}) {
		my $start_code = unpack('n', substr($buffer->{buf}, $buffer->{pos}, 2));

		if (($start_code & AAC_START_CODE_MASK) == AAC_START_CODE) {
			return $buffer->{pos};
		}

		$buffer->{pos}++;
	}

	return -1;
}

1;
