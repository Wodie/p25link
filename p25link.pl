#!/usr/bin/perl
#
# To do:
# Implement Reed-Solomon functions.
# Add Golay functions.
# Implement Golay functions.
# Test Page with encoders.
# Implement IPv6 UDP.
# Implement IPv6 Multicast.
# Implement SuperFrame.
# Implement Base station mode.
# Test TG scanning.
# Allow/block encryption.
# Proxy of v.24 frames, only the IMBE data should be passed to the Quantar. Done
# control data should be stripped out. Done
# - prevents channel changes.
# Local ID black-list.
# Implement DTMF.
# Fix LocalTx flag.

# Strict and warnings recommended.
use strict;
use warnings;
use diagnostics;
use Switch;
use Config::IniFiles;
use Time::HiRes qw(nanosleep);
#use Data::Dumper qw(Dumper);

#use RPi::Pin;
#use RPi::Const qw(:all);
#use Date::Calc qw(check_date Today Date_to_Time Add_Delta_YM Mktime);
use Term::ReadKey;
use Term::ANSIColor;

use Config;
$Config{useithreads} or
	die('Recompile Perl with threads to run this program.');
# Threads
BEGIN {
	if ($Config{useithreads}) {
		# We have threads
#		require MyMod_threaded;
#		import MyMod_threaded;
	} else {
#		require MyMod_unthreaded;
#		import MyMod_unthreaded;
	}
}

# Local files:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom versions:
use FAP;
use APRS_IS;
use CiscoSTUN;
use Serial;
use Quantar;
use Recorder;
use MMDVM;
use P25Link;
use P25NX;
use RDAC;
use DMR;
use Packets;
#use RS;
#use Golay2087;
#use Golay24128;
#use Hamming;
#use RS129;
#use RS241213;
#use P25Utils;
#use P25Control;
#use P25Data;
#use P25LowSpeedData;
#use P25NID;
#use P25Trellis;
#use P25Audio;
#use AMBEFEC;



