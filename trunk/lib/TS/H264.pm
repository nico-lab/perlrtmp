package TS::H264;

use strict;
use BitStream;
use Scalar::Util qw(weaken);

use constant H264_START_CODE_LENGTH => 4;
use constant H264_START_CODE => pack('H*', '00000001');
use constant H264_PREVENT_3_BYTE => pack('H*', '000003');
use constant H264_NAL_TYPE_NON_IDR_SLICE => 0x01;
use constant H264_NAL_TYPE_IDR_SLICE => 0x05;
use constant H264_NAL_TYPE_SEI => 0x06;
use constant H264_NAL_TYPE_SEQ_PARAM => 0x07;
use constant H264_NAL_TYPE_PIC_PARAM => 0x08;
use constant H264_NAL_TYPE_ACCESS_UNIT => 0x09;
use constant H264_NAL_TYPE_FILLER_DATA => 0x0C;

use constant EXP_GOLOMB_BITS => [
	8, 7, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 3, 
	3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
	1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 
];

sub new {
	my($pkg, $buffer) = @_;

	my $hash = {
		buffer => $buffer,
		frames => [],
	};

	my $s = bless $hash, $pkg;

	weaken($s->{buffer});
	$s->parse();

	return $s;
}

sub parse {
	my($s) = @_;

	my $seq_param = '';
	my $pic_param = '';
	my $keyframe = 0;
	my $put = Binary->new();

	while($s->{buffer}->{pos} < $s->{buffer}->{length}) {

		my $buffer = $s->{buffer}->clone();

		my $find = $s->find_start_code($buffer);
		$buffer->{pos} = $find + H264_START_CODE_LENGTH;

		my $next = $s->find_start_code($buffer);

		if ($next == -1) {
			$next = $buffer->{length};
		}

		my $length = $next - $buffer->{pos};
		my $buf = $buffer->getBytes($length);

		my $a = vec($buf, 0, 8);
		my $nal_unit_type = $a & 0x1F;

		if ($nal_unit_type == H264_NAL_TYPE_ACCESS_UNIT) {

			$seq_param = '';
			$pic_param = '';
			$keyframe = 0;
			$put = Binary->new();

			my $a = vec($buf, 1, 8);

			if (($a & 0x20) == 0) {
				$keyframe = 1;
			}

			# for PS3
			# $put->setLong($length);
			# $put->setBytes($buf);
		} elsif ($nal_unit_type == H264_NAL_TYPE_SEI) {
			$put->setLong($length);
			$put->setBytes($buf);
		} elsif ($nal_unit_type == H264_NAL_TYPE_NON_IDR_SLICE || $nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {
			$put->setLong($length);
			$put->setBytes($buf);

			my $frame = {
				seq_param => $seq_param,
				pic_param => $pic_param,
				keyframe => $keyframe,
				buf => $put->{buf},
			};

			push(@{$s->{frames}}, $frame);
		} elsif ($nal_unit_type == H264_NAL_TYPE_SEQ_PARAM) {
			$seq_param = $buf;
		} elsif ($nal_unit_type == H264_NAL_TYPE_PIC_PARAM) {
			$pic_param = $buf;
		} elsif ($nal_unit_type == H264_NAL_TYPE_FILLER_DATA) {
		} else {
			warn "[NOTICE] no support nal unit type: $nal_unit_type\n";
		}

		$s->{buffer}->{pos} = $buffer->{pos};
	}
}

sub find_start_code {
	my($s, $buffer) = @_;
	return index($buffer->{buf}, H264_START_CODE, $buffer->{pos});
}

sub parseSequence {
	my($buf) = @_;

	my $b = BitStream->new($buf);

	my $ref_idc_unit_type = $b->getBits(8);
	my $profile = $b->getBits(8);
	my $constaint_set0_flag = $b->getBits(1);
	my $constaint_set1_flag = $b->getBits(1);
	my $constaint_set2_flag = $b->getBits(1);
	my $constaint_set3_flag = $b->getBits(1);
	$b->getBits(4);
	my $level_idc = $b->getBits(8);
	my $seq_parameter_set_id = &h264_ue($b);
	my $log2_max_frame_num_minus4 = &h264_ue($b);
	my $pic_order_cnt_type = &h264_ue($b);

	if ($pic_order_cnt_type == 0) {
		my $log2_max_pic_order_cnt_lsb_minus4 = &h264_ue($b);
	} elsif ($pic_order_cnt_type == 1) {
		my $delta_pic_order_always_zero_flag = $b->getBits(1);
		my $offset_for_non_ref_pic = &h264_se($b);
		my $offset_for_top_to_bottom_field = &h264_se($b);
		my $temp = &h264_ue($b);

		for (my $ix = 0; $ix < $temp; $ix++) {
			my $offset_for_ref_frame = &h264_se($b);
		}
	}

	my $num_ref_frames = &h264_ue($b);
	my $gaps_in_frame_num_value_allowed_flag = $b->getBits(1);
	my $PicWidthInMbs = &h264_ue($b) + 1;
	my $derived_width = $PicWidthInMbs * 16;

	my $PicHeightInMapUnits = &h264_ue($b) + 1;
	my $frame_mbs_only_flag = $b->getBits(1);
	my $derived_height = (2 - $frame_mbs_only_flag) * $PicHeightInMapUnits * 16;

	if (!$frame_mbs_only_flag) {
		my $mb_adaptive_frame_field_flag = $b->getBits(1);
	}

	my $direct_8x8_inference_flag = $b->getBits(1);
	my $frame_cropping_flag = $b->getBits(1);

	if ($frame_cropping_flag) {
		my $frame_crop_left_offset = &h264_ue($b);
		my $frame_crop_right_offset = &h264_ue($b);
		my $frame_crop_top_offset = &h264_ue($b);
		my $frame_crop_bottom_offset = &h264_ue($b);

		$derived_width -= $frame_crop_left_offset * 2;
		$derived_width -= $frame_crop_right_offset * 2;
		$derived_height -= $frame_crop_top_offset * 2;
		$derived_height -= $frame_crop_bottom_offset * 2;
	}

	my $seq = {
		width => $derived_width,
		height => $derived_height,
	};

	return $seq;
}

sub h264_ue {
	my($b) = @_;

	my $read;
	my $bits = 0;

	while(1) {
		my $bits_left = $b->bits_remain();

		if ($bits_left < 8) {
			$read = $b->peekBits($bits_left) << (8 - $bits_left);
			last;
		} else {
			$read = $b->peekBits(8);

			if ($read == 0) {
				$b->getBits(8);
				$bits += 8;
			} else {
				last;
			}
		}
	}

	my $coded = EXP_GOLOMB_BITS->[$read];
	$b->getBits($coded);
	$bits += $coded;

	return $b->getBits($bits + 1) - 1;
}

sub h264_se {
	my($b) = @_;

	my $ret = &h264_ue($b);

	if (($ret & 0x1) == 0) {
		$ret >>= 1;
		my $temp = 0 - $ret;
		return $temp;
	}

	return ($ret + 1) >> 1;
}

1;
