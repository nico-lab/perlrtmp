package TS::File;

use strict;
use Binary;

use constant PACKET_SIZE => 188;
use constant SYNC_BYTE => 0x47;
use constant PMT_PID => 0x1FC8;
use constant VIDEO_STREAM_TYPE => 0x1B;
use constant AUDIO_STREAM_TYPE => 0x0F;
use constant PES_START_CODE => 0x000001;

sub new {
	my($pkg) = @_;

	my $hash = {
		video_pid => undef,
		audio_pid => undef,
		break => 0,
	};

	my $s = bless $hash, $pkg;

	return $s;
}

sub parse {
	my($s) = @_;

	$s->{break} = 0;
	my $packet_size = 1;

	while(!$s->{break} && $s->read(my $buf, $packet_size)) {
		my $sync_byte = vec($buf, 0, 8);

		if ($sync_byte == SYNC_BYTE) {
			$packet_size = PACKET_SIZE;

			while(length($buf) < PACKET_SIZE && $s->read(my $add, 1)) {
				$buf .= $add;
			}
		} else {
			$packet_size = 1;
			next;
		}

		my $buffer = Binary->new($buf);

		my $ts = $s->parseTS($buffer);

		if ($ts->{payload_unit_start_indicator}) {

			if ($ts->{pid} == PMT_PID) {
				if (!defined $s->{video_pid} || !defined $s->{audio_pid}) {
					$s->pmt($ts, $buffer);
				}
			}

			if ($ts->{pid} == $s->{video_pid}) {
				$s->video($ts, $buffer);
			}

			if ($ts->{pid} == $s->{audio_pid}) {
				$s->audio($ts, $buffer);
			}
		}

		$s->payload($ts, $buffer);
	}

	if (!$s->{break}) {
		$s->complete();
	}
}

sub read {
	my($s) = @_;
	return 0;
}

sub pmt {
	my($s, $ts, $buffer) = @_;

	my $pmt = $s->parsePMT($buffer);

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
	my($s, $ts, $buffer) = @_;
}

sub audio {
	my($s, $ts, $buffer) = @_;
}

sub payload {
	my($s, $ts, $buffer) = @_;
}

sub complete {
	my($s) = @_;
}

sub parseTS {
	my($s, $buffer) = @_;

	my $ret = {};

	$ret->{sync_byte} = $buffer->getInt();

	my $a = $buffer->getInt();
	my $b = $buffer->getInt();
	$ret->{transport_error_indicator}		= $a >> 7 & 0x01;
	$ret->{payload_unit_start_indicator}	= $a >> 6 & 0x01;
	$ret->{transport_priority}				= $a >> 5 & 0x01;
	$ret->{pid}								= ($a & 0x1F) << 8 | $b;

	my $a = $buffer->getInt();
	$ret->{transport_scrambling_control}	= $a >> 6 & 0x03;
	$ret->{adaptation_field_control}		= $a >> 4 & 0x03;
	$ret->{continuity_counter}				= $a      & 0x0F;

	if ($ret->{adaptation_field_control} & 0x02) {
		$ret->{adaptation_field_length} = $buffer->getInt();
		$buffer->{pos} += $ret->{adaptation_field_length};
	}

	return $ret;
}

