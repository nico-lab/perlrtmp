package MP4::Header;

use strict;
use Scalar::Util qw(weaken);
use IO::Seekable;

use constant HANDLER_VIDEO => 'vide';
use constant HANDLER_AUDIO => 'soun';

use constant TAG_ES_DESCR => 3;
use constant TAG_DEC_CONFIG_DESCR => 4;
use constant TAG_DEC_SPECIFIC_DESCR => 5;

sub new {
	my($pkg, $file) = @_;

	my $hash = {
		file => $file,
		duration => 0,
		track => {},
		video => undef,
		audio => undef,
	};

	my $s = bless $hash, $pkg;

	weaken($s->{file});

	return $s;
}

sub execute {
	my($s) = @_;

	while(!$s->getEof()) {

		my $length = $s->getLong();
		my $atom = $s->getBytes(4);
		my $end = $s->getPos() + $length - 8;

		if ($length == 1) {
			$length = $s->getLongLong();
			$end = $s->getPos() + $length - 16;
		}

		if ($atom eq 'moov') {
			next;
		} elsif ($atom eq 'mvhd') {
			$s->mvhd();
		} elsif ($atom eq 'trak') {
			$s->trak();
			next;
		} elsif ($atom eq 'mdia') {
			next;
		} elsif ($atom eq 'mdhd') {
			$s->mdhd();
		} elsif ($atom eq 'hdlr') {
			$s->hdlr();
		} elsif ($atom eq 'minf') {
			next;
		} elsif ($atom eq 'stbl') {
			next;
		} elsif ($atom eq 'stsd') {
			$s->stsd();
			next;
		} elsif ($atom eq 'stts') {
			$s->stts();
		} elsif ($atom eq 'stss') {
			$s->stss();
		} elsif ($atom eq 'stsc') {
			$s->stsc();
		} elsif ($atom eq 'stsz') {
			$s->stsz();
		} elsif ($atom eq 'stco') {
			$s->stco();
		} elsif ($atom eq 'avc1') {
			$s->avc1();
			next;
		} elsif ($atom eq 'avcC') {
			$s->avcC();
		} elsif ($atom eq 'mp4a') {
			$s->mp4a();
			next;
		} elsif ($atom eq 'esds') {
			$s->esds($end);
		}

		$s->setSeek($end);
	}
}

sub seek {
	my($s, $time) = @_;

	$time = $s->seekTrack($s->{video}, $time);
	$s->seekTrack($s->{audio}, $time);

	return $time;
}

# file

sub setSeek {
	my($s, $pos) = @_;
	seek($s->{file}->{handle}, $pos, SEEK_SET);
}

sub getEof {
	my($s) = @_;
	return eof($s->{file}->{handle});
}

sub getPos {
	my($s) = @_;
	return tell($s->{file}->{handle});
}

sub getBytes {
	my($s, $length) = @_;

	my $data = '';

	while(0 < $length && !$s->getEof()) {
		my $read = 1024 < $length ? 1024 : $length;
		$length -= read($s->{file}->{handle}, my $buf, $read);
		$data .= $buf;
	}

	return $data;
}

sub getInt {
	my($s) = @_;
	read($s->{file}->{handle}, my $buf, 1);
	return unpack('C', $buf);
}

sub getShort {
	my($s) = @_;
	read($s->{file}->{handle}, my $buf, 2);
	return unpack('n', $buf);
}

sub getMedium {
	my($s) = @_;
	read($s->{file}->{handle}, my $buf, 3);
	return unpack('N', "\x00" . $buf);
}

sub getLong {
	my($s) = @_;
	read($s->{file}->{handle}, my $buf, 4);
	return unpack('N', $buf);
}

sub getLongLong {
	my($s) = @_;
	my $a = $s->getLong();
	my $b = $s->getLong();
	return $a << 32 | $b;
}

# track

