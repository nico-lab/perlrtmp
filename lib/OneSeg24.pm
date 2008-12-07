package OneSeg24;

use strict;
use base qw(TS);
use Time::Local;
use Fcntl;
use IO::Seekable;

sub new {
	my($pkg, $rtmp) = @_;

	my $s = $pkg->SUPER::new($rtmp);

	$s->{bytes} = 0;
	$s->{files} = [];
	$s->{current} = -1;

	return $s;
}

sub timeToPath {
	my($s, $time, $ch) = @_;

	my($ss, $ii, $hh, $dd, $mm, $yy) = localtime($time);

	$yy = $yy % 100;
	$mm = $mm + 1;

	my $dir = sprintf('%02d%02d%02d', $yy, $mm, $dd);
	my $file = sprintf('%02d%02d%02d%02d_Ch%02d', $yy, $mm, $dd, $hh, $ch);

	return sprintf('%s/%s/%s', $s->{rtmp}->{dir}, $dir, $file);
}

sub totToTime {
	my($s, $tot) = @_;

	my($mjd, $hour, $min, $sec) = unpack('nCCC', $tot);

	my $yy = int(($mjd - 15078.2) / 365.25);
	my $mm = int(($mjd - 14956.1 - int($yy * 365.25)) / 30.6001);
	my $dd = int($mjd - 14956 - int($yy * 365.25) - int($mm * 30.6001));

	if (13 < $mm) {
		$yy = $yy + 1;
		$mm = $mm - 12;
	}

	$yy = $yy + 1900;
	$mm = $mm - 1;

	my $hh = (($hour >> 4) & 0x0F) * 10 + ($hour & 0x0F);
	my $ii = (($min >> 4) & 0x0F) * 10 + ($min & 0x0F);
	my $ss = (($sec >> 4) & 0x0F) * 10 + ($sec & 0x0F);

	return timelocal($ss, $ii, $hh, $dd, $mm - 1, $yy);
}

sub open {
	my($s, $file) = @_;

	if ($file !~ /^(\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)(?:-(\d{6}))?-(\d\d)/) {
		warn "[ERROR] format error: $file\n";
		return 0;
	}

	my $yy = $1 + 2000;
	my $mm = $2;
	my $dd = $3;
	my $stime = timelocal($6, $5, $4, $dd, $mm - 1, $yy);
	my $etime = $stime + (3600 * 2);
	my $end = $7;
	my $ch = $8;

	if ($end =~ /^(\d\d)(\d\d)(\d\d)$/) {
		$etime = timelocal($3, $2, $1, $dd, $mm - 1, $yy);

		if ($etime < $stime) {
			$etime += 3600 * 24;
		}
	}

	my $time = $stime - 3600;
	my $path = $s->timeToPath($time, $ch) . '.idx';

	if (!-f $path) {
		$time = $stime;
	}

	my $starttime = $stime;
	my $startpos = 0;
	my $break = 0;

	while(!$break) {
		my $path = $s->timeToPath($time, $ch) . '.idx';

		if (!-f $path) {
			warn "[ERROR] file not found: $path\n";
			return 0;
		}

		sysopen(my $idx, $path, O_RDONLY | O_BINARY);

		while(!eof($idx)) {
			read($idx, my $tot, 5);
			read($idx, my $pos, 4);
			my $itime = $s->totToTime($tot);
			my $ipos = unpack('L', $pos);

			if ($stime < $itime) {
				$break = 1;
				last;
			}

			$starttime = $itime;
			$startpos = $ipos;
		}

		close($idx);

		$time += 3600;
	}

	my $time = $starttime;
	my $endtime = $etime;
	my $endpos = 0;
	my $break = 0;

	while(!$break) {
		my $path = $s->timeToPath($time, $ch) . '.idx';

		if (!-f $path) {
			last;
		}

		sysopen(my $idx, $path, O_RDONLY | O_BINARY);

		while(!eof($idx)) {
			read($idx, my $tot, 5);
			read($idx, my $pos, 4);
			my $itime = $s->totToTime($tot);
			my $ipos = unpack('L', $pos);

			$endtime = $itime;
			$endpos = $ipos;

			if ($etime < $itime) {
				$break = 1;
				last;
			}
		}

		close($idx);

		$time += 3600;
	}

	my $time = $starttime;
	my $startpath = $s->timeToPath($starttime, $ch) . '.ts';
	my $endpath = $s->timeToPath($endtime, $ch) . '.ts';
	$s->{bytes} = 0;
	$s->{files} = [];
	$s->{current} = -1;

	while(1) {
		my $path = $s->timeToPath($time, $ch) . '.ts';

		if (!-f $path) {
			warn "[ERROR] file not found: $path\n";
			return 0;
		}

		sysopen(my $ts, $path, O_RDONLY | O_BINARY);

		seek($ts, 0, SEEK_END);
		my $bytes = tell($ts);

		close($ts);

		my $offset = $path eq $startpath ? $startpos : 0;
		my $end = $path eq $endpath ? $endpos : $bytes;
		my $length = $end - $offset;

		my $info = {
			path => $path,
			offset => $offset,
			start => $s->{bytes},
			end => $s->{bytes} + $length,
		};

		$s->{bytes} += $length;
		push(@{$s->{files}}, $info);

		if ($path eq $endpath) {
			last;
		}

		$time += 3600;
	}

	$s->fileSeek(0, SEEK_SET);
	$s->{header}->execute();
	return 1;
}

sub fileSeek {
	my($s, $offset, $whence) = @_;

	if ($whence == SEEK_CUR) {
		$offset += $s->fileTell();
	} elsif ($whence == SEEK_END) {
		$offset += $s->{bytes};
	}

	if ($offset < 0) {
		$offset = 0;
	}

	my $current = -1;

	for (my $i = 0; $i < @{$s->{files}}; $i++) {
		my $file = $s->{files}->[$i];

		if ($file->{start} <= $offset) {
			$current = $i;
		}
	}

	if ($s->{current} != $current) {
		if ($s->{handle}) {
			close($s->{handle});
		}

		sysopen($s->{handle}, $s->{files}->[$current]->{path}, O_RDONLY | O_BINARY);
		$s->{current} = $current;
	}

	my $file = $s->{files}->[$s->{current}];
	return seek($s->{handle}, $offset - $file->{start} + $file->{offset}, SEEK_SET);
}

sub fileRead {
	my($s) = @_;

	my $file = $s->{files}->[$s->{current}];
	my $pos = $s->fileTell();

	if ($pos < $file->{end}) {
		return read($s->{handle}, $_[1], $_[2]);
	}

	if ($pos < $s->{bytes}) {
		$s->fileSeek(0, SEEK_CUR);
		return read($s->{handle}, $_[1], $_[2]);
	}

	return 0;
}

sub fileTell {
	my($s) = @_;

	my $file = $s->{files}->[$s->{current}];
	return $file->{start} + tell($s->{handle}) - $file->{offset};
}

1;
