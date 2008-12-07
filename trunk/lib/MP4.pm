package MP4;

use strict;
use Scalar::Util qw(weaken);
use Fcntl;
use IO::Seekable;
use MP4::Header;
use MP4::Writer;
use MP4::H264;

use constant BUFFER_LENGTH => 10;

sub new {
	my($pkg, $rtmp) = @_;

	my $hash = {
		rtmp => $rtmp,
		handle => undef,
		break => 0,
		pause => 0,
	};

	my $s = bless $hash, $pkg;

	$s->{writer} = MP4::Writer->new($s);
	$s->{header} = MP4::Header->new($s);
	$s->reset();
	weaken($s->{rtmp});

	return $s;
}

sub reset {
	my($s) = @_;
	$s->{play} = 1;
	$s->{vtime} = 0;
	$s->{atime} = 0;
	$s->{sent_time} = undef;
	$s->{start_time} = undef;
}

sub open {
	my($s, $file) = @_;
	my $opt = O_RDONLY | O_BINARY;

	eval {
		$opt |= O_LARGEFILE;
	};

	if ($@) {
		warn "[NOTICE] not defined O_LARGEFILE\n";
	}

	sysopen($s->{handle}, $file, $opt);
	$s->{header}->execute();
}

sub close {
	my($s) = @_;
	close($s->{handle});
}

sub seek {
	my($s, $time) = @_;

	$s->reset();
	$s->{writer}->reset(1);

	return $s->{header}->seek($time);
}

sub pause {
	my($s, $flag) = @_;
	$s->{pause} = $flag;

	if (!$flag && $s->{sent_time}) {
		$s->{sent_time} = 0;
		$s->{start_time} = time() + BUFFER_LENGTH;
	}
}

sub parse {
	my($s) = @_;

	$s->{break} = 0;

	if (!defined $s->{sent_time}) {
		$s->{sent_time} = 0;
		$s->{start_time} = time();
	}

	my $sent_time = (time() - $s->{start_time} + BUFFER_LENGTH) * 1000;

	my $video = $s->{header}->{video};
	my $audio = $s->{header}->{audio};

	while (!$s->{break} && $s->{header}->exists($video) && $s->{header}->exists($audio)) {
		while (!$s->{break} && $s->{header}->exists($video)) {
			if ($s->{atime} < $s->{vtime}) {
				last;
			}

			if ($sent_time < $s->{sent_time}) {
				$s->{break} = 1;
				last;
			}

			if ($s->{rtmp}->checkReceive()) {
				$s->{break} = 1;
				last;
			}

			my $frame = $s->{header}->nextFrame($video);
			my $duration = $frame->{delta} / $video->{timeScale} * 1000;
			my $data = $s->getData($frame->{offset}, $frame->{size});
			my $p = MP4::H264->new($data);
			$s->{writer}->send_video($s->{vtime}, $p->{put}->{buf}, $frame->{key});

			$s->{atime} -= $s->{vtime};
			$s->{vtime} = $duration;

			$s->{sent_time} += $duration;
		}

		while (!$s->{break} && $s->{header}->exists($audio)) {
			if ($s->{vtime} < $s->{atime}) {
				last;
			}

			if ($sent_time < $s->{sent_time}) {
				$s->{break} = 1;
				last;
			}

			if ($s->{rtmp}->checkReceive()) {
				$s->{break} = 1;
				last;
			}

			my $frame = $s->{header}->nextFrame($audio);
			my $duration = $frame->{delta} / $audio->{timeScale} * 1000;
			my $data = $s->getData($frame->{offset}, $frame->{size});
			$s->{writer}->send_audio($s->{atime}, $data);

			$s->{vtime} -= $s->{atime};
			$s->{atime} = $duration;
		}
	}

	if (!$s->{break}) {
		$s->complete();
	}
}

sub getData {
	my($s, $offset, $length) = @_;

	seek($s->{handle}, $offset, SEEK_SET);

	my $data = '';

	while(0 < $length) {
		my $read = 1024 < $length ? 1024 : $length;
		$length -= read($s->{handle}, my $buf, $read);
		$data .= $buf;
	}

	return $data;
}

sub complete {
	my($s) = @_;
	$s->{play} = 0;
	$s->{rtmp}->complete();
}

sub execute {
	my($s) = @_;

	if ($s->{play} && !$s->{pause}) {
		$s->parse();
	}
}

1;
