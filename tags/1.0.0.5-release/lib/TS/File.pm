package TS::File;

use strict;
use TS::PESBuffer;
use Fcntl;

use constant PACKET_SIZE => 188;
use constant SYNC_BYTE => 0x47;
use constant PMT_PID => 0x1FC8;
use constant VIDEO_STREAM_TYPE => 0x1B;
use constant AUDIO_STREAM_TYPE => 0x0F;
use constant PES_START_CODE => 0x000001;

sub new {
	my($pkg) = @_;

	my $hash = {
		handle => undef,
		video_pid => undef,
		audio_pid => undef,
		pes_buffer => undef,
		break => 0,
	};

	my $s = bless $hash, $pkg;

	$s->{pes_buffer} = TS::PESBuffer->new();

	return $s;
}

sub reset {
	my($s) = @_;
	$s->{video_pid} = undef;
	$s->{audio_pid} = undef;
	$s->{pes_buffer}->reset();
}

sub open {
	my($s, $file) = @_;
	sysopen($s->{handle}, $file, O_RDONLY | O_LARGEFILE);
}

sub close {
	my($s) = @_;
	close($s->{handle});
}

sub parse {
	my($s) = @_;

	$s->{break} = 0;
	my $packet_size = 1;

	while(!$s->{break} && sysread($s->{handle}, my $buf, $packet_size)) {
		my $sync_byte = vec($buf, 0, 8);

		if ($sync_byte == SYNC_BYTE) {
			$packet_size = PACKET_SIZE;

			while(length($buf) < PACKET_SIZE && sysread($s->{handle}, my $add, 1)) {
				$buf .= $add;
			}
		} else {
			$packet_size = 1;
			next;
		}

		my $ts = $s->parseTS($buf);
		my $b = $s->{pes_buffer}->getPES($ts->{pid});

		if ($ts->{payload_unit_start_indicator}) {

			if ($ts->{pid} == PMT_PID) {
				if (!defined $s->{video_pid} || !defined $s->{audio_pid}) {
					$s->pmt($ts);
				}
			}

			if ($ts->{pid} == $s->{video_pid}) {
				$s->video($ts, $b);
			}

			if ($ts->{pid} == $s->{audio_pid}) {
				$s->audio($ts, $b);
			}
		}

		if ($b->{buffering}) {
			$b->{buf} .= $ts->{payload};
		}
	}

	if (!$s->{break}) {
		$s->complete();
	}
}

sub pmt {
	my($s, $ts) = @_;

	my $pmt = $s->parsePMT($ts);

	for (my $i = 0; $i < @{$pmt->{program}}; $i++) {
		if ($pmt->{program}->[$i]->{stream_type} == VIDEO_STREAM_TYPE) {
			$s->{video_pid} = $pmt->{program}->[$i]->{elementary_PID};
		}

		if ($pmt->{program}->[$i]->{stream_type} == AUDIO_STREAM_TYPE) {
			$s->{audio_pid} = $pmt->{program}->[$i]->{elementary_PID};
		}
	}
}

sub video {
	my($s, $ts, $b) = @_;
}

sub audio {
	my($s, $ts, $b) = @_;
}

sub complete {
	my($s) = @_;
}

sub parseTS {
	my($s, $buf) = @_;

	my $byte = 0;
	my $ret = {};

	$ret->{sync_byte} = vec($buf, $byte++, 8);

	my $a = vec($buf, $byte++, 8);
	my $b = vec($buf, $byte++, 8);
	$ret->{transport_error_indicator}		= $a >> 7 & 0x01;
	$ret->{payload_unit_start_indicator}	= $a >> 6 & 0x01;
	$ret->{transport_priority}				= $a >> 5 & 0x01;
	$ret->{pid}								= ($a & 0x1F) << 8 | $b;

	my $a = vec($buf, $byte++, 8);
	$ret->{transport_scrambling_control}	= $a >> 6 & 0x03;
	$ret->{adaptation_field_control}		= $a >> 4 & 0x03;
	$ret->{continuity_counter}				= $a      & 0x0F;

	if ($ret->{adaptation_field_control} & 0x02) {
		$ret->{adaptation_field_length} = vec($buf, $byte++, 8);
		$byte += $ret->{adaptation_field_length};
	}

	$ret->{payload} = substr($buf, $byte);

	return $ret;
}