sub seekTrack {
	my($s, $track, $time) = @_;

	$track->{stts}->{entryCurrent} = 0;
	$track->{stts}->{sampleCount} = 0;
	$track->{stts}->{sampleDelta} = -1;

	my $frame = 0;

	$s->atomSeek($track->{stts});

	while ($track->{stts}->{entryCurrent} < $track->{stts}->{entryCount}) {
		$track->{stts}->{sampleCount} = $s->getLong();
		$track->{stts}->{sampleDelta} = $s->getLong();
		$track->{stts}->{entryCurrent}++;

		my $duration = $track->{stts}->{sampleDelta} / $track->{timeScale} * 1000;
		my $count = int($time / $duration);

		if ($track->{stts}->{sampleCount} < $count) {
			$frame += $track->{stts}->{sampleCount};
			$time -= $duration * $track->{stts}->{sampleCount};
		} else {
			$frame += $count;
			$time -= $duration * $count;
			last;
		}
	}

	$track->{stss}->{entryCurrent} = 0;
	$track->{stss}->{sampleNumber} = -1;

	my $keyframe = $frame;
	my $entryCurrent = 0;

	$s->atomSeek($track->{stss});

	while ($track->{stss}->{entryCurrent} < $track->{stss}->{entryCount}) {
		$track->{stss}->{sampleNumber} = $s->getLong() - 1;
		$track->{stss}->{entryCurrent}++;

		if ($frame < $track->{stss}->{sampleNumber}) {
			last;
		}

		$keyframe = $track->{stss}->{sampleNumber};
		$entryCurrent = $track->{stss}->{entryCurrent};
	}

	$track->{stss}->{sampleNumber} = $keyframe;
	$track->{stss}->{entryCurrent} = $entryCurrent;

	$track->{stts}->{entryCurrent} = 0;
	$track->{stts}->{sampleCount} = 0;
	$track->{stts}->{sampleDelta} = -1;

	my $result = 0;
	my $count = $keyframe;

	$s->atomSeek($track->{stts});

	while ($track->{stts}->{entryCurrent} < $track->{stts}->{entryCount}) {
		$track->{stts}->{sampleCount} = $s->getLong();
		$track->{stts}->{sampleDelta} = $s->getLong();
		$track->{stts}->{entryCurrent}++;

		my $duration = $track->{stts}->{sampleDelta} / $track->{timeScale} * 1000;

		if ($track->{stts}->{sampleCount} < $count) {
			$result += $duration * $track->{stts}->{sampleCount};
			$count -= $track->{stts}->{sampleCount};
		} else {
			$result += $duration * $count;
			$track->{stts}->{sampleCount} -= $count;
			last;
		}
	}

	$track->{samplesPerChunkCurrent} = 0;
	$track->{samplesPerChunkCount} = 0;

	$track->{stsc}->{entryCurrent} = 0;
	$track->{stsc}->{firstChunk} = -1;
	$track->{stsc}->{samplesPerChunk} = 0;
	$track->{stsc}->{sampleDescriptionIndex} = 0;

	$track->{stco}->{entryCurrent} = 0;
	$track->{stco}->{chunkOffset} = -1;

	my $firstSample = 0;

	$s->atomSeek($track->{stsc});

	while ($track->{stco}->{entryCurrent} < $track->{stco}->{entryCount}) {
		if ($track->{stsc}->{entryCurrent} < $track->{stsc}->{entryCount}) {
			if ($track->{stsc}->{firstChunk} < $track->{stco}->{entryCurrent}) {
				$track->{stsc}->{firstChunk} = $s->getLong() - 1;
				$track->{stsc}->{samplesPerChunk} = $s->getLong();
				$track->{stsc}->{sampleDescriptionIndex} = $s->getLong();
				$track->{stsc}->{entryCurrent}++;
			}
		}

		if ($track->{stsc}->{firstChunk} == $track->{stco}->{entryCurrent}) {
			$track->{samplesPerChunkCurrent} = $track->{stsc}->{samplesPerChunk};
		}

		my $next = $firstSample + $track->{samplesPerChunkCurrent};

		if ($keyframe <= $next) {
			last;
		}

		$track->{stco}->{entryCurrent}++;
		$firstSample = $next;
	}

	$track->{stsz}->{entryCurrent} = $firstSample;
	$track->{stsz}->{sampleSize} = -1;

	while ($track->{stsz}->{entryCurrent} < $keyframe) {
		if ($track->{stco}->{entryCurrent} < $track->{stco}->{entryCount}) {
			if (!$track->{samplesPerChunkCount}) {
				$s->atomSeek($track->{stco});

				$track->{stco}->{chunkOffset} = $s->getLong();
				$track->{stco}->{entryCurrent}++;

				$track->{samplesPerChunkCount} = $track->{samplesPerChunkCurrent};
			}
		}

		$track->{samplesPerChunkCount}--;

		if ($track->{stsz}->{entryCurrent} < $track->{stsz}->{entryCount}) {
			$s->atomSeek($track->{stsz});

			$track->{stsz}->{sampleSize} = $s->getLong();
			$track->{stsz}->{entryCurrent}++;
		}

		$track->{stco}->{chunkOffset} += $track->{stsz}->{sampleSize};
	}

	return $result;
}

