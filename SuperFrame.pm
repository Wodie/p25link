package SuperFrame;
# SuperFrame.pm

use strict;
use warnings;
use Switch;
use Config::IniFiles;
use Term::ANSIColor;

# Local modules:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;



use constant P25Link_ID => 'P25Link' . chr(0x00);

use constant VersionInfo => 1;

# table 1 OpCodes (Tx Low Byte First)
use constant OpSuperFrame => 0x5000;


use constant Header_Size => 18;
use constant Header_Offset => 0;

use constant Flags_Size => 1;
use constant Flags_Offset => Header_Size + Header_Offset;

use constant Header_0x60_Size => 30;
use constant Header_0x60_Offset => Flags_Size + Flags_Offset;
use constant VHeader1 => chr(0xFD) . chr(0x03) . chr(0x60) . chr(0x02) . chr(0x02) .
chr(0x0C) . chr(0x0B) . chr(0x00) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
chr(0x08) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00);
#chr(0x00) . chr(0x02);

use constant Header_0x61_Size => 22;
use constant Header_0x61_Offset => Header_0x60_Size + Header_0x60_Offset;
use constant VHeader2 => chr(0xFD) . chr(0x03) . chr(0x61) . chr(0x00) . chr(0x05) .
chr(0x24) . chr(0x23) . chr(0x22) . chr(0x1F) . chr(0x34) .
chr(0x2E) . chr(0x00) . chr(0x32) . chr(0x05) . chr(0x37) .
chr(0x0A) . chr(0x37) . chr(0x3B) . chr(0x33) . chr(0x14) .
chr(0x00) . chr(0x2A);# . chr(0x09) . chr(0x02);

use constant VHeader => VHeader1 . VHeader2;

use constant Frame_0x62_Size => 22;
use constant Frame_0x62_Offset => Flags_Size + Flags_Offset;
use constant Silence_62 => chr(0xFD) . chr(0x03) . chr(0x62) . chr(0x02) . chr(0x02) .
chr(0x0C) . chr(0x0B) . chr(0x00) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x80) . chr(0x05) . chr(0x73) . chr(0x80) .
chr(0x80) . chr(0x80) . chr(0x40) . chr(0xF0) . chr(0x00) .
chr(0x00) . chr(0x00);# . chr(0x0C) . chr(0x00);


use constant Frame_0x63_Size => 14;
use constant Frame_0x63_Offset => Frame_0x62_Size + Frame_0x62_Offset;
use constant Silence_63 => chr(0xFD) . chr(0x03) . chr(0x63) . chr(0x05) . chr(0x0C) .
chr(0x7F) . chr(0x7F) . chr(0x7F) . chr(0xBF) . chr(0xF3) .
chr(0xFF) . chr(0xFF) . chr(0xFF) . chr(0xFD);# . chr(0x00) .
#chr(0x00);


use constant Frame_0x64_Size => 17;
use constant Frame_0x64_Offset => Frame_0x63_Offset;
use constant Silence_64 => chr(0xFD) . chr(0x03) . chr(0x64) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x08) . chr(0x7A) . chr(0x29) .
chr(0x88) . chr(0xA4) . chr(0x49) . chr(0x06) . chr(0x52) .
chr(0x45) . chr(0x4D);# . chr(0x1A) . chr(0x02);


use constant Frame_0x65_Size => 17;
use constant Frame_0x65_Offset => Frame_0x64_Offset;
use constant Silence_65 => chr(0xFD) . chr(0x03) . chr(0x65) . chr(0x00) . chr(0x00) .
chr(0x05) . chr(0x00) . chr(0x08) . chr(0x0F) . chr(0x7E) .
chr(0x2E) . chr(0x63) . chr(0x9B) . chr(0x01) . chr(0x56) .
chr(0xBA) . chr(0x69);# . chr(0x67) . chr(0x02);


use constant Frame_0x66_Size => 17;
use constant Frame_0x66_Offset => Frame_0x65_Offset;
use constant Silence_66 => chr(0xFD) . chr(0x03) . chr(0x66) . chr(0x00) . chr(0x00) .
chr(0x01) . chr(0x00) . chr(0xB4) . chr(0x74) . chr(0x75) .
chr(0xCE) . chr(0x02) . chr(0xE6) . chr(0x00) . chr(0x02) .
chr(0xE0) . chr(0xE9);# . chr(0x36) . chr(0x02);


