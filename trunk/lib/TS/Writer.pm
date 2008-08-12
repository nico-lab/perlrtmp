package TS::Writer;

use strict;
use Scalar::Util qw(weaken);
use RTMP::Packet;
use TS::PTS;
use TS::H264;
use TS::AAC;

sub new {
	my($pkg, $ts) = @_;

	my $hash = {
		ts => $ts,
		pts => undef,
		video_first => 1,
		audio_first => 1,
		type => 0,
	};

	my $s = bless $hash, $pkg;

	weaken($s->{ts});

	return $s;
}

sub reset {
	my($s, $type) = @_;
	$s->{pts} = undef;
	$s->{video_first} = 1;
	$s->{audio_first} = 1;
	$s->{type} = $type;
}

sub send {
	my($s, $frame) = @_;

	if (!defined $s->{pts}) {
		$s->{pts} = $frame->{pts};
	}

	my $pts_length = TS::PTS::length($frame->{pts}, $s->{pts});
	my $duration = int($pts_length / 90);

	$s->{pts} = $frame->{pts};

	if ($frame->{pid} == $s->{ts}->{video_pid}) {

		if ($s->{video_first} && $frame->{frame}->{keyframe}) {
			my $seq = TS::H264::parseSequence($frame->{frame}->{seq_param});
			$s->metadata($seq);

			my $video_extra = pack('H*', '1700000000');
			$video_extra .= pack('H*', '0142e00cffe1');
			$video_extra .= pack('n', length($frame->{frame}->{seq_param}));
			$video_extra .= $frame->{frame}->{seq_param};
			$video_extra .= pack('H*', '01');
			$video_extra .= pack('n', length($frame->{frame}->{pic_param}));
			$video_extra .= $frame->{frame}->{pic_param};

			my $frame = $s->{type} << 6 | 5;
			my $timer = 0;
			my $data_type = 9;
			my $obj = 0x01000000;
			my $packet = RTMP::Packet->new($frame,$timer,$video_extra,$data_type,$obj);
			$s->{ts}->{rtmp}->{serializer}->send($packet);

			$s->{video_first} = 0;
		}

		my $video = $s->getVideoHeader($frame->{frame}->{keyframe});
		$video .= $frame->{frame}->{buf};

		my $frame = 0x45;
		my $data_type = 9;
		my $obj = 0;
		my $packet = RTMP::Packet->new($frame,$duration,$video,$data_type,$obj);
		$s->{ts}->{rtmp}->{serializer}->send($packet);
	}

	if ($frame->{pid} == $s->{ts}->{audio_pid}) {

		if ($s->{audio_first}) {
			my $profile = $s->getAudioProfile($frame);
			my $frequency = $frame->{frame}->{frequency};
			my $channel = $s->getAudioChannel($frame);
			my $decSpecificInfo = $profile << 11 | $frequency << 7 | $channel << 3;

			my $audio_extra = pack('H*', 'af00');
			$audio_extra .= pack('n', $decSpecificInfo);
			$audio_extra .= pack('H*', '06');

			my $frame = $s->{type} << 6 | 5;
			my $timer = 0;
			my $data_type = 8;
			my $obj = 0x01000000;
			my $packet = RTMP::Packet->new($frame,$timer,$audio_extra,$data_type,$obj);
			$s->{ts}->{rtmp}->{serializer}->send($packet);

			$s->{audio_first} = 0;
		}

		my $audio = $s->getAudioHeader();
		$audio .= $frame->{frame}->{buf};

		my $frame = 0x45;
		my $data_type = 8;
		my $obj = 0;
		my $packet = RTMP::Packet->new($frame,$duration,$audio,$data_type,$obj);
		$s->{ts}->{rtmp}->{serializer}->send($packet);
	}
}

sub getAudioProfile {
	my($s, $frame) = @_;

	my $profile = $frame->{frame}->{profile};

	if ($profile == TS::AAC::AAC_PROFILE_MAIN) {
		return 1;
	} elsif ($profile == TS::AAC::AAC_PROFILE_LC) {
		return 2;
	} elsif ($profile == TS::AAC::AAC_PROFILE_SSR) {
		return 3;
	}

	return 0;
}

sub getAudioChannel {
	my($s, $frame) = @_;

	my $channel = $frame->{frame}->{channel};

	if ($channel == 0) {
		return 2;
	}

	return $channel;
}

sub getVideoHeader {
	my($s, $keyframe) = @_;

	if ($keyframe) {
		return pack('H*', '1701000000');
	} else {
		return pack('H*', '2701000000');
	}
}

sub getAudioHeader {
	my($s) = @_;

	return pack('H*', 'af01');
}

sub metadata {
	my($s, $seq) = @_;

	my $args = [
		{
			key => 'duration',
			value => {
				type => RTMP::AMF::AMF_NUMBER,
				data => $s->{ts}->{duration},
			},
		},
		{
			key => 'width',
			value => {
				type => RTMP::AMF::AMF_NUMBER,
				data => $seq->{width},
			},
		},
		{
			key => 'height',
			value => {
				type => RTMP::AMF::AMF_NUMBER,
				data => $seq->{height},
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => 'onMetaData',
		},
		{
			type => RTMP::AMF::AMF_ASSOC_ARRAY,
			data => $args,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = $s->{type} << 6 | 5;
	my $timer = 0;
	my $data_type = 18;
	my $obj = 0x01000000;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{ts}->{rtmp}->{serializer}->send($packet);
}

sub playStatus {
	my($s) = @_;

	my $option = [
		{
			key => 'code',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'NetStream.Play.Complete',
			},
		},
		{
			key => 'level',
			value => {
				type => RTMP::AMF::AMF_STRING,
				data => 'status',
			},
		},
	];

	my @dump = (
		{
			type => RTMP::AMF::AMF_STRING,
			data => 'onPlayStatus',
		},
		{
			type => RTMP::AMF::AMF_HASH,
			data => $option,
		},
	);

	my $data = RTMP::AMF::dumpArray(@dump);

	my $frame = $s->{type} << 6 | 5;
	my $timer = 0;
	my $data_type = 18;
	my $obj = 0x01000000;
	my $packet = RTMP::Packet->new($frame,$timer,$data,$data_type,$obj);

	$s->{ts}->{rtmp}->{serializer}->send($packet);
}

1;
