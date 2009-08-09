package MP4::H264;

use strict;
use Binary;

use constant H264_NAL_TYPE_NON_IDR_SLICE => 0x01;
use constant H264_NAL_TYPE_IDR_SLICE => 0x05;
use constant H264_NAL_TYPE_SEI => 0x06;

sub new {
	my($pkg, $buf) = @_;

	my $hash = {
		buffer => undef,
		put => undef,
	};

	my $s = bless $hash, $pkg;

	$s->{buffer} = Binary->new($buf);
	$s->{put} = Binary->new();
	$s->parse();

	return $s;
}

sub parse {
	my($s) = @_;

	while($s->{buffer}->{pos} < $s->{buffer}->{length}) {
		my $length = $s->{buffer}->getLong();
		my $buf = $s->{buffer}->getBytes($length);

		my $a = vec($buf, 0, 8);
		my $nal_unit_type = $a & 0x1F;

		if ($nal_unit_type == H264_NAL_TYPE_SEI || 
			$nal_unit_type == H264_NAL_TYPE_NON_IDR_SLICE || 
			$nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {

			$s->{put}->setLong($length);
			$s->{put}->setBytes($buf);
		}
	}
}

1;