use constant Frame_0x67_Size => 17;
use constant Frame_0x67_Offset => Frame_0x66_Offset;
use constant Silence_67 => chr(0xFD) . chr(0x03) . chr(0x67) . chr(0xF9) . chr(0xCD) .
chr(0x53) . chr(0x00) . chr(0x9C) . chr(0x48) . chr(0x0F) .
chr(0x19) . chr(0x3C) . chr(0x1F) . chr(0x00) . chr(0x05) .
chr(0x22) . chr(0x2E);# . chr(0x85) . chr(0x02);


use constant Frame_0x68_Size => 17;
use constant Frame_0x68_Offset => Frame_0x67_Offset;
use constant Silence_68 => chr(0xFD) . chr(0x03) . chr(0x68) . chr(0xBF) . chr(0x68) .
chr(0xA5) . chr(0x00) . chr(0x68) . chr(0x56) . chr(0xF2) .
chr(0x48) . chr(0x26) . chr(0x55) . chr(0x00) . chr(0x04) .
chr(0x85) . chr(0xC4);# . chr(0x36) . chr(0x02);


use constant Frame_0x69_Size => 17;
use constant Frame_0x69_Offset => Frame_0x68_Offset;
use constant Silence_69 => chr(0xFD) . chr(0x03) . chr(0x69) . chr(0xA4) . chr(0xB2) .
chr(0x2B) . chr(0x00) . chr(0xB4) . chr(0x78) . chr(0x6D) .
chr(0xFA) . chr(0x12) . chr(0x96) . chr(0x6C) . chr(0x03) .
chr(0x60) . chr(0x3C);# . chr(0x77) . chr(0x02);


use constant Frame_0x6A_Size => 16;
use constant Frame_0x6A_Offset => Frame_0x69_Offset;
use constant Silence_6A => chr(0xFD) . chr(0x03) . chr(0x6A) . chr(0x00) . chr(0x00) .
chr(0x02) . chr(0xA8) . chr(0x45) . chr(0x99) . chr(0x76) .
chr(0xFA) . chr(0xB0) . chr(0x34) . chr(0x02) . chr(0x3A) .
chr(0xD4);# . chr(0xA6) . chr(0x00);



use constant Frame_0x6B_Size => 22;
use constant Frame_0x6B_Offset => Flags_Offset;
use constant Silence_6B => chr(0xFD) . chr(0x03) . chr(0x6B) . chr(0x02) . chr(0x02) .
chr(0x0C) . chr(0x0B) . chr(0x00) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x80) . chr(0x90) . chr(0x4A) . chr(0xBF) .
chr(0x3D) . chr(0xF2) . chr(0x71) . chr(0x48) . chr(0x02) .
chr(0x0F) . chr(0xAB);# . chr(0x73) . chr(0x00);


use constant Frame_0x6C_Size => 14;
use constant Frame_0x6C_Offset => Frame_0x6B_Offset;
use constant Silence_6C => chr(0xFD) . chr(0x03) . chr(0x6C) . chr(0x90) . chr(0x4C) .
chr(0x82) . chr(0x8E) . chr(0x22) . chr(0x46) . chr(0x58) .
chr(0x21) . chr(0x1C) . chr(0xDA) . chr(0x90);# . chr(0x00) .
#chr(0x00);


use constant Frame_0x6D_Size => 17;
use constant Frame_0x6D_Offset => Frame_0x6C_Offset;
use constant Silence_6D => chr(0xFD) . chr(0x03) . chr(0x6D) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x90) . chr(0x58) . chr(0x2C) .
chr(0xFE) . chr(0xD3) . chr(0x0F) . chr(0x09) . chr(0x03) .
chr(0xB2) . chr(0xF5);# . chr(0x23) . chr(0x02);


use constant Frame_0x6E_Size => 17;
use constant Frame_0x6E_Offset => Frame_0x6D_Offset;
use constant Silence_6E => chr(0xFD) . chr(0x03) . chr(0x6E) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0xA8) . chr(0x51) . chr(0x3F) .
chr(0xEC) . chr(0x21) . chr(0x31) . chr(0x00) . chr(0x00) .
chr(0x3C) . chr(0x61);# . chr(0x96) . chr(0x02);


use constant Frame_0x6F_Size => 17;
use constant Frame_0x6F_Offset => Frame_0x6E_Offset;
use constant Silence_6F => chr(0xFD) . chr(0x03) . chr(0x6F) . chr(0x00) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x90) . chr(0x50) . chr(0x7A) .
chr(0x96) . chr(0x6B) . chr(0xF6) . chr(0x48) . chr(0x01) .
chr(0x5F) . chr(0x9E);# . chr(0xE5) . chr(0x02);


