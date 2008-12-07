package MP4::Writer;

use strict;
use Scalar::Util qw(weaken);
use RTMP::Packet;

sub new {
	my($pkg, $file) = @_;

	my $hash = {
		file => $file,
		video_first => 1,
		audio_first => 1,
		type => 0,
	};

	my $s = bless $hash, $pkg;

	weaken($s->{file});

	return $s;
}

sub reset {
	my($s, $type) = @_;
	$s->{video_first} = 1;
	$s->{audio_first} = 1;
	$s->{type} = $type;
}

sub send_video {
	my($s, $timer, $data, $keyframe) = @_;

	if ($s->{video_first} && $keyframe) {
		my $track = $s->{file}->{header}->{video};

		$s->metadata($track);

		my $video_extra = pack('H*', '1700000000');
		$video_extra .= pack('H*', '0142e00cffe1');
		$video_extra .= pack('n', length($track->{sequenceParameterSetNALUnit}));
		$video_extra .= $track->{sequenceParameterSetNALUnit};
		$video_extra .= pack('H*', '01');
		$video_extra .= pack('n', length($track->{pictureParameterSetNALUnit}));
		$video_extra .= $track->{pictureParameterSetNALUnit};

		my $frame = $s->{type} << 6 | 5;
		my $timer = 0;
		my $data_type = 9;
		my $obj = 0x01000000;
		my $packet = RTMP::Packet->new($frame,$timer,$video_extra,$data_type,$obj);
		$s->{file}->{rtmp}->{serializer}->send($packet);

		$s->{video_first} = 0;
	}

	my $video = $s->getVideoHeader($keyframe);
	$video .= $data;

	my $frame = 0x45;
	my $data_type = 9;
	my $obj = 0;
	my $packet = RTMP::Packet->new($frame,$timer,$video,$data_type,$obj);
	$s->{file}->{rtmp}->{serializer}->send($packet);
}

sub send_audio {
	my($s, $timer, $data) = @_;

	if ($s->{audio_first}) {
		my $track = $s->{file}->{header}->{audio};

		my $audio_extra = pack('H*', 'af00');
		$audio_extra .= $track->{decSpecificInfo};
		$audio_extra .= pack('H*', '06');

		my $frame = $s->{type} << 6 | 5;
		my $timer = 0;
		my $data_type = 8;
		my $obj = 0x01000000;
		my $packet = RTMP::Packet->new($frame,$timer,$audio_extra,$data_type,$obj);
		$s->{file}->{rtmp}->{serializer}->send($packet);

		$s->{audio_first} = 0;
	}

	my $audio = $s->getAudioHeader();
	$audio .= $data;

	my $frame = 0x45;
	my $data_type = 8;
	my $obj = 0;
	my $packet = RTMP::Packet->new($frame,$timer,$audio,$data_type,$obj);
	$s->{file}->{rtmp}->{serializer}->send($packet);
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
				data => $s->{file}->{header}->{duration},
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

	$s->{file}->{rtmp}->{serializer}->send($packet);
}

1;