# About this app.
my $AppName = 'P25Link';
use constant VersionInfo => 2;
use constant MinorVersionInfo => 40;
use constant RevisionInfo => 6;
my $Version = VersionInfo . '.' . MinorVersionInfo . '-' . RevisionInfo;
(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();
my $StartTime = "$hour:$min:$sec";
print "Started at $StartTime\n";
print "\n##################################################################\n";
print "	*** $AppName v$Version ***\n";
print "	Released: Mar 06, 2023. Created October 17, 2019.\n";
print "	Created by:\n";
print "	Juan Carlos Perez De Castro (Wodie) KM4NNO / XE1F\n";
print "	Bryan Fields W9CR.\n";
print "	p25.link\n";
print "	www.wodielite.com\n";
print "	wodielite at mac.com\n";
print "	km4nno at yahoo.com\n\n";
print "	License:\n";
print "	This software is licenced under the GPL v3.\n";
print "	If you are using it, please let me know, I will be glad to know it.\n\n";
print "	This project is based on the work and information from:\n";
print "	Juan Carlos PŽrez KM4NNO / XE1F\n";
print "	Byan Fields W9CR\n";
print "	P25-MMDVM creator Jonathan Naylor G4KLX\n";
print "	P25NX creatorDavid Kraus NX4Y\n";
print "	David Kierzkowski KD8EYF\n";
print "	APRS is a registed trademark and creation of Bob Bruninga WB4APR\n";
print "\n##################################################################\n\n";
#nanosleep(3.0 * 1000000000.0);

# System info:
print color('green'), "System Info:\n", color('reset');
# Detect Target OS.
my $OS = $^O;
print "  Current OS: $OS\n";
print "  Perl version: $]\n";
print "  AppName: $0\n";
my $ConfigFile;
my $UserNum = 0;
($ConfigFile = "/opt/p25link/config.ini", $UserNum = 0) = @ARGV;
print "  Arguments: $ConfigFile\n";
#print "ARGV @ARGV\n";

if ($ConfigFile eq "" or $ConfigFile eq undef) {
	$ConfigFile = "/opt/p25link/config.ini";
	print "Config File = $ConfigFile\n";
}
print "----------------------------------------------------------------------\n";

Packets::Load_Settings($ConfigFile);

my $Verbose = 1;
my $VerboseValue = 1;
# Quantar
my $LoopOldTime = P25Link::GetTickCount();

print "----------------------------------------------------------------------\n";



# Voice Announce.
my $SpeechFile;
my $SpeechIni;
my @Speech_Zero;
my @Speech_One;
my @Speech_Two;
my @Speech_Three;
my @Speech_Four;
my @Speech_Five;
my @Speech_Six;
my @Speech_Seven;
my @Speech_Eight;
my @Speech_Nine;
my @Speech_Local;
my @Speech_WW;
my @Speech_WWTac1;
my @Speech_WWTac2;
my @Speech_WWTac3;
my @Speech_NA;
my @Speech_NATac1;
my @Speech_NATac2;
my @Speech_NATac3;
my @Speech_Europe;
my @Speech_EuTac1;
my @Speech_EuTac2;
my @Speech_EuTac3;
my @Speech_France;
my @Speech_Germany;
my @Speech_Pacific;
my @Speech_PacTac1;
my @Speech_PacTac2;
my @Speech_PacTac3;

my @Speech_Alarm;
my @Speech_CTone1;
my @Speech_CTone2;
my @Speech_QuindarToneStart;
my @Speech_QuindarToneEnd;
my @Speech_3Up;
my @Speech_BeeBoo;
my @Speech_BumbleBee;
my @Speech_Nextel;
my @Speech_RC210_9;
my @Speech_RC210_10;
my @Speech_LoBat1;
my @Speech_LoBat2;
my @Speech_CustomCTone;

my @Speech_SystemStartP25NX;
my @Speech_WellcomeToP25DotLink;
my @Speech_DefaultRevert;
my @Speech_FSG_2050;
my @Speech_Wave_4095;

my @Speech_TestPattern;

my $VA_Test;
print "----------------------------------------------------------------------\n";



#RS::Init();
#RS::test();

#die("testing.");

# Class
#	my $P25Object = new P25Control("Juan", "Perez", 293, "123456");
#	my $firstName = $P25Object->getFirstName();
#	print "  Before Setting First Name is : $firstName\n";
#	$P25Object->setFirstName("Carlos");
#	$firstName = $P25Object->getFirstName();
#	print "  After Setting First Name is : $firstName\n";

#	my $ID = $P25Object->getID();
#	print "  Before Setting ID is : $ID\n";
#	$P25Object->setID("310999");
#	$ID = $P25Object->getID();
#	print "  After Setting ID is : $ID\n";


#	my $P25Object2 = new P25Control("Pali", "Pan", 293, "000000");
#	my $firstName2 = $P25Object2->getFirstName();
#	print "  Before Setting First Name is : $firstName2\n";
#	$P25Object2->setFirstName("Yo");
#	$firstName2 = $P25Object2->getFirstName();
#	print "  After Setting First Name is : $firstName2\n";

#	my $ID2 = $P25Object2->getID();
#	print "  Before Setting ID2 is : $ID2\n";
#	$P25Object2->setID("310999");
#	$ID = $P25Object2->getID();
#	print "  After Setting ID2 is : $ID2\n";



#die("\ntesting.\n");
print "----------------------------------------------------------------------\n";



Recorder::Init($ConfigFile);

RDAC::Init($ConfigFile, VersionInfo, MinorVersionInfo, RevisionInfo);

MMDVM::Init($ConfigFile);

DMR::Init($ConfigFile);

P25Link::Init($ConfigFile);

P25NX::Init($ConfigFile);

Quantar::Init($ConfigFile);

APRS_IS::Init($ConfigFile, $AppName, $Version);

if ($Packets::Mode == 0) {
	Serial::Init($ConfigFile);
} elsif ($Packets::Mode == 1) {
	CiscoSTUN::Init($ConfigFile);
}

Load_VoiceAnnounce($ConfigFile);

# Connect to Priority and scan TGs.
Packets::InitScanList();

# Prepare Startup VA Message.
$Packets::VA_Message = 0xFFFF11; # 0 = Welcome to P25Link.
$Packets::Pending_VA = 1; # Let the system know we wish a Voice Announce when possible.



# Raspberry Pi GPIO
#my $ResetPicPin = RPi::Pin->new(4, "Reset PIC");
#my $Pin5 = RPi::Pin->new(5, "PTT");
#my $Pin5 = RPi::Pin->new(6, "COS");
# This use the BCM pin numbering scheme. 
# Valid GPIOs are: 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27.
# GPIO 2, 3 Aleternate for I2C.
# GPIO 14, 15 alternate for USART.
#$ResetPicPin->mode(OUTPUT);
#$Pin5->write(HIGH);
#$pin->set_interrupt(EDGE_RISING, 'main::Pin5_Interrupt_Handler');



# Threads
#use Config;
#$Config{useithreads} or die('Recompile Perl with threads to run this program.');

#use threads;
#use threads::shared;

#my $Value :shared = 10;
#my $Value = 10;
#print "Tick 1 " . P25Link::GetTickCount() . "\n";
#print "Value = $Value\n";
#my $thread1 = threads->create(\&thrsub1, "Test 1");

#print "Next\n";
#nanosleep(1.0 * 1000000000.0);
#print "Value = $Value\n";
#print "Tick 2 " . P25Link::GetTickCount() . "\n";
#my ($result) = $thread1->join(); # Get data if complete, or will halt until it finish.
#print "result is $result\n";
#print "Tick 3 " . P25Link::GetTickCount() . "\n";
#print "Value = $Value\n";



#sub thrsub1 {
#	my ($message) = @_;
#	$Value = 20;
#	print("\nIn the thread, message is: $message\n\n");
#	return("answer");
#	}
#}


print "----------------------------------------------------------------------\n";



# Read Keys:
if ($Packets::HotKeys) {
	ReadMode 3;
	PrintMenu();
}
print "----------------------------------------------------------------------\n";



# Misc
my $Run = 1;
my $PacketCount = 0;

my $TestBuffer = "";
my $TestValue = 0x00;


###################################################################
# MAIN ############################################################
###################################################################
if ($Packets::Mode == 0) { # If Serial (Mode 0) is selected: 
	MainLoop();
} elsif ($Packets::Mode == 1) { # If Cisco STUN (Mode 1) is selected:
	if ($Verbose) {print "Cisco STUN listen for connections:\n";}
	while ($Run) {
		if (CiscoSTUN::Open()) {
			print "P25Link Loop running.\n";
			MainLoop();
		} else {
			HotKeys(); # Keystrokes events.
		}
	}
	CiscoSTUN::Disconnect();
}
# Program exit:
print "----------------------------------------------------------------------\n";
ReadMode 0; # Set keys back to normal State.
if ($Packets::Mode == 0) { # Close Serial Port:
	Serial::Close();
} elsif ($Packets::Mode == 1) {
	CiscoSTUN::Disconnect();
}
APRS_IS::Disconnect();
Packets::Disconnect();
#P25Link::DisconnectIPv6();
DMR::Close(1);

print "Good bye cruel World.\n\a";
print "----------------------------------------------------------------------\n\n";
exit;



##################################################################
# Menu ###########################################################
##################################################################
sub PrintMenu {
	print "Shortcuts menu:\n";
	print "  Q/q = Quit                       \n";
	print "  A = APRS verbose                 a = APRS file reload and Tx\n";
	print "  B =                              b = Voice Announce file reload\n";
	print "  C = Cisco STUN verbose           c = \n";
	print "  D =                              d = DMR show/hide verbose\n";
	print "  E = Emergency Page/Alarm         e = Play Alarm\n";
	print "  F = Serach user test                 \n";
	print "  G =                              g = \n";
	print "  H = HDLC verbose                 h = Help...\n";
	print "  I =                                  \n";
	print "  J = JSON verbose                     \n";
	print "  K =                                  \n";
	print "  L = P25Link verbose                  \n";
	print "  M = MMDVM verbose                    \n";
	print "  N = P25NX verbose                    \n";
	print "  O =                                  \n";
	print "  P = P25NX verbose                    \n";
	print "  Q = Qantar verbose               q = Quit.\n";
	print "  R = RDAC verbose                     \n";
	print "  S = Serial verbose                   \n";
	print "  V = Voice anounce test           v = \n";
	print "  Z = All verbose Off                  \n";
	print "\nStartTime $StartTime\n";
}



#################################################################################
# Voice Announce ################################################################
#################################################################################
sub Load_VoiceAnnounce {
	my ($ConfigFile) = @_;
	# Voice Announce.
	print color('green'), "Loading voice announcements...\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$SpeechFile = $cfg->val('Settings', 'SpeechFile');
	print "  File = $SpeechFile\n";
	$SpeechIni = Config::IniFiles->new( -file => $SpeechFile);
	@Speech_Zero = $SpeechIni->val('Zero', 'byte');
	@Speech_One = $SpeechIni->val('One', 'byte');
	@Speech_Two = $SpeechIni->val('Two', 'byte');
	@Speech_Three = $SpeechIni->val('Three', 'byte');
	@Speech_Four = $SpeechIni->val('Four', 'byte');
	@Speech_Five = $SpeechIni->val('Five', 'byte');
	@Speech_Six = $SpeechIni->val('Six', 'byte');
	@Speech_Seven = $SpeechIni->val('Seven', 'byte');
	@Speech_Eight = $SpeechIni->val('Eight', 'byte');
	@Speech_Nine = $SpeechIni->val('Nine', 'byte');
	@Speech_Local = $SpeechIni->val('Local', 'byte');
	@Speech_WW = $SpeechIni->val('WW', 'byte');
	@Speech_WWTac1 = $SpeechIni->val('WWTac1', 'byte');
	@Speech_WWTac2 = $SpeechIni->val('WWTac2', 'byte');
	@Speech_WWTac3 = $SpeechIni->val('WWTac3', 'byte');
	@Speech_NA = $SpeechIni->val('NA', 'byte');
	@Speech_NATac1 = $SpeechIni->val('NATac1', 'byte');
	@Speech_NATac2 = $SpeechIni->val('NATac2', 'byte');
	@Speech_NATac3 = $SpeechIni->val('NATac3', 'byte');
	@Speech_Europe = $SpeechIni->val('Europe', 'byte');
	@Speech_EuTac1 = $SpeechIni->val('EuTac1', 'byte');
	@Speech_EuTac2 = $SpeechIni->val('EuTac2', 'byte');
	@Speech_EuTac3 = $SpeechIni->val('EuTac3', 'byte');
	@Speech_France = $SpeechIni->val('France', 'byte');
	@Speech_Germany = $SpeechIni->val('Germany', 'byte');
	@Speech_Pacific = $SpeechIni->val('Pacific', 'byte');
	@Speech_PacTac1 = $SpeechIni->val('PacTac1', 'byte');
	@Speech_PacTac2 = $SpeechIni->val('PacTac2', 'byte');
	@Speech_PacTac3 = $SpeechIni->val('PacTac3', 'byte');

	@Speech_Alarm = $SpeechIni->val('Alarm', 'byte');
	@Speech_CTone1 = $SpeechIni->val('CTone1', 'byte');
	@Speech_CTone2 = $SpeechIni->val('CTone2', 'byte');
	@Speech_QuindarToneStart = $SpeechIni->val('QuindarToneStart', 'byte');
	@Speech_QuindarToneEnd = $SpeechIni->val('QuindarToneEnd', 'byte');
	@Speech_3Up = $SpeechIni->val('3Up', 'byte');
	@Speech_BeeBoo = $SpeechIni->val('BeeBoo', 'byte');
	@Speech_BumbleBee = $SpeechIni->val('BumbleBee', 'byte');
	@Speech_Nextel = $SpeechIni->val('Nextel', 'byte');
	@Speech_RC210_9 = $SpeechIni->val('RC210_9', 'byte');
	@Speech_RC210_10 = $SpeechIni->val('RC210_10', 'byte');
	@Speech_LoBat1 = $SpeechIni->val('LoBat1', 'byte');
	@Speech_LoBat2 = $SpeechIni->val('LoBat2', 'byte');
	@Speech_CustomCTone = $SpeechIni->val('customCTone', 'byte');

	@Speech_SystemStartP25NX = $SpeechIni->val('SystemStartP25NX', 'byte');
	@Speech_WellcomeToP25DotLink = $SpeechIni->val('WellcomeToP25DotLink', 'byte');
	@Speech_DefaultRevert = $SpeechIni->val('DefaultRevert', 'byte');
	@Speech_FSG_2050 = $SpeechIni->val('FSG_2050', 'byte');
	@Speech_Wave_4095 = $SpeechIni->val('Wave_4095', 'byte');

	@Speech_TestPattern = $SpeechIni->val('TestPattern', 'byte');

	$VA_Test = 0xFFFF;
	print "  Done.\n";
	print "----------------------------------------------------------------------\n";

}



sub SaySomething {
	my ($ThingToSay) = @_;
	my @Speech;
	if ($Verbose) {print color('green'), "Voice Announcement: ", color('reset');}
	Quantar::SetHDLC_TxTraffic(1);
	switch ($ThingToSay) {
		case 0x00 {
			;#@Speech = NONE;
		}
		case 0x01 {
			print "1 Speech_Local";
			@Speech = @Speech_Local;
		}
		case 0x02 {
			print "2 Speech_Two";
			@Speech = @Speech_Two;
		}
		case 0x03 {
			print "3 Speech_Three";
			@Speech = @Speech_Three;
		}
		case 0x04 {
			print "4 Speech_Four";
			@Speech = @Speech_Four;
		}
		case 0x05 {
			print "5 Speech_Five";
			@Speech = @Speech_Five;
		}
		case 0x06 {
			print "6 Speech_Six";
			@Speech = @Speech_Six;
		}
		case 0x07 {
			print "7 Speech_Seven";
			@Speech = @Speech_Seven;
		}
		case 0x08 {
			print "8 Speech_Eight";
			@Speech = @Speech_Eight;
		}
		case 0x09 {
			print "9 Speech_Nine";
			@Speech = @Speech_Nine;
		}
		case 2050 {
			print "2050 Speech_FSG_2050";
			@Speech = @Speech_FSG_2050;
		}
		case 4095 {
			print "4095 Speech_Wave_4095";
			@Speech = @Speech_Wave_4095;
		}
		case 10100 {
			print "10100 Speech_WW";
			@Speech = @Speech_WW;
		}
		case 10101 {
			print "10101 Speech_WWTac1";
			@Speech = @Speech_WWTac1;
		}
		case 10102 {
			print "10102 Speech_WWTac2";
			@Speech = @Speech_WWTac2;
		}
		case 10103 {
			print "10103 Speech_WWTac3";
			@Speech = @Speech_WWTac3;
		}
		case 10200 {
			print "10200 Speech_NA";
			@Speech = @Speech_NA;
		}
		case 10201 {
			print "10201 Speech_NATac1";
			@Speech = @Speech_NATac1;
		}
		case 10202 {
			print "10202 Speech_NATac2";
			@Speech = @Speech_NATac2;
		}
		case 10203 {
			print "10203 Speech_NATac3";
			@Speech = @Speech_NATac3;
		}
		case 10300 {
			print "10300 Speech_Europe";
			@Speech = @Speech_Europe;
		}
		case 10301 {
			print "10301 Speech_EuTac1";
			@Speech = @Speech_EuTac1;
		}
		case 10302 {
			print "10302 Speech_EuTac2";
			@Speech = @Speech_EuTac2;
		}
		case 10303 {
			print "10303 Speech_EuTac3";
			@Speech = @Speech_EuTac3;
		}
		case 10310 {
			print "10310 Speech_France";
			@Speech = @Speech_France;
		}
		case 10320 {
			print "10320 Speech_Germany";
			@Speech = @Speech_Germany;
		}
		case 10400 {
			print "10400 Speech_Pacific";
			@Speech = @Speech_Pacific;
		}
		case 10401 {
			print "10401 Speech_PacTac1";
			@Speech = @Speech_PacTac1;
		}
		case 10402 {
			print "10402 Speech_PacTac2";
			@Speech = @Speech_PacTac2;
		}
		case 10403 {
			print "10403 Speech_PacTac3";
			@Speech = @Speech_PacTac3;
		}

		case 10500 {
			print "10500 Speech_WW";
			@Speech = @Speech_WW;
		}
		case 10501 {
			print "10403 Speech_NA";
			@Speech = @Speech_NA;
		}
		
		case 0xFFFF {
			print "65535 System Call";
#			@Speech = @Speech_Alarm;
		}
		
		case 0xFFFF00 {
			print "0 Alarm";
			@Speech = @Speech_Alarm;
		}
		case 0xFFFF01 {
			print "1 Speech_3Up";
			@Speech = @Speech_3Up;
		}
		case 0xFFFF02 {
			print "2 Speech_BeeBoo";
			@Speech = @Speech_BeeBoo;
		}
		case 0xFFFF03 {
			print "3 Speech_BumbleBee";
			@Speech = @Speech_BumbleBee;
		}
		case 0xFFFF04 {
			print "4 Speech_Nextel";
			@Speech = @Speech_Nextel;
		}
		case 0xFFFF05 {
			print "5 Speech_RC210_9";
			@Speech = @Speech_RC210_9;
		}
		case 0xFFFF06 {
			print "6 Speech_RC210_10";
			@Speech = @Speech_RC210_10;
		}
		case 0xFFFF07 {
			print "7 Speech_QuindarToneStart";
			@Speech = @Speech_QuindarToneStart;
		}
		case 0xFFFF08 {
			print "8 Speech_QuindarToneEnd";
			@Speech = @Speech_QuindarToneEnd;
		}
		case 0xFFFF09 {
			print "9 Speech_CustomTone";
			@Speech = @Speech_CustomCTone;
		}

		case 0xFFFF11 {
			print "1 Speech_WellcomeToP25DotLink";
			@Speech = @Speech_WellcomeToP25DotLink;
		}
		case 0xFFFF12 {
			print "2 Speech_SystemStartP25NX";
			@Speech = @Speech_SystemStartP25NX;
		}
		case 0xFFFF13 {
			print "3 Speech_DefaultRevert";
			@Speech = @Speech_DefaultRevert;
		}

		case 0xFFFF20 {
			print "0 Speech_Zero";
			@Speech = @Speech_Zero;
		}
		case 0xFFFF21 {
			print "1 Speech_One";
			@Speech = @Speech_One;
		}
		case 0xFFFF22 {
			print "2 Speech_Two";
			@Speech = @Speech_Two;
		}
		case 0xFFFF23 {
			print "3 Speech_Three";
			@Speech = @Speech_Three;
		}
		case 0xFFFF24 {
			print "4 Speech_Four";
			@Speech = @Speech_Four;
		}
		case 0xFFFF25 {
			print "5 Speech_Five";
			@Speech = @Speech_Five;
		}
		case 0xFFFF26 {
			print "6 Speech_Six";
			@Speech = @Speech_Six;
		}
		case 0xFFFF27 {
			print "7 Speech_Seven";
			@Speech = @Speech_Seven;
		}
		case 0xFFFF28 {
			print "8 Speech_Eight";
			@Speech = @Speech_Eight;
		}
		case 0xFFFF29 {
			print "9 Speech_Nine";
			@Speech = @Speech_Nine;
		}
		else {
			print "Unknown Speech_Zero";
			@Speech = @Speech_Zero;
		}

	}
	for (my $x = 0; $x < scalar(@Speech); $x++) {
		my $Message = P25Link::HexString_2_Bytes($Speech[$x]);
		Quantar::HDLC_Tx($Message, 1);
	}
	Quantar::SetHDLC_TxTraffic(0);
	if ($Verbose) {print " done.\n";}
}



#################################################################################
# Misc Subs #####################################################################
#################################################################################

sub Pin5_Interrupt_Handler {
	print color('yellow'), "Pin5 Interrupt Handler.\n", color('reset');
}

sub HotKeys {
	# Hot Keys.
	if ($Packets::HotKeys) {
		if (not defined (my $key = ReadKey(-1))) {
			# No key yet.
		} else {
			switch (ord($key)) {
				case 0x1B { # Escape
					print "EscKey Pressed.\n";
					$Run = 0;
				}
				case ord('0') { # '0'
					$VerboseValue = 0;
				}
				case ord('1') { # '1'
					$VerboseValue = 1;
				}
				case ord('2') { # '2'
					$VerboseValue = 2;
				}
				case ord('3') { # '3'
					$VerboseValue = 3;
				}
				case ord('4') { # '4'
					$VerboseValue = 4;
				}
				case ord('A') { # 'A'
					APRS_IS::Verbose($VerboseValue);
				}
				case ord('a') { # 'a'
					APRS_IS::Update_All(Packets::GetLinkedTalkGroup());
					APRS_IS::Start_Refresh_Timer();
				}
				case ord('B') { # 'B'
				}
				case ord('b') { # 'b'
					Load_VoiceAnnounce($ConfigFile);
				}
				case ord('C') { # 'C'
					CiscoSTUN::Verbose($VerboseValue);
				}
				case ord('c') { # 'c'
				}
				case ord('D') { # 'D'
					DMR::Verbose($VerboseValue);
				}
				case ord('d') { # 'd'
					print "\a";
				}
				case ord('E') {
					# Emergency packet from radio 1 to TG 65535:
					Page_Tx(1, 1, 1, 1);
				}
				case ord('e') {
					# Play Alarm
					Packets::SetVA_Message(0xFFFF00);
					Packets::SetPending_VA(1);
				}
				case ord('f') {
#					SearchUser(0, 3341010);
#					SearchRepeater(0, 334004);
				}
				case ord('H') { # 'H'
					Quantar::Verbose($VerboseValue);
				}
				case ord('h') { # 'h'
					PrintMenu();
				}
				case ord('L') { # 'L'
					P25Link::Verbose($VerboseValue);
				}
				case ord('l') { # 'l'
				}
				case ord('M') { # 'M'
					MMDVM::Verbose($VerboseValue);
				}
				case ord('m') { # 'm'
				}
				case ord('N') { # 'N'
					P25NX::Verbose($VerboseValue);
				}
				case ord('n') { # 'n'
				}
				case ord('Q') { # 'Q'
					Quantar::Verbose($VerboseValue);
				}
				case ord('q') { # 'q'
					$Run = 0;
				}
				case ord('R') { # 'R'
					RDAC::Verbose($VerboseValue);
				}
				case ord('r') { # 'r'
#					Serial::Reset();
					$TestBuffer = "";
#					for (my$x = $TestValue; $x < $TestValue + 4; $x++) {
					for (my$x = 0; $x < 4; $x++) {
#						$TestBuffer .= chr($x);
						$TestBuffer = chr(0x00) . chr(0x7D) .chr(0) . chr(0x7E) .chr(0) . chr(0x7D) . chr(0x5E);
					}
					if ($TestValue < 0xDF) {
						$TestValue += 32;
					} else {
						$TestValue = 0x00;
					}

					$TestBuffer = 
						chr(0x00) . chr(0x7C) .
						chr(0x00) . chr(0x7D) .
						chr(0x00) . chr(0x7E) .
						chr(0x00) . chr(0x7F) .
						chr(0x00) . chr(0x7D) . chr(0x5D) .
						chr(0x00) . chr(0x7D) . chr(0x5E) .
						chr(0x00) . chr(0x7E) .
						chr(0x00) . chr(0xFD);

					Quantar::HDLC_Tx($TestBuffer, 1);
				}
				case ord('S') { # 'S'
					Serial::Verbose($VerboseValue);
				}
				case ord('s') { # 's'
#					Serial::Reset();
					$TestBuffer = "";
					$TestValue = 0x00;
				}
				case ord('t') {
					SuperFrame::Test();
				}
				case ord('v') { # 'v'
					$VA_Test = 0xFFFF11;
					$Packets::VA_Message = $VA_Test;
					$Packets::Pending_VA = 1;
				}
				case ord('V') { # 'V'
					$VA_Test = $VA_Test + 1;
					$Packets::VA_Message = $VA_Test;
					$Packets::Pending_VA = 1;
				}
				case ord('Z') { # 'Z'
					APRS_IS::Verbose(0);
					CiscoSTUN::Verbose(0);
					DMR::Verbose(0);
					MMDVM::Verbose(0);
					P25Link::Verbose(0);
					P25NX::Verbose(0);
					Quantar::Verbose(0);
					RDAC::Verbose(0);
					Serial::Verbose(0);
					Recorder::Verbose(0);
				}
				case 0x41 { # 'UpKey'
					print "UpKey Pressed.\n";
				}
				case 0x42 { # 'DownKey'
					print "DownKey Pressed.\n";
				}
				case 0x43 { # 'RightKey'
					print "RightKey Pressed.\n";
				}
				case 0x44 { # 'LeftKey'
					print "LeftKey Pressed.\n";
				}
				case '[' { # '['
					print "[ Pressed (used also as an escape char).\n";
				}
				else {
					if ($Verbose) {
						print sprintf(" %x", ord($key));
						print " Key Pressed\n";
					}
				}
			}
		}
	}
}

sub Announcements_Player {
	# Voice announce.
	if (Quantar::GetHDLC_Handshake() and (Quantar::GetLocalRx() == 0) and $Packets::Pending_VA) {
		if ($Packets::VA_Message <= 0xFFFF) { APRS_IS::Update_TG($Packets::VA_Message); }
		if ($Packets::VA_Message == 0xFFFF13) { APRS_IS::Update_TG($Packets::PriorityTG); }
		if ($Packets::UseVoicePrompts == 1) {
			SaySomething($Packets::VA_Message);
		}
		$Packets::Pending_VA = 0;
	}

	# Courtesy tone.
	if (Quantar::GetHDLC_Handshake() and (Quantar::GetLocalRx() == 0) and ($Packets::Pending_CourtesyTone > 0)) {
		if ($Packets::UseLocalCourtesyTone > 0 and $Packets::Pending_CourtesyTone >= 1) {
			#if ($Verbose) {print "Courtesy tone expected $Pending_CourtesyTone\n";}
			if ($Packets::Pending_CourtesyTone == 1){
				SaySomething(0xFFFF00 | $Packets::UseLocalCourtesyTone);
			}
			if ($Packets::Pending_CourtesyTone == 2){
				SaySomething(0xFFFF00 | $Packets::UseRemoteCourtesyTone);
			}
			$Packets::Pending_CourtesyTone = 0;
		}
	}
}



#################################################################################
# Main Loop #####################################################################
#################################################################################
sub MainLoop {
	while ($Run) {
		$Packets::Scan = 0;

		Quantar::HDLC_SABM_Timer();
		Quantar::HDLC_RR_Timer();
		Quantar::HDLC_Connection_WD_Timer();
		if ($Packets::Mode == 0) {
			# Serial Port Receiver when Mode == 0
			Serial::Read();
		} elsif ($Packets::Mode == 1) {
			# Cisco STUN TCP Receiver.
			CiscoSTUN::Events();
		}

		DMR::Events();

		# MMDVM WritePoll beacon.
		MMDVM::TimeoutTimer();
		# MMDVM Receiver.
		MMDVM::Events();

		# P25Link Receiver
		P25Link::Events();
#		P25Link::EventsSuperFrame();

		# P25NX Receiver
		P25NX::Events();

		Packets::PauseTGScan_Timer();
		Packets::TxLossTimeout_Timer(); # End of Tx timmer (1 sec).
		Announcements_Player();
		Packets::RemoveDynamicTGLink(); # Remove Dynamic Talk Group Link.
		RDAC::Timer();
		APRS_IS::Refresh_Timer(); # APRS-IS Timer to send position/objects to APRS-IS.
		HotKeys(); # Keystrokes events.
		if ($Packets::Trigger) {
			my $Now = P25Link::GetTickCount;
			my $CycTime = $Now - $LoopOldTime;
			if ($CycTime >= .03) {
				print color('yellow'), "Looping, cycle = $CycTime\n", color('reset');
			} elsif ($CycTime >= .05) {
				print color('bright_yellow'), "Looping, cycle = $CycTime\n", color('reset');
			} elsif ($CycTime >= .07) {
				print color('on_yellow'), "Looping, cycle = $CycTime\n", color('reset');
			}
			$LoopOldTime = $Now;
			$Packets::Trigger = 0;
		}
		#my $NumberOfTalkGroups = scalar keys %TG;
		#print "Total number of links is: $NumberOfTalkGroups\n\n";
	}
}

