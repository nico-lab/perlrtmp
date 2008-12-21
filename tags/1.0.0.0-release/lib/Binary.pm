package Binary;

use strict;

sub new {
	my($pkg, $buf, $pos) = @_;

	my $hash = {
		pos => $pos || 0,
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

sub getBytes {
	my($s, $length) = @_;
	my $data = substr($s->{buf}, $s->{pos}, $length);
	$s->{pos} += $length;
	return $data;
}

sub getInt {
	my($s) = @_;
	return vec($s->{buf}, $s->{pos}++, 8);
}

sub getShort {
	my($s) = @_;
	my $a = $s->getInt();
	my $b = $s->getInt();
	return $a << 8 | $b;
}

sub getMedium {
	my($s) = @_;
	my $a = $s->getInt();
	my $b = $s->getInt();
	my $c = $s->getInt();
	return $a << 16 | $b << 8 | $c;
}

sub getLong {
	my($s) = @_;
	my $a = $s->getInt();
	my $b = $s->getInt();
	my $c = $s->getInt();
	my $d = $s->getInt();
	return $a << 24 | $b << 16 | $c << 8 | $d;
}

sub setBytes {
	my($s, $data) = @_;
	$s->{buf} .= $data;
	$s->{pos} += length($data);
}

sub setInt {
	my($s, $num) = @_;
	$s->setBytes(pack('C', $num));
}

sub setShort {
	my($s, $num) = @_;
	$s->setBytes(pack('n', $num));
}

sub setMedium {
	my($s, $num) = @_;
	$s->setBytes(substr(pack('N', $num), 1));
}

sub setLong {
	my($s, $num) = @_;
	$s->setBytes(pack('N', $num));
}

sub slide {
	my($s) = @_;

	$s->{buf} = substr($s->{buf}, $s->{pos});
	$s->{length} = length($s->{buf});
	$s->{pos} = 0;
}

sub clone {
	my($s) = @_;

	return Binary->new($s->{buf}, $s->{pos});
}

1;
