#!/usr/bin/perl

use strict;
use lib 'lib';
use IO::Socket;
use IO::Select;
use RTMP;

my $dir = $ARGV[0];

if ($dir eq '') {
	die "Usage: $0 <document root>\n";
} else {
	$dir =~ s/\/$//;
}

my $port = '1935';
my $lsn = new IO::Socket::INET(Listen => 1, LocalPort => $port, Reuse => 1) or exit;
my $sel = new IO::Select($lsn);

my $session = {};

while (1) {
	for my $sock ($sel->can_read(5)) {
		if ($sock == $lsn) {
			my $new = $lsn->accept;
			$sel->add($new);
			$session->{$new} = RTMP->new($new, $dir);
			warn "[socket] connect from ", $new->peerhost, "\n";
		} else {
			if (sysread($sock, my $buf, 8192)) {
				$session->{$sock}->receive($buf);
			} else {
				$session->{$sock}->close();
				delete $session->{$sock};
				warn "[socket] disconnect\n";
				$sel->remove($sock);
				$sock->close;
			}
		}
	}

	foreach my $sock (keys %$session) {
		$session->{$sock}->execute();
	}
}