use constant Frame_0x70_Size => 17;
use constant Frame_0x70_Offset => Frame_0x6F_Offset;
use constant Silence_70 => chr(0xFD) . chr(0x03) . chr(0x70) . chr(0x80) . chr(0x00) .
chr(0x00) . chr(0x00) . chr(0x90) . chr(0x4A) . chr(0x9F) .
chr(0x4D) . chr(0x8D) . chr(0x98) . chr(0xC8) . chr(0x02) .
chr(0x15) . chr(0x43);# . chr(0xDE) . chr(0x02);


use constant Frame_0x71_Size => 17;
use constant Frame_0x71_Offset => Frame_0x70_Offset;
use constant Silence_71 => chr(0xFD) . chr(0x03) . chr(0x71) . chr(0xAC) . chr(0xB8) .
chr(0xA4) . chr(0x00) . chr(0xAC) . chr(0x78) . chr(0x77) .
chr(0x4E) . chr(0x84) . chr(0xB3) . chr(0x80) . chr(0x00) .
chr(0x7F) . chr(0x8B);# . chr(0x41) . chr(0x02);


use constant Frame_0x72_Size => 17;
use constant Frame_0x72_Offset => Frame_0x71_Offset;
use constant Silence_72 => chr(0xFD) . chr(0x03) . chr(0x72) . chr(0x9B) . chr(0xDC) .
chr(0x75) . chr(0x00) . chr(0x94) . chr(0x2B) . chr(0xB6) .
chr(0x59) . chr(0xC2) . chr(0x70) . chr(0x88) . chr(0x02) .
chr(0xFC) . chr(0xC8);# . chr(0x70) . chr(0x02);


use constant Frame_0x73_Size => 16;
use constant Frame_0x73_Offset => Frame_0x72_Offset;
use constant Silence_73 => chr(0xFD) . chr(0x03) . chr(0x73) . chr(0x00) . chr(0x00) .
chr(0x02) . chr(0xB4) . chr(0x68) . chr(0x88) . chr(0xFB) .
chr(0xD6) . chr(0xDD) . chr(0x80) . chr(0x03) . chr(0x53) .
chr(0x35);# . chr(0x41) . chr(0x00);

use constant Silence_PDU1 => Silence_62 . Silence_63 . Silence_64 . Silence_65 . Silence_66 .
Silence_67 . Silence_68 . Silence_69 . Silence_6A;

use constant Silence_PDU2 => Silence_6B . Silence_6C . Silence_6D . Silence_6E . Silence_6F .
Silence_70 . Silence_71 . Silence_72 . Silence_73;



my $Verbose;
my %SF;
my $SFH_Buffer;
my $SF_Buffer;
my $Header;
my $Flags;
my $VHeader;
my $Sequence = 0;



##################################################################
# SuperFrame #####################################################
##################################################################
sub Init {
	my ($ConfigFile) = @_;
	# Load Settings ini file.
	print color('green'), "SuperFrame Loading Settings...\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	# Settings:
	$Verbose = $cfg->val('Settings', 'Verbose');
	print "  Verbose = $Verbose\n";
	print "----------------------------------------------------------------------\n";
}

sub Header {
	my $Data = P25Link_ID; # Header ID[8] = "P25Link" . chr(0)
	$Data .= chr(OpSuperFrame & 0xFF) . chr((OpSuperFrame & 0xFF00) >> 8);
	$Data .= chr((VersionInfo & 0xFF00) >> 8); # Firmware Version Hi
	$Data .= chr(VersionInfo & 0xFF); # Firmware Version Lo
	$Data .= DMR::Get_RepeaterID4();
	Sequence();
	$Data .= $Sequence;
	$Data .= chr(0); # Filler to make len = 18
	return $Data;
}

sub Sequence {
	if ($Sequence < 255) {
		$Sequence++;
	} else {
		$Sequence = 0;
	}
}

sub Test {
	my $Buffer = chr(0xFD) . chr(0x03) . chr(0x62);
	for (my $x = 3;$x < Frame_0x62_Size; $x++) {
		$Buffer .= chr($x + 1);
	}
	P25Link::Bytes_2_HexString($Buffer);
	UpdateSuperFrame(1, $Buffer);

	$Buffer = chr(0xFD) . chr(0x03) . chr(0x63);
	for (my $x = 3;$x < Frame_0x63_Size; $x++) {
		$Buffer .= chr($x + 1);
	}
	P25Link::Bytes_2_HexString($Buffer);
	UpdateSuperFrame(1, $Buffer);
}