sub nextFrame {
	my($s, $track) = @_;

	if ($track->{stss}->{entryCurrent} < $track->{stss}->{entryCount}) {
		if ($track->{stss}->{sampleNumber} < $track->{stsz}->{entryCurrent}) {
			$s->atomSeek($track->{stss});

			$track->{stss}->{sampleNumber} = $s->getLong() - 1;
			$track->{stss}->{entryCurrent}++;
		}
	}

	my $key = ($track->{stss}->{sampleNumber} == $track->{stsz}->{entryCurrent}) ? 1 : 0;

	if ($track->{stts}->{entryCurrent} < $track->{stts}->{entryCount}) {
		if (!$track->{stts}->{sampleCount}) {
			$s->atomSeek($track->{stts});

			$track->{stts}->{sampleCount} = $s->getLong();
			$track->{stts}->{sampleDelta} = $s->getLong();
			$track->{stts}->{entryCurrent}++;
		}
	}

	$track->{stts}->{sampleCount}--;

	my $delta = $track->{stts}->{sampleDelta};

	if ($track->{stsc}->{entryCurrent} < $track->{stsc}->{entryCount}) {
		if ($track->{stsc}->{firstChunk} < $track->{stco}->{entryCurrent}) {
			$s->atomSeek($track->{stsc});

			$track->{stsc}->{firstChunk} = $s->getLong() - 1;
			$track->{stsc}->{samplesPerChunk} = $s->getLong();
			$track->{stsc}->{sampleDescriptionIndex} = $s->getLong();
			$track->{stsc}->{entryCurrent}++;
		}
	}

	if ($track->{stsc}->{firstChunk} == $track->{stco}->{entryCurrent}) {
		$track->{samplesPerChunkCurrent} = $track->{stsc}->{samplesPerChunk};
	}

	if ($track->{stco}->{entryCurrent} < $track->{stco}->{entryCount}) {
		if (!$track->{samplesPerChunkCount}) {
			$s->atomSeek($track->{stco});

			$track->{stco}->{chunkOffset} = $s->getLong();
			$track->{stco}->{entryCurrent}++;

			$track->{samplesPerChunkCount} = $track->{samplesPerChunkCurrent};
		}
	}

	$track->{samplesPerChunkCount}--;

	my $offset = $track->{stco}->{chunkOffset};

	if ($track->{stsz}->{entryCurrent} < $track->{stsz}->{entryCount}) {
		$s->atomSeek($track->{stsz});

		$track->{stsz}->{sampleSize} = $s->getLong();
		$track->{stsz}->{entryCurrent}++;
	}

	$track->{stco}->{chunkOffset} += $track->{stsz}->{sampleSize};

	my $size = $track->{stsz}->{sampleSize};

	return {key => $key, delta => $delta, offset => $offset, size => $size};
}

sub exists {
	my($s, $track) = @_;
	return $track->{stsz}->{entryCurrent} < $track->{stsz}->{entryCount};
}

# atom

sub atomSeek {
	my($s, $atom) = @_;
	my $offset = $atom->{atomOffset} + ($atom->{entryLength} * $atom->{entryCurrent});
	$s->setSeek($offset);
}

sub trak {
	my($s) = @_;

	$s->{track} = {};

	$s->{track}->{samplesPerChunkCurrent} = 0;
	$s->{track}->{samplesPerChunkCount} = 0;

	$s->{track}->{stts} = {};
	$s->{track}->{stts}->{entryCurrent} = 0;
	$s->{track}->{stts}->{entryLength} = 8;
	$s->{track}->{stts}->{entryCount} = 0;
	$s->{track}->{stts}->{sampleCount} = 0;
	$s->{track}->{stts}->{sampleDelta} = -1;

	$s->{track}->{stss} = {};
	$s->{track}->{stss}->{entryCurrent} = 0;
	$s->{track}->{stss}->{entryLength} = 4;
	$s->{track}->{stss}->{entryCount} = 0;
	$s->{track}->{stss}->{sampleNumber} = -1;

	$s->{track}->{stsc} = {};
	$s->{track}->{stsc}->{entryCurrent} = 0;
	$s->{track}->{stsc}->{entryLength} = 12;
	$s->{track}->{stsc}->{entryCount} = 0;
	$s->{track}->{stsc}->{firstChunk} = -1;
	$s->{track}->{stsc}->{samplesPerChunk} = 0;
	$s->{track}->{stsc}->{sampleDescriptionIndex} = 0;

	$s->{track}->{stsz} = {};
	$s->{track}->{stsz}->{entryCurrent} = 0;
	$s->{track}->{stsz}->{entryLength} = 4;
	$s->{track}->{stsz}->{entryCount} = 0;
	$s->{track}->{stsz}->{sampleSize} = -1;

	$s->{track}->{stco} = {};
	$s->{track}->{stco}->{entryCurrent} = 0;
	$s->{track}->{stco}->{entryLength} = 4;
	$s->{track}->{stco}->{entryCount} = 0;
	$s->{track}->{stco}->{chunkOffset} = -1;
}

sub mvhd {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $creationTime = $s->getLong();
	my $modificationTime = $s->getLong();
	my $timeScale = $s->getLong();
	my $duration = $s->getLong();

	$s->{duration} = $duration / $timeScale;
}

