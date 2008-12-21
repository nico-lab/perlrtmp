package RTMP::Method;

use strict;
use Scalar::Util qw(weaken);
use RTMP::Packet;
use RTMP::AMF;

sub new {
	my($pkg, $rtmp) = @_;

	my $hash = {
		rtmp => $rtmp,
	};

	my $s = bless $hash, $pkg;

	weaken($s->{rtmp});

	return $s;
}

sub serverBandwidth {
	my($s) = @_;

	my $frame = 2;
	my $timer = 0;
	my $data_type = 5;
	my $obj = 0;
	my $data = pack('C*', 0x00,0x26,0x25,0xa0);
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub clientBandwidth {
	my($s) = @_;

	my $frame = 2;
	my $timer = 0;
	my $data_type = 6;
	my $obj = 0;
	my $data = pack('C*', 0x00,0x26,0x25,0xa0,0x02);
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub connect {
	my($s) = @_;

	my $args = [
		{
			key => 'capabilities',
			value => {
				type => RTMP::AMF::AMF_NUMBER,
				data => 31.0,
			},
		},
		{
			key => 'fmsVer',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'perlRTMP/1,0,0,7',
			},
		},
	];

	my $option = [
		{
			key => 'code',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'NetConnection.Connect.Success',
			},
		},
		{
			key => 'level',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'status',
			},
		},
		{
			key => 'description',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'Connection succeeded.',
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => '_result',
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 1,
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $args,
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $option,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = 3;
	my $timer = 0;
	my $data_type = 20;
	my $obj = 0;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub createStream {
	my($s) = @_;

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => '_result',
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 2,
		},
		{
			type => RTMP::AMF::AMF_NIL,
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 1.0,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = 3;
	my $timer = 0;
	my $data_type = 20;
	my $obj = 0;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub setChankSize {
	my($s) = @_;

	my $frame = 2;
	my $timer = 0;
	my $data_type = 1;
	my $obj = 0;
	my $data = pack('N', $s->{rtmp}->{serializer}->{chank_size});
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub commandAAA {
	my($s) = @_;

	my $frame = 2;
	my $timer = 0;
	my $data_type = 4;
	my $obj = 0;
	my $data = pack('C*', 0,4,0,0,0,1);
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub commandBBB {
	my($s) = @_;

	my $frame = 2;
	my $timer = 0;
	my $data_type = 4;
	my $obj = 0;
	my $data = pack('C*', 0,0,0,0,0,1);
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub commandCCC {
	my($s) = @_;

	my $frame = 2;
	my $timer = 0;
	my $data_type = 4;
	my $obj = 0;
	my $data = pack('C*', 0,1,0,0,0,1);
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub playStart {
	my($s, $type) = @_;

	my $option = [
		{
			key => 'code',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'NetStream.Play.Start',
			},
		},
		{
			key => 'level',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'status',
			},
		},
		{
			key => 'description',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => '-',
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => 'onStatus',
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 0,
		},
		{
			type => RTMP::AMF::AMF_NIL,
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $option,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = $type << 6 | 5;
	my $timer = 0;
	my $data_type = 20;
	my $obj = 0x01000000;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub seekNotify {
	my($s, $time) = @_;

	my $option = [
		{
			key => 'code',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'NetStream.Seek.Notify',
			},
		},
		{
			key => 'level',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'status',
			},
		},
		{
			key => 'description',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => '-',
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => 'onStatus',
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 0,
		},
		{
			type => RTMP::AMF::AMF_NIL,
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $option,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = 5;
	my $data_type = 20;
	my $obj = 0x01000000;
	my $packet = RTMP::Packet->new($frame,$time,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub pauseNotify {
	my($s, $type) = @_;

	my $option = [
		{
			key => 'code',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'NetStream.Pause.Notify',
			},
		},
		{
			key => 'level',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'status',
			},
		},
		{
			key => 'description',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => '-',
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => 'onStatus',
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 0,
		},
		{
			type => RTMP::AMF::AMF_NIL,
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $option,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = $type << 6 | 5;
	my $timer = 0;
	my $data_type = 20;
	my $obj = 0x01000000;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

sub playStop {
	my($s, $type) = @_;

	my $option = [
		{
			key => 'code',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'NetStream.Play.Stop',
			},
		},
		{
			key => 'level',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'status',
			},
		},
		{
			key => 'description',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => '-',
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => 'onStatus',
		},
		{
			type => RTMP::AMF::AMF_NUMBER,
			data => 0,
		},
		{
			type => RTMP::AMF::AMF_NIL,
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $option,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = $type << 6 | 5;
	my $timer = 0;
	my $data_type = 20;
	my $obj = 0x01000000;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{rtmp}->{serializer}->send($packet);
}

1;