sub parsePMT {
	my($s, $buffer) = @_;

	my $ret = {};

	$ret->{pointer_field} = $buffer->getInt();
	$buffer->{pos} += $ret->{pointer_field};

	$ret->{table_id} = $buffer->getInt();

	my $a = $buffer->getInt();
	my $b = $buffer->getInt();
	$ret->{section_syntax_indicator}	= $a >> 7 & 0x01;
	$ret->{private_indicator}			= $a >> 6 & 0x01;
	$ret->{section_length}				= ($a & 0x0F) << 8 | $b;
	my $program_endbyte = $buffer->{pos} + $ret->{section_length};

	$ret->{program_number} = 0;
	$ret->{version_number} = 0;
	$ret->{current_next_indicator} = 0;
	$ret->{section_number} = 0;
	$ret->{last_section_number} = 0;

	if ($ret->{section_syntax_indicator}) {
		$ret->{program_number} = $buffer->getShort();

		my $a = $buffer->getInt();
		$ret->{version_number} = $a >> 1 & 0x1F;
		$ret->{current_next_indicator} = $a & 0x01;

		$ret->{section_number} = $buffer->getInt();
		$ret->{last_section_number} = $buffer->getInt();
	}

	my $a = $buffer->getInt();
	my $b = $buffer->getInt();
	$ret->{PCR_PID} = ($a & 0x1F) << 8 | $b;

	my $a = $buffer->getInt();
	my $b = $buffer->getInt();
	$ret->{program_info_length} = ($a & 0x0F) << 8 | $b;
	my $descriptor_endbyte = $buffer->{pos} + $ret->{program_info_length};

	$ret->{descriptor} = [];

	while ($buffer->{pos} + 2 < $descriptor_endbyte) {
		my $desc = {};

		$desc->{desc_tag} = $buffer->getInt();
		$desc->{desc_length} = $buffer->getInt();
		$desc->{desc_data} = $buffer->getBytes($desc->{desc_length});

		push(@{$ret->{descriptor}}, $desc);
	}

	$ret->{program} = [];

	while ($buffer->{pos} + 5 < $program_endbyte) {
		my $prog = {};

		$prog->{stream_type} = $buffer->getInt();

		my $a = $buffer->getInt();
		my $b = $buffer->getInt();
		$prog->{elementary_PID} = ($a & 0x1F) << 8 | $b;

		my $a = $buffer->getInt();
		my $b = $buffer->getInt();
		$prog->{ES_info_length} = ($a & 0x0F) << 8 | $b;
		my $descriptor_endbyte = $buffer->{pos} + $prog->{ES_info_length};

		$prog->{descriptor} = [];

		while ($buffer->{pos} + 2 < $descriptor_endbyte) {
			my $desc = {};

			$desc->{desc_tag} = $buffer->getInt();
			$desc->{desc_length} = $buffer->getInt();
			$desc->{desc_data} = $buffer->getBytes($desc->{desc_length});

			push(@{$prog->{descriptor}}, $desc);
		}

		push(@{$ret->{program}}, $prog);
	}

	$buffer->{pos} = $program_endbyte;

	return $ret;
}

sub parsePES {
	my($s, $buffer) = @_;

	my $ret = {};

	$ret->{packet_start_code_prefix} = $buffer->getMedium();

	if ($ret->{packet_start_code_prefix} == PES_START_CODE) {

		$ret->{stream_id}						= $buffer->getInt();
		$ret->{PES_packet_length}				= $buffer->getShort();

		my $a = $buffer->getInt();
		$ret->{PES_scrambling_control}			= $a >> 4 & 0x03;
		$ret->{PES_priority}					= $a >> 3 & 0x01;
		$ret->{data_alignment_indicator}		= $a >> 2 & 0x01;
		$ret->{copyright}						= $a >> 1 & 0x01;
		$ret->{original_or_copy}				= $a      & 0x01;

		my $a = $buffer->getInt();
		$ret->{PTS_flags}						= $a >> 7 & 0x01;
		$ret->{DTS_flags}						= $a >> 6 & 0x01;
		$ret->{ESCR_flag}						= $a >> 5 & 0x01;
		$ret->{ES_rate_flag}					= $a >> 4 & 0x01;
		$ret->{DSM_trick_mode_flag}				= $a >> 3 & 0x01;
		$ret->{additional_copy_info_flag}		= $a >> 2 & 0x01;
		$ret->{PES_CRC_flag}					= $a >> 1 & 0x01;
		$ret->{PES_extension_flag}				= $a      & 0x01;

		$ret->{PES_header_data_length}			= $buffer->getInt();

		my $tmpByte = $buffer->{pos} + $ret->{PES_header_data_length};

		if ($ret->{PTS_flags}) {
			my $a = $buffer->getInt();
			my $pts1 = $a >> 1 & 0x07;
			my $a = $buffer->getInt();
			my $b = $buffer->getInt();
			my $pts2 = $a << 7 | $b >> 1 & 0x7F;
			my $a = $buffer->getInt();
			my $b = $buffer->getInt();
			my $pts3 = $a << 7 | $b >> 1 & 0x7F;
			$ret->{pts} = ($pts1 * 32768 * 32768) + ($pts2 * 32768) + $pts3;
		}

		$buffer->{pos} = $tmpByte;

	} else {
		warn "[ERROR] not pes code\n";
	}

	return $ret;
}

1;