sub mdhd {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();

	my $creationTime;
	my $modificationTime;
	my $timeScale;
	my $duration;

	if ($version == 1) {
		$creationTime = $s->getLongLong();
		$modificationTime = $s->getLongLong();
		$timeScale = $s->getLong();
		$duration = $s->getLongLong();
	} else {
		$creationTime = $s->getLong();
		$modificationTime = $s->getLong();
		$timeScale = $s->getLong();
		$duration = $s->getLong();
	}

	$s->{track}->{timeScale} = $timeScale;
	$s->{track}->{duration} = $duration;
}

sub hdlr {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	$s->getBytes(4);
	my $handlerType = $s->getBytes(4);

	if ($handlerType eq HANDLER_VIDEO) {
		$s->{video} = $s->{track};
	} elsif ($handlerType eq HANDLER_AUDIO) {
		$s->{audio} = $s->{track};
	}
}

sub stsd {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $entryCount = $s->getLong();
}

sub avc1 {
	my($s) = @_;

	$s->getBytes(6);
	my $dataReferenceIndex = $s->getShort();
	$s->getBytes(16);
	my $width = $s->getShort();
	my $height = $s->getShort();
	$s->getBytes(14);
	$s->getBytes(32);
	$s->getBytes(4);

	$s->{track}->{width} = $width;
	$s->{track}->{height} = $height;
}

sub avcC {
	my($s) = @_;

	my $configurationVersion = $s->getInt();
	my $AVCProfileIndication = $s->getInt();
	my $profile_compatibility = $s->getInt();
	my $AVCLevelIndication = $s->getInt();

	my $a = $s->getInt();
	my $lengthSizeMinusOne = $a & 0x03;

	my $a = $s->getInt();
	my $numOfSequenceParameterSets = $a & 0x1F;

	while($numOfSequenceParameterSets--) {
		my $sequenceParameterSetLength = $s->getShort();
		my $sequenceParameterSetNALUnit = $s->getBytes($sequenceParameterSetLength);
		$s->{track}->{sequenceParameterSetNALUnit} = $sequenceParameterSetNALUnit;
	}

	my $numOfPictureParameterSets = $s->getInt();

	while($numOfPictureParameterSets--) {
		my $pictureParameterSetLength = $s->getShort();
		my $pictureParameterSetNALUnit = $s->getBytes($pictureParameterSetLength);
		$s->{track}->{pictureParameterSetNALUnit} = $pictureParameterSetNALUnit;
	}
}

sub mp4a {
	my($s) = @_;

	$s->getBytes(6);
	my $dataReferenceIndex = $s->getShort();
	my $soundVersion = $s->getShort();
	$s->getBytes(6);
	my $channels = $s->getShort();
	my $sampleSize = $s->getShort();
	my $packetSize = $s->getShort();
	my $timeScale = $s->getLong();
	$s->getBytes(2);
}

sub esds {
	my($s, $end) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();

	while($s->getPos() < $end) {
		my $tag = $s->getInt();
		my $length = $s->getInt();

		if ($length == 0x80) {
			$s->getBytes(2);
			$length = $s->getInt();
		}

		if ($tag == TAG_ES_DESCR) {
			$s->getBytes(3);
		} elsif ($tag == TAG_DEC_CONFIG_DESCR) {
			$s->getBytes(13);
		} elsif ($tag == TAG_DEC_SPECIFIC_DESCR) {
			my $decSpecificInfo = $s->getBytes($length);
			$s->{track}->{decSpecificInfo} = $decSpecificInfo;
		} else {
			$s->getBytes($length);
		}
	}
}

sub stts {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $entryCount = $s->getLong();

	$s->{track}->{stts}->{entryCount} = $entryCount;
	$s->{track}->{stts}->{atomOffset} = $s->getPos();
}

sub stss {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $entryCount = $s->getLong();

	$s->{track}->{stss}->{entryCount} = $entryCount;
	$s->{track}->{stss}->{atomOffset} = $s->getPos();
}

sub stsc {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $entryCount = $s->getLong();

	$s->{track}->{stsc}->{entryCount} = $entryCount;
	$s->{track}->{stsc}->{atomOffset} = $s->getPos();
}

sub stsz {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $sampleSize = $s->getLong();
	my $entryCount = $s->getLong();

	$s->{track}->{stsz}->{entryCount} = $entryCount;
	$s->{track}->{stsz}->{atomOffset} = $s->getPos();
}

sub stco {
	my($s) = @_;

	my $version = $s->getInt();
	my $flags = $s->getMedium();
	my $entryCount = $s->getLong();

	$s->{track}->{stco}->{entryCount} = $entryCount;
	$s->{track}->{stco}->{atomOffset} = $s->getPos();
}

1;