sub parsePMT {
	my($s, $ts) = @_;

	my $buf = $ts->{payload};
	my $byte = 0;
	my $ret = {};

	$ret->{pointer_field} = vec($buf, $byte++, 8);
	$byte += $ret->{pointer_field};

	$ret->{table_id} = vec($buf, $byte++, 8);

	my $a = vec($buf, $byte++, 8);
	my $b = vec($buf, $byte++, 8);
	$ret->{section_syntax_indicator}	= $a >> 7 & 0x01;
	$ret->{private_indicator}			= $a >> 6 & 0x01;
	$ret->{section_length}				= ($a & 0x0F) << 8 | $b;
	my $program_endbyte = $byte + $ret->{section_length};

	$ret->{program_number} = 0;
	$ret->{version_number} = 0;
	$ret->{current_next_indicator} = 0;
	$ret->{section_number} = 0;
	$ret->{last_section_number} = 0;

	if ($ret->{section_syntax_indicator}) {
		my $a = vec($buf, $byte++, 8);
		my $b = vec($buf, $byte++, 8);
		$ret->{program_number} = $a << 8 | $b;

		my $a = vec($buf, $byte++, 8);
		$ret->{version_number} = $a >> 1 & 0x1F;
		$ret->{current_next_indicator} = $a & 0x01;

		$ret->{section_number} = vec($buf, $byte++, 8);
		$ret->{last_section_number} = vec($buf, $byte++, 8);
	}

	my $a = vec($buf, $byte++, 8);
	my $b = vec($buf, $byte++, 8);
	$ret->{PCR_PID} = ($a & 0x1F) << 8 | $b;

	my $a = vec($buf, $byte++, 8);
	my $b = vec($buf, $byte++, 8);
	$ret->{program_info_length} = ($a & 0x0F) << 8 | $b;
	my $descriptor_endbyte = $byte + $ret->{program_info_length};

	$ret->{descriptor} = [];

	while ($byte + 2 < $descriptor_endbyte) {
		my $desc = {};

		$desc->{desc_tag} = vec($buf, $byte++, 8);
		$desc->{desc_length} = vec($buf, $byte++, 8);
		$desc->{desc_data} = substr($buf, $byte, $desc->{desc_length});
		$byte += $desc->{desc_length};

		push(@{$ret->{descriptor}}, $desc);
	}

	$ret->{program} = [];

	while ($byte + 5 < $program_endbyte) {
		my $prog = {};

		$prog->{stream_type} = vec($buf, $byte++, 8);

		my $a = vec($buf, $byte++, 8);
		my $b = vec($buf, $byte++, 8);
		$prog->{elementary_PID} = ($a & 0x1F) << 8 | $b;

		my $a = vec($buf, $byte++, 8);
		my $b = vec($buf, $byte++, 8);
		$prog->{ES_info_length} = ($a & 0x0F) << 8 | $b;
		my $descriptor_endbyte = $byte + $prog->{ES_info_length};

		$prog->{descriptor} = [];

		while ($byte + 2 < $descriptor_endbyte) {
			my $desc = {};

			$desc->{desc_tag} = vec($buf, $byte++, 8);
			$desc->{desc_length} = vec($buf, $byte++, 8);
			$desc->{desc_data} = substr($buf, $byte, $desc->{desc_length});
			$byte += $desc->{desc_length};

			push(@{$prog->{descriptor}}, $desc);
		}

		push(@{$ret->{program}}, $prog);
	}

	$byte = $program_endbyte;

	$ts->{payload} = substr($buf, $byte);

	return $ret;
}

sub parsePES {
	my($s, $ts) = @_;

	my $buf = $ts->{payload};
	my $byte = 0;
	my $ret = {};

	my $a = vec($buf, $byte++, 8);
	my $b = vec($buf, $byte++, 8);
	my $c = vec($buf, $byte++, 8);
	$ret->{packet_start_code_prefix} = $a << 16 | $b << 8 | $c;

	if ($ret->{packet_start_code_prefix} == PES_START_CODE) {

		$ret->{stream_id}						= vec($buf, $byte++, 8);
		my $a = vec($buf, $byte++, 8);
		my $b = vec($buf, $byte++, 8);
		$ret->{PES_packet_length}				= $a << 8 | $b;

		my $a = vec($buf, $byte++, 8);
		$ret->{PES_scrambling_control}			= $a >> 4 & 0x03;
		$ret->{PES_priority}					= $a >> 3 & 0x01;
		$ret->{data_alignment_indicator}		= $a >> 2 & 0x01;
		$ret->{copyright}						= $a >> 1 & 0x01;
		$ret->{original_or_copy}				= $a      & 0x01;

		my $a = vec($buf, $byte++, 8);
		$ret->{PTS_flags}						= $a >> 7 & 0x01;
		$ret->{DTS_flags}						= $a >> 6 & 0x01;
		$ret->{ESCR_flag}						= $a >> 5 & 0x01;
		$ret->{ES_rate_flag}					= $a >> 4 & 0x01;
		$ret->{DSM_trick_mode_flag}				= $a >> 3 & 0x01;
		$ret->{additional_copy_info_flag}		= $a >> 2 & 0x01;
		$ret->{PES_CRC_flag}					= $a >> 1 & 0x01;
		$ret->{PES_extension_flag}				= $a      & 0x01;

		$ret->{PES_header_data_length}			= vec($buf, $byte++, 8);

		my $tmpByte = $byte + $ret->{PES_header_data_length};

		if ($ret->{PTS_flags}) {
			my $a = vec($buf, $byte++, 8);
			my $pts1 = $a >> 1 & 0x07;
			my $a = vec($buf, $byte++, 8);
			my $b = vec($buf, $byte++, 8);
			my $pts2 = $a << 7 | $b >> 1 & 0x7F;
			my $a = vec($buf, $byte++, 8);
			my $b = vec($buf, $byte++, 8);
			my $pts3 = $a << 7 | $b >> 1 & 0x7F;
			$ret->{pts} = ($pts1 * 32768 * 32768) + ($pts2 * 32768) + $pts3;
		}

		$byte = $tmpByte;

		$ts->{payload} = substr($buf, $byte);

	} else {
		warn "[ERROR] not pes code\n";
	}

	return $ret;
}

1;
