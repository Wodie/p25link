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



my $Verbose;
my %SF;
my $SFBuffer;
my $Header;
my $Flags;
my $VHeader;
my $Sequence = 0;
my $VSilence;



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
	$Data .= $MMDVM::RepeaterID4;
	Sequence();
	$Data .= $Sequence;
	$Data .= chr(0); # Filler to make len = 18
}

sub Sequence {
	if ($Sequence < 255) {
		$Sequence++;
	} else {
		$Sequence = 0;
	}
}

sub AddVoiceFrame {
	my ($TalkGroup, $Buffer) = @_;
print "SF len 0x = " . length($Buffer) . "\n";
P25Link::Bytes_2_HexString($Buffer);

	my $OpCode = ord(substr($Buffer, 0, 1));
	switch ($OpCode) {
		case 0x00 {

		}
		case [0x60] { # Headers data.
			$SF{'Header'} = 0x01;
			Header();
			$Flags = 0x01;
			$SFBuffer = $Header . $Flags . $VHeader . $VSilence;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30, length ($SFBuffer) - 30);
		}
		case [0x61] { # Headers data.
			$SF{'Header'} = 0x02;
			$Flags = 0x02;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22, length ($SFBuffer) - 22);
		}
		# LDU 1
		case [0x62] { # Voice data.
			$Flags = 0x04;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22, length ($SFBuffer) - 22);
		}
		case [0x63] { # Voice data.
			$SF{'VoiceCount'} += 0x02;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14, length ($SFBuffer) - 14);
		}
		case [0x64] { # Voice data.
			$SF{'VoiceCount'} += 0x04;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17, length ($SFBuffer) - 17);
		}
		case [0x65] { # Voice data.
			$SF{'VoiceCount'} += 0x08;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x66] { # Voice data.
			$SF{'VoiceCount'} += 0x10;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x67] { # Voice data.
			$SF{'VoiceCount'} += 0x20;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x68] { # Voice data.
			$SF{'VoiceCount'} += 0x40;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x69] { # Voice data.
			$SF{'VoiceCount'} += 0x80;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x6A] { # Voice data.
			$SF{'VoiceCount'} += 0x100;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17 + 17 + 16, length ($SFBuffer) - 16);
			print "len SFBuffer = " . length($SFBuffer)
		}
		# LDU 2
		case [0x6B] { # Voice data.
			$SF{'VoiceCount'} += 0x200;
			$Flags = 0x08;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22, length ($SFBuffer) - 22);
		}
		case [0x6C] { # Voice data.
			$SF{'VoiceCount'} += 0x400;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14, length ($SFBuffer) - 14);
		}
		case [0x6D] { # Voice data.
			$SF{'VoiceCount'} += 0x800;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17, length ($SFBuffer) - 17);
		}
		case [0x6E] { # Voice data.
			$SF{'VoiceCount'} += 0x1000;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x6F] { # Voice data.
			$SF{'VoiceCount'} += 0x2000;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x70] { # Voice data.
			$SF{'VoiceCount'} += 0x4000;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x71] { # Voice data.
			$SF{'VoiceCount'} += 0x8000;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x72] { # Voice data.
			$SF{'VoiceCount'} += 0x10000;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17 + 17, length ($SFBuffer) - 17);
		}
		case [0x73] { # Voice data.
			$SF{'VoiceCount'} += 0x20000;
			$SFBuffer = substr($SFBuffer, 0, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17 + 17) . $Buffer .
				substr($SFBuffer, 18 + 1 + 30 + 22 + 22 + 14 + 17 + 17 + 17 + 17 + 17 + 17 + 16, length ($SFBuffer) - 16);
			print "len SFBuffer = " . length($SFBuffer) ."\n";
		}
		else {

		}
	}
}



1;