sub UpdateSuperFrame {
	my ($TalkGroup, $Buffer) = @_;
print "Rx SuperFrame len = " . length($Buffer) . "\n";
P25Link::Bytes_2_HexString($Buffer);
print "\n";
	my $OpCode = ord(substr($Buffer, 2, 1));
	switch ($OpCode) {
		case 0x00 {
			return;
		}
		# Headers
		case [0x60] { # Headers data.
			$SF{'Header'} = 0x01;
			$Flags = chr(0x00);
			$SFH_Buffer = Header() . $Flags . VHeader1 . VHeader2;
			$SFH_Buffer = substr($SFH_Buffer, 0, Header_0x60_Offset) . $Buffer .
				substr($SFH_Buffer, Header_0x60_Offset + Header_0x60_Size, length ($SFH_Buffer) - Header_0x60_Size);
		}
		case [0x61] { # Headers data.
			$SF{'Header'} = 0x02;
			$SFH_Buffer = substr($SFH_Buffer, 0, Header_0x61_Offset) . $Buffer .
				substr($SFH_Buffer, Header_0x61_Offset + Header_0x61_Size, length ($SFH_Buffer) - Header_0x61_Size);
		}
		# LDU 1
		case [0x62] { # Voice data.
			$SF{'VoiceCount'} = 0x01;
			$Flags = chr(0x01);
			$SF_Buffer = Header() . $Flags . Silence_PDU1;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x62_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x62_Offset + Frame_0x62_Size, length($SF_Buffer) - Frame_0x62_Size);
		}
		case [0x63] { # Voice data.
			$SF{'VoiceCount'} += 0x02;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x63_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x63_Offset + Frame_0x63_Size, length($SF_Buffer) - Frame_0x63_Size);
		}
		case [0x64] { # Voice data.
			$SF{'VoiceCount'} += 0x04;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x64_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x64_Offset + Frame_0x64_Size, length($SF_Buffer) - Frame_0x64_Size);
		}
		case [0x65] { # Voice data.
			$SF{'VoiceCount'} += 0x08;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x65_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x65_Offset + Frame_0x65_Size, length($SF_Buffer) - Frame_0x65_Size);
		}
		case [0x66] { # Voice data.
			$SF{'VoiceCount'} += 0x10;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x66_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x66_Offset + Frame_0x66_Size, length($SF_Buffer) - Frame_0x66_Size);
		}
		case [0x67] { # Voice data.
			$SF{'VoiceCount'} += 0x20;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x67_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x67_Offset + Frame_0x67_Size, length($SF_Buffer) - Frame_0x67_Size);
		}
		case [0x68] { # Voice data.
			$SF{'VoiceCount'} += 0x40;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x68_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x68_Offset + Frame_0x68_Size, length($SF_Buffer) - Frame_0x68_Size);
		}
		case [0x69] { # Voice data.
			$SF{'VoiceCount'} += 0x80;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x69_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x69_Offset + Frame_0x69_Size, length($SF_Buffer) - Frame_0x69_Size);
		}
		case [0x6A] { # Voice data.
			$SF{'VoiceCount'} += 0x100;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x6A_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x6A_Offset + Frame_0x6A_Size, length($SF_Buffer) - Frame_0x6A_Size);
			print "len SFBuffer = " . length($SF_Buffer);


#			send $SFH_Buffer;
			P25Link::Tx($TalkGroup, $SFH_Buffer);
