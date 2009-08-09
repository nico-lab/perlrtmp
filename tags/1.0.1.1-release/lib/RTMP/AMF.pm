package RTMP::AMF;

use strict;

use constant AMF_NUMBER => 0;
use constant AMF_BOOLEAN => 1;
use constant AMF_STRING => 2;
use constant AMF_HASH => 3;
use constant AMF_NIL => 5;
use constant AMF_UNDEF => 6;
use constant AMF_ASSOC_ARRAY => 8;
use constant AMF_END => 9;
use constant AMF_LONG_STRING => 12;
use constant LITTLE_ENDIAN => pack('I', 1) =~ /^\x01/;

sub new {
	my($pkg, $buf) = @_;

	my $hash = {
		buffer => undef,
	};

	my $s = bless $hash, $pkg;

	$s->{buffer} = Binary->new($buf);

	return $s;
}

sub loadArray {
	my($buf) = @_;

	my $s = RTMP::AMF->new($buf);

	my @ary = ();

	while($s->{buffer}->{pos} < $s->{buffer}->{length}) {
		my $data = $s->load();
		push(@ary, $data);
	}

	return @ary;
}

sub load {
	my($s) = @_;

	my $type = $s->{buffer}->getInt();

	if ($type == AMF_NUMBER) {
		return $s->getNumber();
	} elsif ($type == AMF_BOOLEAN) {
		return $s->getBoolean();
	} elsif ($type == AMF_STRING) {
		return $s->getString();
	} elsif ($type == AMF_HASH) {
		return $s->getHash();
	} elsif ($type == AMF_NIL) {
		return '';
	} elsif ($type == AMF_UNDEF) {
		return '';
	} elsif ($type == AMF_ASSOC_ARRAY) {
		return $s->getAssocArray();
	} elsif ($type == AMF_END) {
		return undef;
	} else {
		warn "[NOTICE] no support amf type: $type\n";
	}
}

sub getNumber {
	my($s) = @_;

	my $bytes = $s->{buffer}->getBytes(8);

	if (LITTLE_ENDIAN) {
		my $buf = '';

		for (my $i = length($bytes) - 1; 0 <= $i; $i--) {
			$buf .= substr($bytes, $i, 1);
		}

		return unpack('d', $buf);
	}

	return unpack('d', $bytes);
}

sub getBoolean {
	my($s) = @_;

	if ($s->{buffer}->getInt()) {
		return 1;
	}

	return 0;
}

sub getString {
	my($s) = @_;

	my $length = $s->{buffer}->getShort();
	return $s->{buffer}->getBytes($length);
}

sub getHash {
	my($s) = @_;

	my $hash = {};

	while(1) {
		my $length = $s->{buffer}->getShort();
		my $key = $s->{buffer}->getBytes($length);
		my $val = $s->load();

		if (defined $val) {
			$hash->{$key} = $val;
		} else {
			last;
		}
	}

	return $hash;
}

sub getAssocArray {
	my($s) = @_;

	my $hash = {};

	$s->{buffer}->getLong();

	while(1) {
		my $length = $s->{buffer}->getShort();
		my $key = $s->{buffer}->getBytes($length);
		my $val = $s->load();

		if (defined $val) {
			$hash->{$key} = $val;
		} else {
			last;
		}
	}

	return $hash;
}

sub dumpArray {
	my(@ary) = @_;

	my $s = RTMP::AMF->new();

	foreach my $obj (@ary) {
		$s->dump($obj);
	}

	return $s->{buffer}->{buf};
}

sub dump {
	my($s, $obj) = @_;

	my $type = $obj->{type};
	my $data = $obj->{data};

	if ($type == AMF_NUMBER) {
		$s->setNumber($data);
	} elsif ($type == AMF_BOOLEAN) {
		$s->setBoolean($data);
	} elsif ($type == AMF_STRING) {
		$s->setString($data);
	} elsif ($type == AMF_HASH) {
		$s->setHash($data);
	} elsif ($type == AMF_NIL) {
		$s->{buffer}->setInt(AMF_NIL);
	} elsif ($type == AMF_UNDEF) {
		$s->{buffer}->setInt(AMF_UNDEF);
	} elsif ($type == AMF_ASSOC_ARRAY) {
		$s->setAssocArray($data);
	} elsif ($type == AMF_END) {
		$s->{buffer}->setInt(AMF_END);
	} else {
		warn "[NOTICE] no support amf type: $type\n";
	}
}

sub setNumber {
	my($s, $data) = @_;

	$s->{buffer}->setInt(AMF_NUMBER);
	my $bytes = pack('d', $data);

	if (LITTLE_ENDIAN) {
		for (my $i = length($bytes) - 1; 0 <= $i; $i--) {
			$s->{buffer}->setBytes(substr($bytes, $i, 1));
		}
	} else {
		$s->{buffer}->setBytes($bytes);
	}
}

sub setBoolean {
	my($s, $data) = @_;

	$s->{buffer}->setInt(AMF_BOOLEAN);

	if ($data) {
		$s->{buffer}->setInt(1);
	} else {
		$s->{buffer}->setInt(0);
	}
}

sub setString {
	my($s, $data) = @_;

	if (length($data) < 65535) {
		$s->{buffer}->setInt(AMF_STRING);
		$s->{buffer}->setShort(length($data));
		$s->{buffer}->setBytes($data);
	} else {
		$s->{buffer}->setInt(AMF_LONG_STRING);
		$s->{buffer}->setLong(length($data));
		$s->{buffer}->setBytes($data);
	}
}

sub setHash {
	my($s, $data) = @_;

	$s->{buffer}->setInt(AMF_HASH);

	foreach my $obj (@$data) {
		$s->{buffer}->setShort(length($obj->{key}));
		$s->{buffer}->setBytes($obj->{key});
		$s->dump($obj->{value});
	}

	$s->{buffer}->setShort(0);
	$s->{buffer}->setInt(AMF_END);
}

sub setAssocArray {
	my($s, $data) = @_;

	$s->{buffer}->setInt(AMF_ASSOC_ARRAY);

	my $count = @$data;
	$s->{buffer}->setLong($count);

	foreach my $obj (@$data) {
		$s->{buffer}->setShort(length($obj->{key}));
		$s->{buffer}->setBytes($obj->{key});
		$s->dump($obj->{value});
	}

	$s->{buffer}->setShort(0);
	$s->{buffer}->setInt(AMF_END);
}

1;