#			send $SF_Buffer;
			P25Link::Tx($TalkGroup, $SF_Buffer);


		}
		# LDU 2
		case [0x6B] { # Voice data.
			$SF{'VoiceCount'} = 0x01;
			$Flags = chr(0x02);
			$SF_Buffer = Header() . $Flags . Silence_PDU2;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x6B_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x6B_Offset + Frame_0x6B_Size, length ($SF_Buffer) - Frame_0x6B_Size);
		}
		case [0x6C] { # Voice data.
			$SF{'VoiceCount'} += 0x02;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x6C_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x6C_Offset + Frame_0x6C_Size, length ($SF_Buffer) - Frame_0x6C_Size);
		}
		case [0x6D] { # Voice data.
			$SF{'VoiceCount'} += 0x04;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x6D_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x6D_Offset + Frame_0x6D_Size, length ($SF_Buffer) - Frame_0x6D_Size);
		}
		case [0x6E] { # Voice data.
			$SF{'VoiceCount'} += 0x08;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x6E_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x6E_Offset + Frame_0x6E_Size, length ($SF_Buffer) - Frame_0x6E_Size);
		}
		case [0x6F] { # Voice data.
			$SF{'VoiceCount'} += 0x10;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x6F_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x6F_Offset + Frame_0x6F_Size, length ($SF_Buffer) - Frame_0x6F_Size);
		}
		case [0x70] { # Voice data.
			$SF{'VoiceCount'} += 0x20;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x70_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x70_Offset + Frame_0x70_Size, length ($SF_Buffer) - Frame_0x70_Size);
		}
		case [0x71] { # Voice data.
			$SF{'VoiceCount'} += 0x40;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x71_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x71_Offset + Frame_0x71_Size, length ($SF_Buffer) - Frame_0x71_Size);
		}
		case [0x72] { # Voice data.
			$SF{'VoiceCount'} += 0x80;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x72_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x72_Offset + Frame_0x72_Size, length ($SF_Buffer) - Frame_0x72_Size);
		}
		case [0x73] { # Voice data.
			$SF{'VoiceCount'} += 0x100;
			$SF_Buffer = substr($SF_Buffer, 0, Frame_0x73_Offset) . $Buffer .
				substr($SF_Buffer, Frame_0x73_Offset + Frame_0x73_Size, length ($SF_Buffer) - Frame_0x73_Size);
			print "len SF_Buffer = " . length($SF_Buffer) ."\n";

#			send $SF_Buffer;
			P25Link::Tx($TalkGroup, $SF_Buffer);

		}
		else {

		}
	}

	P25Link::Bytes_2_HexString($SF_Buffer);

}




sub To_HDLC {
	my ($Buffer) = @_;

	$Buffer = substr($Buffer, 7, length($Buffer) - 7); # Here we remove Cisco STUN.

	if (substr($Buffer, 0, 8) ne P25Link_ID) {
		print "Bad SF Header Rx.\n";
		return;
	}
	if (substr($Buffer, Header_Size, 1) == 0x00) { # Header
		SF_to_HDLC(substr($Buffer, Header_0x60_Offset, Header_0x60_Size));
		SF_to_HDLC(substr($Buffer, Header_0x61_Offset, Header_0x61_Size));
	} elsif (substr($Buffer, Header_Size, 1) == 0x01) { # PDU1
		SF_to_HDLC(substr($Buffer, Frame_0x62_Offset, Frame_0x62_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x63_Offset, Frame_0x63_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x64_Offset, Frame_0x64_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x65_Offset, Frame_0x65_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x66_Offset, Frame_0x66_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x67_Offset, Frame_0x67_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x68_Offset, Frame_0x68_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x69_Offset, Frame_0x69_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x6A_Offset, Frame_0x6A_Size));
	} elsif (substr($Buffer, Header_Size, 1) == 0x02) { # PDU 2
		SF_to_HDLC(substr($Buffer, Frame_0x6B_Offset, Frame_0x6B_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x6C_Offset, Frame_0x6C_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x6D_Offset, Frame_0x6D_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x6E_Offset, Frame_0x6E_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x6F_Offset, Frame_0x6F_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x70_Offset, Frame_0x70_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x71_Offset, Frame_0x71_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x72_Offset, Frame_0x72_Size));
		SF_to_HDLC(substr($Buffer, Frame_0x73_Offset, Frame_0x73_Size));
	}
	die "Fatal error\n";
}

sub SF_to_HDLC { # P25Link packet contains Cisco STUN and Quantar packet.
	my ($Buffer) = @_;
	if (Packets::GetLocalActive() == 1) {
		return;
	}
#	$Buffer = substr($Buffer, 7, length($Buffer)); # Here we remove Cisco STUN.
	Quantar::SetHDLC_TxTraffic(1);
	Quantar::HDLC_Tx($Buffer, 1);
#	if (ord(substr($Buffer, 2, 1)) eq 0x00 and
#		ord(substr($Buffer, 3, 1)) eq 0x02 and
#		ord(substr($Buffer, 5, 1)) eq Quantar::C_EndTx and
#		ord(substr($Buffer, 6, 1)) eq Quantar::C_DVoice
#	) {
#		if ($Verbose) { print color('green'), "Network Tail_P25Link\n", color('reset'); }
#		if ($UseRemoteCourtesyTone) {
#			$Packets::Pending_CourtesyTone = 2;
#		}
#	}
#Qunatar::SetPrevFrame($Buffer);
# Add a 1s timer to Quantar::SetHDLC_TxTraffic(0);
;
}






sub GetSuperFrame {
	return($SF_Buffer);

}


1;