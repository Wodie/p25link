#!/usr/bin/perl
#
#
# Strict and warnings recommended.
use strict;
use warnings;
use diagnostics;
use IO::Select;
use Switch;
use Config::IniFiles;
use Digest::CRC; # For HDLC CRC.
use Device::SerialPort;
use IO::Socket;
use IO::Socket::INET;
#use IO::Socket::Timeout;
use IO::Socket::Multicast;
use JSON;
use Data::Dumper qw(Dumper);
use Time::HiRes qw(nanosleep);

use Sys::Hostname;

#use RPi::Pin;
#use RPi::Const qw(:all);
use Ham::APRS::IS;
use Date::Calc qw(check_date Today Date_to_Time Add_Delta_YM Mktime);
use Term::ReadKey;
use Term::ANSIColor;

# Needed for FAP:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use FAP;


my $MaxLen =1024; # Max Socket Buffer length.
my $StartTime = time();


# About this app.
my $AppName = 'P25Link';
use constant VersionInfo => 2;
use constant MinorVersionInfo => 34;
use constant RevisionInfo => 4;
my $Version = VersionInfo . '.' . MinorVersionInfo . '-' . RevisionInfo;
print "\n##################################################################\n";
print "	*** $AppName v$Version ***\n";
print "	Released: May 02, 2022. Created October 17, 2019.\n";
print "	Created by:\n";
print "	Juan Carlos Perez\n";
print "	Bryan Fields W9CR.\n";
print "	p25.link\n";
print "	License:\n";
print "	This software is licenced under the GPL v3.\n";
print "	If you are using it, please let me know, I will be glad to know it.\n\n";
print "	This project is based on the work and information from:\n";
print "	Juan Carlos Perez\n";
print "	Byan Fields W9CR\n";
print "	P25-MMDVM creator Jonathan Naylor G4KLX\n";
print "	P25NX creatorDavid Kraus NX4Y\n";
print "	David Kierzkowski KD8EYF\n";
print "	APRS is a registed trademark and creation of Bob Bruninga WB4APR\n";
print "\n##################################################################\n\n";

# Detect Target OS.
my $OS = $^O;
print color('green'), "Current OS is $OS\n", color('reset');

# Load Settings ini file.
print color('green'), "Loading Settings...\n", color('reset');
my $cfg = Config::IniFiles->new( -file => "/opt/p25link/config.ini");
# Settings:
my $Mode = $cfg->val('Settings', 'HardwareMode'); #0 = v.24, no other modes coded at the momment.
my $HotKeys = $cfg->val('Settings', 'HotKeys');
my $LocalHost = $cfg->val('Settings', 'LocalHost');
	#my($LocalIPAddr) = inet_ntoa((gethostbyname(hostname))[4]); 
	my($LocalHostIP) = inet_ntoa((gethostbyname($LocalHost))[4]); 
my $PriorityTG = $cfg->val('Settings', 'PriorityTG');
my $Hangtime = $cfg->val('Settings', 'Hangtime');
my $MuteTGTimeout = $cfg->val('Settings', 'MuteTGTimeout');
my $UseVoicePrompts = $cfg->val('Settings', 'UseVoicePrompts');
my $UseLocalCourtesyTone = $cfg->val('Settings', 'UseLocalCourtesyTone');
my $UseRemoteCourtesyTone = $cfg->val('Settings', 'UseRemoteCourtesyTone');
my $SiteName = $cfg->val('Settings', 'SiteName');
my $SiteInfo = $cfg->val('Settings', 'SiteInfo');
my $Verbose = $cfg->val('Settings', 'Verbose');
print "  Mode = $Mode\n";
print "  HotKeys = $HotKeys\n";
print "  LocalHost = $LocalHost    ntoa($LocalHostIP)\n";
print "  Mute Talk Group Timeout = $MuteTGTimeout seconds.\n";
print "  Use Voice Prompts = $UseVoicePrompts\n";
print "  Use Local Courtesy Tone = $UseLocalCourtesyTone\n";
print "  Use Remote Courtesy Tone = $UseRemoteCourtesyTone\n";
print "  Site Name = $SiteName\n";
print "  Site Info = $SiteInfo\n";
print "  Verbose = $Verbose\n";
print "----------------------------------------------------------------------\n";



# Data Recorder
print color('green'), "Init data recorder...\n", color('reset');
my $RecordEnable = $cfg->val('Settings', 'RecordEnable');
my $RecordFile = $cfg->val('Settings', 'RecordFile');
print "  Enable = $RecordEnable\n";
print "  File Name = $RecordFile\n";
open my $recfh, ">", $RecordFile || die "Can't open the recording file: $!";
print "----------------------------------------------------------------------\n";



# TalkGroups:
print color('green'), "Init TalkGroups...\n", color('reset');
my $TalkGroupsFile = $cfg->val('TalkGroups', 'HostsFile');
my $TG_Verbose = $cfg->val('TalkGroups', 'Verbose');
print "  Talk Groups File: " . $TalkGroupsFile ."\n";
print "  Verbose = $TG_Verbose\n";
our %TG;
my $fh;
print "  Loading TalkGroupsFile...\n";
if (!open($fh, "<", $TalkGroupsFile)) {
	warn "  *** Error ***   File $TalkGroupsFile not found.\n";
} else {
	print "  File Ok.\n";
	my %result;
	while (my $Line = <$fh>) {
		chomp $Line;
		## skip comments and blank lines and optional repeat of title line
		next if $Line =~ /^\#/ || $Line =~ /^\s*$/ || $Line =~ /^\+/;
		#split each line into array
		#my @Line = split(/\s+/, $Line);
		my @Line = split(/\t+/, $Line);
		my $TalkGroup = $Line[0];
		$TG{$TalkGroup}{'TalkGroup'} = $Line[0];
		$TG{$TalkGroup}{'Mode'} = $Line[1];
		$TG{$TalkGroup}{'MMDVM_URL'} = $Line[2];
		$TG{$TalkGroup}{'MMDVM_Port'} = $Line[3];
		$TG{$TalkGroup}{'Scan'} = $Line[4];
		$TG{$TalkGroup}{'Linked'} = 0;
		$TG{$TalkGroup}{'P25Link_Connected'} = 0;
		$TG{$TalkGroup}{'P25NX_Connected'} = 0;
		$TG{$TalkGroup}{'MMDVM_Connected'} = 0;
		if ($TG_Verbose) {
			print "  TG Index " . $TalkGroup;
			print ", Mode " . $TG{$TalkGroup}{'Mode'};
			print ", URL " . $TG{$TalkGroup}{'MMDVM_URL'};
			print ", Port " . $TG{$TalkGroup}{'MMDVM_Port'};
			print ", Scan " . $TG{$TalkGroup}{'Scan'};
			print "\n";
		}
	}
	close $fh;	
	# System Call:
	my $TalkGroup = 65535;
	$TG{$TalkGroup}{'TalkGroup'} = $TalkGroup;
	$TG{$TalkGroup}{'Mode'} = 'Local';
	$TG{$TalkGroup}{'MMDVM_URL'} = '';
	$TG{$TalkGroup}{'MMDVM_Port'} = 0;
	$TG{$TalkGroup}{'Scan'} = 0;
	$TG{$TalkGroup}{'Linked'} = 0;
	$TG{$TalkGroup}{'P25Link_Connected'} = 0;
	$TG{$TalkGroup}{'P25NX_Connected'} = 0;
	$TG{$TalkGroup}{'MMDVM_Connected'} = 0;
	if ($TG_Verbose > 2) {
		foreach my $key (keys %TG)
		{
			print "  Key field: $key\n";
			foreach my $key2 (keys %{$TG{$key}})
			{
				print "  - $key2 = $TG{$key}{$key2}\n";
			}
		}
	}
}
my $NumberOfTalkGroups = scalar keys %TG;
print "\n  Total number of Internet TGs is: " . $NumberOfTalkGroups . "\n";
if ($NumberOfTalkGroups <= 0) {
	warn "*** Error***\tNo hosts.\n";
	die;
}
my $ValidNteworkTG = 0;
print "----------------------------------------------------------------------\n";



# Init RDAC.
print color('green'), "Init RDAC.\n", color('reset');
my %RDAC;
$RDAC{'Interval'} = $cfg->val('RDAC', 'Interval');
my $RDAC_Verbose = $cfg->val('RDAC', 'Verbose');
print "  Interval = $RDAC{'Interval'}\n";
print "  Verbose = $RDAC_Verbose\n";
use constant OpPollReply => 0x2100;
$RDAC{'NextTimer'} = time(); # Make it run as soon as Mail Loop is running.
$RDAC{'Port'} = 30002;
$RDAC{'MulticastAddress'} = P25Link_MakeMulticastAddress(100);
$RDAC{'TalkGroup'} = $PriorityTG;
#$RDAC{'Sock'} = IO::Socket::Multicast->new (
#	LocalHost => $RDAC{'MulticastAddress'},
#	LocalPort => $RDAC{'Port'},
#	Proto => 'udp',
#	Blocking => 0,
#	Broadcast => 1,
#	ReuseAddr => 1,
#	PeerPort => $RDAC{'Port'}
#) || die "Can not Bind RDAC Sock : $@\n";
#$RDAC{'Sel'} = IO::Select->new($RDAC{'Sock'}
#) || die "  cannot create RDAC_Sock $!\n";
#$RDAC{'Sock'}->mcast_add($RDAC{'MulticastAddress'});
#$RDAC{'Sock'}->mcast_ttl(10);
#$RDAC{'Sock'}->mcast_loopback(0);
#$RDAC{'Connected'} = 1;
print "----------------------------------------------------------------------\n";



# Init MMDVM.
print color('green'), "Init MMDVM.\n", color('reset');
my $MMDVM_Enabled = $cfg->val('MMDVM', 'MMDVM_Enabled');
my $Callsign = $cfg->val('MMDVM', 'Callsign');
my $RadioID = $cfg->val('MMDVM', 'RadioID');
my $MMDVM_Verbose = $cfg->val('MMDVM', 'Verbose');
print "  Enabled = $MMDVM_Enabled\n";
print "  Callsign = $Callsign\n";
print "  RadioID = $RadioID\n";
print "  Verbose = $MMDVM_Verbose\n";

my $MMDVM_LocalHost = $LocalHost; # Bind Address.
my $MMDVM_LocalPort = 41020; # Local Port.
my $MMDVM_RemoteHost; # Buffer for Rx data IP.
my $MMDVM_Poll_Timer_Interval = 5; # sec.
my $MMDVM_Poll_NextTimer = time() + $MMDVM_Poll_Timer_Interval;
my $MMDVM_TG = 0;
print "----------------------------------------------------------------------\n";



# Init P25Link.
print color('green'), "Init P25Link.\n", color('reset');
my $P25Link_Enabled = $cfg->val('P25Link', 'P25Link_Enabled');
my $P25Link_Verbose =$cfg->val('P25Link', 'Verbose');
print "  Enabled = $P25Link_Enabled\n";
print "  Verbose = $P25Link_Verbose\n";
my $P25Link_Port = 30001;
print "----------------------------------------------------------------------\n";



# Init P25NX.
print color('green'), "Init P25NX.\n", color('reset');
my $P25NX_Enabled = $cfg->val('P25NX', 'P25NX_Enabled');
my $P25NX_Verbose =$cfg->val('P25NX', 'Verbose');
print "  Enabled = $P25NX_Enabled\n";
print "  Verbose = $P25NX_Verbose\n";
my $P25NX_Port = 30000;
print "----------------------------------------------------------------------\n";



# Quantar HDLC Init.
print color('green'), "Init HDLC.\n", color('reset');
my $HDLC_RTRT_Enabled = $cfg->val('HDLC', 'RTRT_Enabled');
my $HDLC_Verbose =$cfg->val('HDLC', 'Verbose');
print "  RT/RT ENabled = $HDLC_RTRT_Enabled\n";
print "  Verbose = $HDLC_Verbose\n";

my %Quant;
$Quant{'FrameType'} = 0;
$Quant{'LocalRx'} = 0;
$Quant{'LocalRx_Time'} = 0;
$Quant{'IsDigitalVoice'} = 1;
$Quant{'IsPage'} = 0;
$Quant{'dBm'} = 0;
$Quant{'RSSI'} = 0;
$Quant{'RSSI_Is_Valid'} = 0;
$Quant{'InvertedSignal'} = 0;
$Quant{'CandidateAdjustedMM'} = 0;
$Quant{'BER'} = 0;
$Quant{'SourceDev'} = 0;
$Quant{'Encrypted'} = 0;
$Quant{'Explicit'} = 0;
$Quant{'IndividualCall'} = 0;
$Quant{'ManufacturerID'} = 0;
$Quant{'ManufacturerName'} = "";
$Quant{'Emergency'} = 0;
$Quant{'Protected'} = 0;
$Quant{'FullDuplex'} = 0;
$Quant{'PacketMode'} = 0;
$Quant{'Priority'} = 0;
$Quant{'IsTGData'} = 0;
$Quant{'AstroTalkGroup'} = 0;
$Quant{'DestinationRadioID'} = 0;
$Quant{'SourceRadioID'} = 0;
$Quant{'LSD'} = [0, 0, 0, 0];
$Quant{'LSD0'} = 0;
$Quant{'LSD1'} = 0;
$Quant{'LSD2'} = 0;
$Quant{'LSD3'} = 0;
$Quant{'EncryptionI'} = 0;
$Quant{'EncryptionII'} = 0;
$Quant{'EncryptionIII'} = 0;
$Quant{'EncryptionIV'} = 0;
$Quant{'Algorythm'} = 0;
$Quant{'AlgoName'} = "";
$Quant{'KeyID'} = 0;
$Quant{'Speech'} = "";
$Quant{'Raw0x62'} = "";
$Quant{'Raw0x63'} = "";
$Quant{'Raw0x64'} = "";
$Quant{'Raw0x65'} = "";
$Quant{'Raw0x66'} = "";
$Quant{'Raw0x67'} = "";
$Quant{'Raw0x68'} = "";
$Quant{'Raw0x69'} = "";
$Quant{'Raw0x6A'} = "";
$Quant{'Raw0x6B'} = "";
$Quant{'Raw0x6C'} = "";
$Quant{'Raw0x6D'} = "";
$Quant{'Raw0x6E'} = "";
$Quant{'Raw0x6F'} = "";
$Quant{'Raw0x70'} = "";
$Quant{'Raw0x71'} = "";
$Quant{'Raw0x72'} = "";
$Quant{'Raw0x73'} = "";
$Quant{'SuperFrame'} = "";
$Quant{'Tail'} = 0;
$Quant{'PrevFrame'} = "";
#
# ICW (Infrastructure Control Word).
# Byte 1 address.
# Bte 2 frame type.
my $C_RR = 0x41;
my $C_UI = 0x03;
my $C_SABM = 0x3F;
my $C_XID = 0xBF;
# Byte 3.
#0x60 thru 0x73, etc
my $C_RN_Page = 0xA1;
# Byte 4.
# Byte 5 RT mode flag.
my $C_RTRT_Enabled = 0x02;
my $C_RTRT_Disabled = 0x04;
my $C_RTRT_DCRMode = 0x05;
# Byte 6 Op Code Start/Stop flag.
my $C_ChangeChannel = 0x06;
my $C_StartTx = 0x0C;
my $C_EndTx = 0x25;
# Byte 7 OpArg, type flag.
my $C_AVoice = 0x00;
my $C_TMS_Data_Payload = 0x06;
my $C_DVoice = 0x0B;
my $C_TMS_Data = 0x0C;
my $C_From_Comparator_Start = 0x0D;
my $C_From_Comparator_Stop = 0x0E;
my $C_Page = 0x0F;
# Byte 8 ICW flag.
my $C_DIU3000 = 0x00;
my $C_Quantar = 0xC2;
my $C_QuantarAlt = 0x1B;
# Byte 9 LDU1 RSSI.
# Byte 10 1A flag.
my $C_RSSI_Is_Valid = 0x1A;
# Byte 11 LDU1 RSSI.
#
# Byte 12.
my $C_Normal_Page = 0x9F;
my $C_Emergency_Page = 0xA7;

# Byte 13 Page.
my $C_Individual_Page = 0x00;
my $C_Group_Page = 0x90;
#
my $C_SystemCallTG = 0xFFFF;
#
#
my $IsTGData = 0;
my $C_Implicit_MFID = 0;
my $C_Explicit_MFID = 1;
my $Is_TG_Data = 0;
my $SuperframeCounter = 0;
#
#
my $RR_NextTimer = 0;
my $RR_Timeout = 0;
my $RR_TimerInterval = 4; # Seconds.
my $HDLC_Handshake = 0;
my $SABM_Counter = 0;
my $Message = "";
my $HDLC_Buffer = "";
my $RR_TimerEnabled = 0;
#
my $Tx_Started = 0;
my $SuperFrameCounter = 0;
my $HDLC_TxTraffic = 0;
my $LocalRx_Time;
print "----------------------------------------------------------------------\n";



# Init Serial Port for HDLC.
print color('green'), "Init Serial Port.\n", color('reset');
my $SerialPort;
my $SerialPort_Configuration = "SerialConfig.cnf";
if ($Mode == 0) {


# For Mac:
if ($OS eq "darwin") {
	$SerialPort = Device::SerialPort->new('/dev/tty.usbserial') || die "Cannot Init Serial Port : $!\n";
}
# For Linux:
if ($OS eq "linux") {
	$SerialPort = Device::SerialPort->new('/dev/ttyUSB0') || die "Cannot Init Serial Port : $!\n";
}
	$SerialPort->baudrate(19200);
	$SerialPort->databits(8);
	$SerialPort->parity('none');
	$SerialPort->stopbits(1);
	$SerialPort->handshake('none');
	$SerialPort->buffers(4096, 4096);
	$SerialPort->datatype('raw');
	$SerialPort->debug(1);
	#$SerialPort->write_settings || undef $SerialPort;
	#$SerialPort->save($SerialPort_Configuration);
	#$TickCount = sprintf("%d", $SerialPort->get_tick_count());
	#$FutureTickCount = $TickCount + 5000;
	#print "  TickCount = $TickCount\n\n";
	print color('yellow'),
		"To use Raspberry Pi UART you need to disable Bluetooth by editing: /boot/config.txt\n" .
		"Add line: dtoverlay=pi3-disable-bt-overlay\n", color('reset'),;
}
print "----------------------------------------------------------------------\n";



# APRS-IS:
print color('green'), "Loading APRS-IS...\n", color('reset');
my $APRS_Passcode = $cfg->val('APRS', 'Passcode');
my $APRS_Suffix = $cfg->val('APRS', 'Suffix');
my $APRS_Server= $cfg->val('APRS', 'Server');
my $APRS_File = $cfg->val('APRS', 'APRS_File');
my $APRS_Interval = $cfg->val('APRS', 'APRS_Interval') * 60;
my $My_Latitude = $cfg->val('APRS', 'Latitude');
my $My_Longitude = $cfg->val('APRS', 'Longitude');
my $My_Symbol = $cfg->val('APRS', 'Symbol');
my $My_Altitude = $cfg->val('APRS', 'Altitude');
my $My_Freq = $cfg->val('APRS', 'Frequency');
my $My_Tone = $cfg->val('APRS', 'AccessTone');
my $My_Offset = $cfg->val('APRS', 'Offset');
my $My_NAC = $cfg->val('APRS', 'NAC');
my $My_Comment = $cfg->val('APRS', 'APRSComment');
my $APRS_Verbose= $cfg->val('APRS', 'Verbose');
print "  Passcode = $APRS_Passcode\n";
print "  Suffix = $APRS_Suffix\n";
print "  Server = $APRS_Server\n";
print "  APRS File $APRS_File\n";
print "  APRS Interval $APRS_Interval\n";
print "  Latitude = $My_Latitude\n";
print "  Longitude = $My_Longitude\n";
print "  Symbol = $My_Symbol\n";
print "  Altitude = $My_Altitude\n";
print "  Freq = $My_Freq\n";
print "  Tone = $My_Tone\n";
print "  Offset = $My_Offset\n";
print "  NAC = $My_NAC\n";
print "  Comment = $My_Comment\n";
print "  Verbose = $APRS_Verbose\n";
my $APRS_IS;
my %APRS;
my $APRS_NextTimer = time();
if ($APRS_Passcode ne Ham::APRS::IS::aprspass($Callsign)) {
	$APRS_Server = undef;
	warn color('red'), "APRS invalid pasword.\n", color('reset');
}
my $APRS_Callsign = $Callsign . '-' . $APRS_Suffix;
print "  APRS Callsign = $APRS_Callsign\n";
if (defined $APRS_Server) {
	$APRS_IS = new Ham::APRS::IS($APRS_Server, $APRS_Callsign,
		'appid' => "$AppName $Version",
		'passcode' => $APRS_Passcode,
		'filter' => 't/m');
	if (!$APRS_IS) {
		warn color('red'), "Failed to create APRS-IS Server object: " . $APRS_IS->{'error'} .
			"\n", color('reset');
	}
	#Ham::APRS::FAP::debug(1);
}
print "----------------------------------------------------------------------\n";



# Voice Announce.
print color('green'), "Loading voice announcements...\n", color('reset');
my $SpeechFile = $cfg->val('Settings', 'SpeechFile');
print "  File = $SpeechFile\n";
my $SpeechIni = Config::IniFiles->new( -file => $SpeechFile);
my @Speech_Zero = $SpeechIni->val('Zero', 'byte');
my @Speech_One = $SpeechIni->val('One', 'byte');
my @Speech_Two = $SpeechIni->val('Two', 'byte');
my @Speech_Three = $SpeechIni->val('Three', 'byte');
my @Speech_Four = $SpeechIni->val('Four', 'byte');
my @Speech_Five = $SpeechIni->val('Five', 'byte');
my @Speech_Six = $SpeechIni->val('Six', 'byte');
my @Speech_Seven = $SpeechIni->val('Seven', 'byte');
my @Speech_Eight = $SpeechIni->val('Eight', 'byte');
my @Speech_Nine = $SpeechIni->val('Nine', 'byte');
my @Speech_Local = $SpeechIni->val('Local', 'byte');
my @Speech_WW = $SpeechIni->val('WW', 'byte');
my @Speech_WWTac1 = $SpeechIni->val('WWTac1', 'byte');
my @Speech_WWTac2 = $SpeechIni->val('WWTac2', 'byte');
my @Speech_WWTac3 = $SpeechIni->val('WWTac3', 'byte');
my @Speech_NA = $SpeechIni->val('NA', 'byte');
my @Speech_NATac1 = $SpeechIni->val('NATac1', 'byte');
my @Speech_NATac2 = $SpeechIni->val('NATac2', 'byte');
my @Speech_NATac3 = $SpeechIni->val('NATac3', 'byte');
my @Speech_Europe = $SpeechIni->val('Europe', 'byte');
my @Speech_EuTac1 = $SpeechIni->val('EuTac1', 'byte');
my @Speech_EuTac2 = $SpeechIni->val('EuTac2', 'byte');
my @Speech_EuTac3 = $SpeechIni->val('EuTac3', 'byte');
my @Speech_France = $SpeechIni->val('France', 'byte');
my @Speech_Germany = $SpeechIni->val('Germany', 'byte');
my @Speech_Pacific = $SpeechIni->val('Pacific', 'byte');
my @Speech_PacTac1 = $SpeechIni->val('PacTac1', 'byte');
my @Speech_PacTac2 = $SpeechIni->val('PacTac2', 'byte');
my @Speech_PacTac3 = $SpeechIni->val('PacTac3', 'byte');

my @Speech_Alarm = $SpeechIni->val('Alarm', 'byte');
my @Speech_CTone1 = $SpeechIni->val('CTone1', 'byte');
my @Speech_CTone2 = $SpeechIni->val('CTone2', 'byte');
my @Speech_QuindarToneStart = $SpeechIni->val('QuindarToneStart', 'byte');
my @Speech_QuindarToneEnd = $SpeechIni->val('QuindarToneEnd', 'byte');
my @Speech_3Up = $SpeechIni->val('3Up', 'byte');
my @Speech_BeeBoo = $SpeechIni->val('BeeBoo', 'byte');
my @Speech_BumbleBee = $SpeechIni->val('BumbleBee', 'byte');
my @Speech_Nextel = $SpeechIni->val('Nextel', 'byte');
my @Speech_RC210_9 = $SpeechIni->val('RC210_9', 'byte');
my @Speech_RC210_10 = $SpeechIni->val('RC210_10', 'byte');
my @Speech_LoBat1 = $SpeechIni->val('LoBat1', 'byte');
my @Speech_LoBat2 = $SpeechIni->val('LoBat2', 'byte');
my @Speech_CustomCTone = $SpeechIni->val('customCTone', 'byte');

my @Speech_SystemStartP25NX = $SpeechIni->val('SystemStartP25NX', 'byte');
my @Speech_WellcomeToP25DotLink = $SpeechIni->val('WellcomeToP25DotLink', 'byte');
my @Speech_DefaultRevert = $SpeechIni->val('DefaultRevert', 'byte');
my @Speech_FSG_2050 = $SpeechIni->val('FSG_2050', 'byte');
my @Speech_Wave_4095 = $SpeechIni->val('Wave_4095', 'byte');

my @Speech_TestPattern = $SpeechIni->val('TestPattern', 'byte');

my $Pending_VA = 0;
my $VA_Message = 0;
my $VA_Test = 0xFFFF;
my $Pending_CourtesyTone = 0;
print "  Done.\n";
print "----------------------------------------------------------------------\n";



# Connect to Priority and scan TGs.
my $LocalActive = 0;
my $PauseScan = 0;
my $PauseTGScanTimer = time();
my $LinkedTalkGroup = $PriorityTG;

foreach my $key (keys %TG) {
	if ($TG{$key}{'Scan'}) {
		print color('green'), "Scan TG " . $key . "\n", color('reset');
		AddLinkTG($key, 0);
	}
}
if ($PriorityTG > 10) {
	if (!$TG{$PriorityTG}{'Scan'}) {
		$TG{$PriorityTG}{'Scan'} = 100;
	}
	AddLinkTG($PriorityTG, 0);
}
print "----------------------------------------------------------------------\n";



# Prepare Startup VA Message.
$VA_Message = 0xFFFF11; # 0 = Welcome to P25Link.
$Pending_VA = 1; # Let the system know we wish a Voice Announce when possible.



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



# Init Cisco STUN TCP
print color('green'), "Init Cisco STUN.\n", color('reset');
my $STUN_ID = sprintf("%x", hex($cfg->val('STUN', 'STUN_ID')));
my $STUN_Verbose =$cfg->val('STUN', 'Verbose');
print "  Stun ID = 0x$STUN_ID\n";
print "  Verbose = $STUN_Verbose\n";
my $STUN_ServerSocket;
my $STUN_Port = 1994; # Cisco STUN port is 1994;
my $STUN_Connected = 0;
my $STUN_Sel;
my $STUN_ClientSocket;
my $STUN_ClientAddr;
my $STUN_ClientPort;
my $STUN_ClientIP;
my $STUN_fh;

$STUN_ServerSocket = IO::Socket::INET->new (
	#LocalHost => '172.31.7.162',
	LocalPort => $STUN_Port,
	Proto => 'tcp',
	Listen => SOMAXCONN,
	ReuseAddr =>1,
	Blocking => 0
) || die "  cannot create CiscoUSTUN_ServerSocket $!\n";
print "  Server waiting for client connection on port " . $STUN_Port . ".\n";

# Set timeouts -- may not really be needed
#IO::Socket::Timeout->enable_timeouts_on($STUN_ServerSocket);
#$STUN_ServerSocket->read_timeout(0.0001);
#$STUN_ServerSocket->write_timeout(0.0001);
my $STUN_DataIndex = 0;
my @STUN_Data = [];

print "----------------------------------------------------------------------\n";



# Read Keys:
if ($HotKeys) {
	ReadMode 3;
	PrintMenu();
}
print "----------------------------------------------------------------------\n";



# Misc
my $Read_Timeout = 0.003;
my $Run = 1;
my $TGVar = 2044;



###################################################################
# MAIN ############################################################
###################################################################
if ($Mode == 1) { # If Cisco STUN (Mode 1) is selected:
	if ($STUN_Verbose) {print "Cisco STUN listen for connections:\n";}
	while ($Run) {
		#if($STUN_ClientAddr = accept($STUN_ClientSocket, $STUN_ServerSocket)) {
		if(($STUN_ClientSocket, $STUN_ClientAddr) = $STUN_ServerSocket->accept()) {
			my ($Client_Port, $Client_IP) = sockaddr_in($STUN_ClientAddr);
			$STUN_ClientIP = inet_ntoa($Client_IP);
			if ($STUN_Verbose) {print "STUN_Client IP " . inet_ntoa($Client_IP) . 
				":" . $STUN_Port . "\n";}
			$STUN_ClientSocket->autoflush(1);
			$STUN_Sel = IO::Select->new($STUN_ClientSocket);
			$STUN_Connected = 1;
			MainLoop();
		}
	}
	$STUN_ServerSocket->close();
} else { # If Serial (Mode 0) is selected: 
	MainLoop();
}
# Program exit:
print "----------------------------------------------------------------------\n";
ReadMode 0; # Set keys back to normal State.
if ($Mode == 0) { # Close Serial Port:
	$SerialPort->close || die "Failed to close SerialPort.\n";
}
if ($APRS_IS and $APRS_IS->connected()) {
	$APRS_IS->disconnect();
	print color('yellow'), "APRS-IS Disconected.\n", color('reset');
}
foreach my $key (keys %TG){ # Close Socket connections:
	if (($TG{$key}{'MMDVM_Connected'} >= 1) or ($TG{$key}{'P25Link_Connected'} >= 1) or
			($TG{$key}{'P25NX_Connected'} >= 1)) {
		RemoveLinkTG($key);
	}
}
print "Good bye cruel World.\n";
print "----------------------------------------------------------------------\n\n";
exit;



##################################################################
# Menu ###########################################################
##################################################################
sub PrintMenu {
	print "Shortcuts menu:\n";
	print "  Q/q = Quit.                      h = Help..\n";
	print "  A/a = APRS  show/hide verbose.   C/c = Voice anounce test.       \n";
	print "  E/e = Emergency Page/Alarm.      F/f = Serach user test.         \n";
	print "  A/a = APRS  show/hide verbose.   H/h = HDLC  show/hide verbose.  \n";
	print "  J/j = JSON  show/hide verbose.   M/m = MMDVM   show/hide verbose.\n";
	print "  P/p = P25NX show/hide verbose.   L/l = P25Link show/hide verbose.\n";
	print "  S/s = STUN  show/hide verbose.   t   = Test.                   \n\n";
}



#################################################################################
# Recorder ########################################################################
#################################################################################
sub RecorderBytes_2_HexString {
	my ($Buffer) = @_;
	# Display Rx Hex String.
	#print "HDLC_Rx Buffer:              ";
	my $x = 0;
	if (ord(substr($Buffer, $x, 1)) < 0x10) {
		print $recfh sprintf("byte = 0x0%x", ord(substr($Buffer, $x, 1)));
		if ($Verbose eq 'R') { print sprintf("byte = 0x0%x", ord(substr($Buffer, $x, 1)));}
	} else {
		print $recfh sprintf("byte = 0x%x", ord(substr($Buffer, $x, 1)));
		if ($Verbose eq 'R') { print sprintf("byte = 0x%x", ord(substr($Buffer, $x, 1)));}
	}
	for (my $x = 1; $x < length($Buffer); $x++) {
		if (ord(substr($Buffer, $x, 1)) < 0x10) {
			print $recfh sprintf(", 0x0%x", ord(substr($Buffer, $x, 1)));
			if ($Verbose eq 'R') {print sprintf(", 0x0%x", ord(substr($Buffer, $x, 1)));}
		} else {
			print $recfh sprintf(", 0x%x", ord(substr($Buffer, $x, 1)));
			if ($Verbose eq 'R') {print sprintf(", 0x%x", ord(substr($Buffer, $x, 1)));}
		}
	}
	print $recfh "\n";
	if ($Verbose eq 'R') {print "\n";}
}



##################################################################
# RDAC ###########################################################
##################################################################
sub RDAC_Disconnect {
	my ($TalkGroup) = @_;
	my $MulticastAddress = P25Link_MakeMulticastAddress($TalkGroup);
	$TG{$TalkGroup}{'Sock'}->mcast_drop($MulticastAddress);
#	$TG{$TalkGroup}{'Sel'}->remove($TG{$TalkGroup}{'Sock'});
	$TG{$TalkGroup}{'P25Link_Connected'} = 0;
	$TG{$TalkGroup}{'Sock'}->close();
	print color('green'), "P25Link TG $TalkGroup disconnected.\n", color('reset');
}

sub RDAC_Timer {
	if (time() >= $RDAC{'NextTimer'}) {
		RDAC_Tx($RDAC{'TalkGroup'});
		$RDAC{'NextTimer'} = time() + $RDAC{'Interval'};
	}
}

sub RDAC_Tx {
	my ($TalkGroup) = @_;
	if (($P25Link_Enabled == 0) and ($P25NX_Enabled == 0)) { return; }
	$RDAC{'TalkGroup'} = $TalkGroup;
	my $Buffer;
	$Buffer = 'P25Link' . chr(0x00);
	$Buffer = $Buffer . chr(OpPollReply & 0xFF) . chr((OpPollReply & 0xFF00) >> 8);
	$Buffer = $Buffer . inet_aton($LocalHost);
	$Buffer = $Buffer . chr($RDAC{'Port'} & 0xFF) . chr(($RDAC{'Port'} & 0xFF00) >> 8);
	$Buffer = $Buffer . chr(VersionInfo); # Software Mayor Version
	# 6
	$Buffer = $Buffer . chr(MinorVersionInfo); # Software Minor Version
	$Buffer = $Buffer . chr(RevisionInfo); # Software Revision Version
	# Flags
	my $Byte = 0;
	if ($Quant{'LocalRx'}) {$Byte = 0x01;} # Receive
	if ($Quant{'LocalRx'}) {$Byte = $Byte | 0x02;} # Transmit
	if ($Quant{'IsDigitalVoice'} == 1) { # Mode Digital
		$Byte = $Byte | 0x04;
	}
	if ($Quant{'IsDigitalVoice'} == 0) { # Mode Analog
		$Byte = $Byte | 0x08;
	}
	if ($Quant{'IsPage'} == 1) { # Mode Data
		$Byte = $Byte | 0x10;
	}
	$Buffer = $Buffer . chr($Byte); # Flags
	# Callsign
	my $RDAC_Callsign = $Callsign . "/" . $APRS_Suffix;
	$Buffer = $Buffer . $RDAC_Callsign;
	for (my $x = length($RDAC_Callsign); $x < 10; $x++) {
		$Buffer = $Buffer . ' ';
	}
	# Site Name
	if (length($SiteName) > 30) {
		$SiteName = substr($SiteName, 0, 30);
	}
	$Buffer = $Buffer . $SiteName;
	for (my $x = length($SiteName); $x < 30; $x++) {
		$Buffer = $Buffer . ' ';
	}
	# Tak Group
	$Buffer = $Buffer . chr($TalkGroup & 0xFF) . chr(($TalkGroup & 0xFF00) >> 8);
	# Info
	if (length($SiteInfo) > 30) {
		$SiteInfo = substr($SiteInfo, 0, 30);
	}
	$Buffer = $Buffer . $SiteInfo;
	for (my $x = length($SiteInfo); $x < 30; $x++) {
		$Buffer = $Buffer . ' ';
	}
	#Filler 10
	$Buffer = $Buffer . chr(0) . chr(0) . chr(0) . chr(0) . chr(0) . chr(0) . chr(0) . chr(0) . chr(0) . chr(0);
#print " Len4 " . length($Buffer) . "\n";
		
	# Tx to the Network.
	if ($RDAC_Verbose >= 2) {
		print "RDAC_Tx Message.\n";
		StrToHex($Buffer);
	}
	my $Tx_Sock = IO::Socket::Multicast->new(
		LocalHost => $RDAC{'MulticastAddress'},
		LocalPort => $RDAC{'Port'},
		Proto => 'udp',
		Blocking => 0,
		Broadcast => 1,
		ReuseAddr => 1,
		PeerPort => $RDAC{'Port'}
		)
		or die "Can not create Multicast : $@\n";
	$Tx_Sock->mcast_ttl(10);
	$Tx_Sock->mcast_loopback(0);
	$Tx_Sock->mcast_send($Buffer, $RDAC{'MulticastAddress'} . ":" . $RDAC{'Port'});
	$Tx_Sock->close;
#	if ($RDAC_Verbose) {
		print color('green'), "RDAC_Tx IP Mcast " . $RDAC{'MulticastAddress'} . "\n", color('reset');
#	}
}



##################################################################
# APRS-IS ########################################################
##################################################################
sub APRS_connect {
	my $Ret = $APRS_IS->connect('retryuntil' => 2);
	if (!$Ret) {
		warn color('red'), "Failed to connect APRS-IS server: " . $APRS_IS->{'error'} . "\n", color('reset');
		return;
	}
	print "  APRS-IS: connected.\n";
}

sub APRS_Timer { # APRS-IS
	if (time() >= $APRS_NextTimer) {
		if ($APRS_IS) {
			if (!$APRS_IS->connected()) {
				APRS_connect();
			}
			if ( $APRS_IS->connected() ) {
				if ($APRS_Verbose) {print color('green'), "APRS-IS Timer.\n", color('reset');}
				APRS_Update($LinkedTalkGroup);
			}
		}
		$APRS_NextTimer = time() + $APRS_Interval;
	}
}

sub APRS_Make_Pos {
	my ($Call, $Latitude, $Longitude, $Speed, $Course, $Altitude, $Symbol, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "  APRS-IS does not exist.\n", color('reset'); 
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "  APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		APRS_connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	my %Options;
	$Options{'timestamp'} = 0;
	$Options{'comment'} = 'Hola';
	
	my $APRS_position = Ham::APRS::FAP::make_position(
		$Latitude,
		$Longitude,
		$Speed, # speed
		$Course, # course
		$Altitude, # altitude
		(defined $Symbol) ? $Symbol : '/[', # symbol
		{
		#'compression' => 1,
		#'ambiguity' => 1, # still can not make it work.
		#'timestamp' => time(), # still can not make it work.
		'comment' => $Comment,
		#'dao' => 1
	});
	if ($APRS_Verbose > 1) {print color('green'), "  APRS Position is: $APRS_position\n", color('reset');}
	my $Packet = sprintf('%s>APTR01:%s', $Call, $APRS_position . $Comment);
	print color('blue'), "  $Packet\n", color('reset');
	if ($APRS_Verbose > 2) {print "  APRS Packet is: $Packet\n";}
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	print color('grey12'),"  APRS_Make_Pos done for $APRS_Callsign\n", color('reset');
}

sub APRS_Make_Object {
	my ($Name, $TimeStamp, $Latitude, $Longitude, $Symbol, $Speed, 
		$Course, $Altitude, $Alive, $UseCompression, $PosAmbiguity, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "  APRS-IS does not exist.\n", color('reset');
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "  APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		APRS_connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	
	my $APRS_object = Ham::APRS::FAP::make_object(
		$Name, # Name
		$TimeStamp,
		$Latitude,
		$Longitude,
		$Symbol, # symbol
		$Speed, # speed
		$Course,
		$Altitude, # altitude
		$Alive,
		$UseCompression,
		$PosAmbiguity,
		$Comment
	);
	if ($APRS_Verbose > 0) {print "  APRS Object is: $APRS_object\n";}
	my $Packet = sprintf('%s>APTR01:%s', $APRS_Callsign, $APRS_object);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "*** Error *** sending APRS-IS Object $Name packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	if ($APRS_Verbose) { print color('grey12'), "  APRS_Make_Object $Name sent.\n", color('reset'); }
}

sub APRS_Make_Item {
	my ($Name, $Latitude, $Longitude, $Symbol, $Speed, 
		$Course, $Altitude, $Alive, $UseCompression, $PosAmbiguity, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "  APRS-IS does not exist.\n", color('reset');
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "  APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		APRS_connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	
	my $APRS_item = Ham::APRS::FAP::make_item(
		$Name, # Name
		$Latitude,
		$Longitude,
		$Symbol, # symbol
		$Speed, # speed
		$Course,
		$Altitude, # altitude
		$Alive,
		$UseCompression,
		$PosAmbiguity,
		$Comment
	);
	if ($APRS_Verbose > 0) {print "  APRS Item is: $APRS_item\n";}
	my $Packet = sprintf('%s>APTR01:%s', $APRS_Callsign, $APRS_item);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "*** Error *** sending APRS-IS Item $Name packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	if ($APRS_Verbose) { print color('grey12'), "  APRS_Make_Item $Name sent.\n", color('reset'); }
}

sub APRS_Update_TG {
	my ($TG) = @_;
	APRS_Make_Item($Callsign . '/' . $APRS_Suffix, $My_Latitude, $My_Longitude, $My_Symbol, -1, -1, undef,
		1, 0, 0, $My_Freq . 'MHz ' . $My_Tone . ' ' . $My_Offset . ' NAC-' . $My_NAC . ' ' .
		' TG=' . $TG . ' ' . $My_Comment . ' alt ' . $My_Altitude . 'm');
}

sub APRS_Update {
	my ($TG) = @_;
	# Station position as Object
	if ($APRS_Verbose) { print color('green'), "APRS-IS Update:\n", color('reset'); }
	APRS_Make_Object(
		$Callsign . '/' . $APRS_Suffix,
		0,
		$My_Latitude,
		$My_Longitude,
		$My_Symbol,
		-1,
		-1,
		undef,
		1,
		0,
		0,
		$My_Freq . 'MHz ' . $My_Tone . ' ' . $My_Offset . ' NAC-' . $My_NAC . ' ' .
		' TG=' . $TG . ' ' . $My_Comment . ' alt ' . $My_Altitude . 'm');

	# Objects and Items refresh list loading file.
	my $fh;
	if ($APRS_Verbose) { print color('grey12'), "  Loading APRS File...\n", color('reset'); }
	if (!open($fh, "<", $APRS_File)) {
		warn color('red'), "  *** Error ***   $APRS_File File not found.\n", color('reset');
	} else {
		if ($APRS_Verbose) { print color('grey12'), "  File Ok.\n", color('reset'); }
		my %result;
		while (my $Line = <$fh>) {
			chomp $Line;
			## skip comments and blank lines and optional repeat of title line
			next if $Line =~ /^\#/ || $Line =~ /^\s*$/ || $Line =~ /^\+/;
			#split each line into array
			my @Line = split(/\t+/, $Line);
			my $Index = $Line[0];
			$APRS{$Index}{'Name'} = $Line[0];
			$APRS{$Index}{'Type'} = $Line[1];
			$APRS{$Index}{'Lat'} = $Line[2];
			$APRS{$Index}{'Long'} = $Line[3];
			$APRS{$Index}{'Speed'} = $Line[4];
			$APRS{$Index}{'Course'} = $Line[5];
			if ($Line[6] >= 0) {
				$APRS{$Index}{'Altitude'} = $Line[6];
			} else {
				$APRS{$Index}{'Altitude'} = -1;
			}
			$APRS{$Index}{'Alive'} = $Line[7];
			$APRS{$Index}{'Symbol'} = $Line[8];
			$APRS{$Index}{'Comment'} = $Line[9];
			if ($APRS_Verbose > 1) {
				print "  APRS Index = $Index";
				print ", Name = $APRS{$Index}{'Name'}";
				print ", Type = $APRS{$Index}{'Type'}";
				print ", Lat = $APRS{$Index}{'Lat'}";
				print ", Long = $APRS{$Index}{'Long'}";
				print ", Speed = $APRS{$Index}{'Speed'}";
				print ", Course = $APRS{$Index}{'Course'}";
				print ", Altitude = $APRS{$Index}{'Altitude'}";
				print ", Alive = $APRS{$Index}{'Alive'}";
				print ", Symbol = $APRS{$Index}{'Symbol'}";
				print ", Comment = $APRS{$Index}{'Comment'}";
				print "\n";
			}
			if ($APRS{$Index}{'Type'} eq 'O') {
				APRS_Make_Object(
					$APRS{$Index}{'Name'},
					0, # Timestamp
					$APRS{$Index}{'Lat'},
					$APRS{$Index}{'Long'},
					$APRS{$Index}{'Symbol'},
					$APRS{$Index}{'Speed'},
					$APRS{$Index}{'Course'},
					$APRS{$Index}{'Altitude'},
					$APRS{$Index}{'Alive'},
					0, # Compression 
					0, # Position Ambiguity
					$APRS{$Index}{'Comment'},
				);
			}
			if ($APRS{$Index}{'Type'} eq 'I') {
				APRS_Make_Item(
					$APRS{$Index}{'Name'},
					$APRS{$Index}{'Lat'},
					$APRS{$Index}{'Long'},
					$APRS{$Index}{'Symbol'},
					$APRS{$Index}{'Speed'},
					$APRS{$Index}{'Course'},
					$APRS{$Index}{'Altitude'},
					$APRS{$Index}{'Alive'},
					0, # Compression 
					0, # Position Ambiguity
					$APRS{$Index}{'Comment'},
				);
			}




		}
		close $fh;
		if ($APRS_Verbose > 2) {
			foreach my $key (keys %APRS)
			{
				print color('green'), "  Key field: $key\n";
				foreach my $key2 (keys %{$APRS{$key}})
				{
					print "  - $key2 = $APRS{$key}{$key2}\n";
				}
				print color('reset');
			}
		}
	}
}



##################################################################
# Serial #########################################################
##################################################################
sub Read_Serial { # Read the serial port, look for 0x7E characters and extract data between them.
	if ($Mode |= 0) { return; }
	my $NumChars;
	my $SerialBuffer;
	($NumChars, $SerialBuffer) = $SerialPort->read(255);
	if ($NumChars >= 1 ){ #Perl data Arrival test.
		#Bytes_2_HexString($SerialBuffer);
		for (my $x = 0; $x <= $NumChars; $x++) {
			if (ord(substr($SerialBuffer, $x, 1)) == 0x7E) {
				if (length($HDLC_Buffer) > 0) {
					HDLC_Rx($HDLC_Buffer); # Process a full data stream.
					print "Serial Str Data Rx len() = " . length($HDLC_Buffer) . "\n";
				}
				print "Read_Serial len = " . length($HDLC_Buffer) . "\n";
				$HDLC_Buffer = ""; # Clear Rx buffer.
			} else {
				# Add Bytes until the end of data stream (0x7E):
				$HDLC_Buffer .= substr($SerialBuffer, $x, 1);
			}
		}
	}
}

##################################################################
# HDLC ###########################################################
##################################################################
sub HDLC_Rx {
	my ($Buffer, $RemoteHostIP) = @_;
	my $RTRTOn;
	my $OpCode;
	my $OpArg;
	my $SiteID;
	my $IsChannelChange;
	my $Channel;
	my $IsStart;
	my $IsEnd;

	if ($Mode == 0) { # Serial Mode
		# CRC CCITT test patterns:
		#my $DataC;
		#$DataC = "7EFD01BED27E"; # RR
		#$DataC = "7EFD3F430A7E"; # SABM
		#$Buffer = chr(0x7E) . chr(0xFD) . chr(0x3F) . chr(0x43) . chr(0x0A) . chr(0x7E);
		#$Buffer = chr(0x7E) . chr(0xFD) . chr(0x03) . chr(0x00) . chr(0x00) . 
			#chr(0x7D) . chr(0x5E) . 
			#chr(0x11) . chr(0x11) .
			#chr(0x7D) . chr(0x5D) . chr(0x22) . chr(0x22) . 
			#chr(0x7D) . chr(0x45) . chr(0x33) . chr(0x33) .
			#chr(0x7E);

		#$Buffer = chr(0x7E) . $Buffer . chr(0x7E);

		#print "A ", sprintf("0x%x", ord(substr($Buffer, 0, 1))), "\n";
		#print "B ", sprintf("0x%x", ord(substr($Buffer, 1, 1))), "\n";
		#print "C ", sprintf("0x%x", ord(substr($Buffer, 2, 1))), "\n";
		#print "D ", sprintf("0x%x", ord(substr($Buffer, 3, 1))), "\n";
		#print "E ", sprintf("0x%x", ord(substr($Buffer, 4, 1))), "\n";
		#print "F ", sprintf("0x%x", ord(substr($Buffer, 5, 1))), "\n";
	
		#print "Buffer = $Buffer\n";
		#print "Len(Buffer) = ", length($Buffer), "\n";
		#my $res = HexStr_2_Str($Buffer);

		if (substr($Buffer, 0, 7) eq "!RESET!") {
			my $BoardID = ord(substr($Buffer, 7, 1));
			warn color('red'), "*** Warning ***   HDLC_Rx Board $BoardID made a Reset!\n", color('reset');
			return;
		}

		# Byte Stuff
		$Buffer =~ s/\}\^/\~/g; # 0x7D 0x5E to 0x7E
		$Buffer =~ s/\}\]/\}/g; # 0x7D 0x5D to 0x7D
		#print "Byte Stuff, Len(Buffer) = ", length($Buffer), "\n";
		
		# Show Raw data.
		#Bytes_2_HexString($Buffer);
	
		# CRC CCITT.
		if (length($Buffer) < 2) {
			warn color('red'), "*** Warning ***   HDLC_Rx Warning Buffer < 2 Bytes.\n", color('reset');
			return;
		}
		$Message = substr($Buffer, 0, length($Buffer) - 2);
		#print "Len(Message) = ", length($Message), "\n";
		my $CRC_Rx = 256 * ord(substr($Buffer, length($Buffer) - 2, 1 )) + 
			ord(substr($Buffer, length($Buffer) - 1, 1));
		#print "CRC_Rx  = $CRC_Rx\n";
		if (length($Message) == 0) {
			warn color('red'), "*** Warning ***   HDLC_Rx Message is Null.\n", color('reset');
			return;
		}
		my $CRC_Gen = CRC_CCITT_Gen($Message);
		#print "CRC_Gen = $CRC_Gen\n";
		#print "CRCH ", sprintf("0x%x", ord(substr($CRC_Gen, 0, 1))), "\n";
		#print "CRCL ", sprintf("0x%x", ord(substr($CRC_Gen, 1, 1))), "\n";
		#print "Calc CRC16 in hex: ", unpack('H*', pack('S', $Message)), "\n";
		if ($CRC_Rx != $CRC_Gen) {
			warn color('red'), "*** Warning ***   HDLC_Rx CRC does not match " . $CRC_Rx . " <> " .
			$CRC_Gen . ".\n", color('reset');
			return;
		}
	} else {
		$Message = $Buffer;
	}

	if ($HDLC_Verbose >= 3) {
		print "HDLC_Rx Message.\n";
		Bytes_2_HexString($Message);
	}
	if ($RecordEnable == 1) { # Audio recoreder
		RecorderBytes_2_HexString($Message);
	}
	# 01 Address
	my $Address = ord(substr($Message, 0, 1));
	#print "Address = ", sprintf("0x%x", $Address), "\n";
	#Bytes_2_HexString($Message);
	
	$Quant{'FrameType'} = ord(substr($Message, 1, 1));
	#print "Frame Types = ", sprintf("0x%x", $Quant{'FrameType'}), "\n";
	switch ($Quant{'FrameType'}) {
		case 0x01 { # RR Receive Ready.
			if ($Address == 253) {
				if ((($Mode == 1) and $STUN_Connected and ($HDLC_TxTraffic == 0))
					or (($Mode == 0) and ($HDLC_TxTraffic == 0))) {
					if ($HDLC_Verbose) {print color('green'), "  0x01 calling HDLC_Tx_RR\n", color('reset');}
					HDLC_Tx_RR();
				}
#				$RR_NextTimer = time() + $RR_TimerInterval;
			} else {
				warn color('red'), "*** Warning ***   HDLC_Rx RR Address 253 != $Address\n", color('reset');
			}
			return;
		}
		case 0x03 { # User Information.
			#print "Case 0x03 UI.", substr($Message, 2, 1), "\n";
			#Bytes_2_HexString($Message);
			$Quant{'LocalRx'} = 1;
			$Quant{'LocalRx_Time'} = getTickCount();
			switch (ord(substr($Message, 2, 1))) {
				case 0x00 { #Network ID, NID Start/Stop.
					if ($HDLC_Verbose) {
						print "UI 0x00 NID Start/Stop";
					}
					if (ord(substr($Message, 3, 1)) != 0x02) {warn "Debug this with the XML.\n";}
					if (ord(substr($Message, 4, 1)) == $C_RTRT_Enabled) {
						$RTRTOn = 1;
						if ($HDLC_Verbose) {
							print ", RT/RT Enabled";
						}
					}
					if (ord(substr($Message, 4, 1)) == $C_RTRT_Disabled) {
						$RTRTOn = 0;
						if ($HDLC_Verbose) {
							print ", RT/RT Disabled";
						}
					}
					$OpCode = ord(substr($Message, 5, 1));
					$OpArg = ord(substr($Message, 6, 1));
					switch ($OpCode) {
						case 0x06 { # ChannelChange
							$IsChannelChange = 1;
							$Channel = $OpArg;
							#if ($HDLC_Verbose) {
								print ", HDLC Channel change to $Channel\n";
							#}
						}
						case 0x0C { # StartTx
							$IsStart = 1;
							if ($HDLC_Verbose) {
								print ", HDLC ICW Start";
							}
						}
						case 0x0D {
							if ($HDLC_Verbose) {
								print ", HDLC DIU Monitor";
							}
						}
						case 0x25 { # StopTx
							$IsEnd = 1;
							if ($HDLC_Verbose) {
								print ", HDLC ICW Terminate";
							}
							$Quant{'LocalRx'} = 0;
							if ($Quant{'Tail'} == 1) {
								$Pending_CourtesyTone = 1;
								$Quant{'Tail'} = 0;
								print ", HDLC Stop 0x25 Tail Rx\n";
								if ($HDLC_Verbose) { Bytes_2_HexString($Message) };
							} else {
								print ", HDLC Stop 0x25 Tail Rx (dupe).\n";
								if ($HDLC_Verbose) { Bytes_2_HexString($Message) };
							}
						}
					}
					if ($HDLC_Verbose) {
						print ", Linked Talk Group $LinkedTalkGroup";
					}
					switch ($OpArg) {
						case 0x00 { # AVoice
							if ($HDLC_Verbose) {print ", Analog Voice\n";}
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 0;
							RDAC_Tx(0);
						}
						case 0x06 { # TMS Data Payload
							if ($HDLC_Verbose) {
								print ", TMS Data Payload\n";
								Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							Tx_to_Network($Message);
							#RDAC_Tx(0);
						}
						case 0x0B { # DVoice
							if ($HDLC_Verbose) {print ", Digital Voice\n";}
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
							Tx_to_Network($Message);
							RDAC_Tx($LinkedTalkGroup);
						}
						case 0x0C { # TMS
							if ($HDLC_Verbose) {
								print ", TMS\n";
								Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							Tx_to_Network($Message);
							#RDAC_Tx();
						}
						case 0x0D { # From Comparator Start
							if ($HDLC_Verbose) {
								print ", From Comparator Start\n";
								Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							#Tx_to_Network($Message);
							#RDAC_Tx(0);
						}
						case 0x0E { # From Comprator Stop
							if ($HDLC_Verbose) {
								print ", From Comparator Stop\n";
								Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							#Tx_to_Network($Message);
							#RDAC_Tx(0);
						}
						case 0x0F { # Page
							if ($HDLC_Verbose) {print ", Page\n";}
							$Quant{'IsPage'} = 1;
							Tx_to_Network($Message);
							RDAC_Tx($LinkedTalkGroup);
						}
					}
					if ($HDLC_Verbose) {
						print "\n";
					}
				}
				case 0x01 {
					warn color('yellow'), "UI 0x01 Undefined.\n", color('reset');
				}
				case 0x59 {
					warn color('yellow'), "UI 0x59 Undefined.\n", color('reset');
					return;
				}
				case 0x60 {
					if ($HDLC_Verbose) {print "UI 0x60 Voice Header part 1.\n";}
					if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Message);}
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RTRT_Enabled
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Enabled";}
						}
						case 0x04 { # RTRT_Disabled
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Disabled";}
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x00 { # AVoice
							if ($HDLC_Verbose) {print ", Analog Voice";}
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 0;
						}
						case 0x0B { # DVoice
							if ($HDLC_Verbose) {print ", Digital Voice";}
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
						}
						case 0x0F { # Page
							if ($HDLC_Verbose) {print ", Page";}
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 1;
						}
					}
					$SiteID = ord(substr($Message,7 ,1));
					switch ($SiteID) {
						case 0x00 { # DIU3000
							if ($HDLC_Verbose) {print ", Source: DIU 3000";}
						}
						case 0xC2 { # Quantar
							if ($HDLC_Verbose) {print ", Source: Quantar";}
						}
					}
					if (ord(substr($Message, 9, 1)) == 1) {
						$Quant{'RSSI_Is_Valid'} = 1;
						$Quant{'RSSI'} = ord(substr($Message, 8, 1));
						$Quant{'InvertedSignal'} = ord(substr($Message, 10, 1));
						if ($HDLC_Verbose) {
							print ", RSSI = $Quant{'RSSI'}\n";
							print ", Inverted signal = $Quant{'InvertedSignal'}\n";
						}
					} else {
						$Quant{'RSSI_Is_Valid'} = 0;
						if ($HDLC_Verbose) {print ".\n";}
					}
					if ( ($Quant{'IsDigitalVoice'} == 1) or ($Quant{'IsPage'} == 1) ) {
						Tx_to_Network($Message);
					}
				}

				case 0x61 {
					if ($HDLC_Verbose) { print "UI 0x61 Voice Header part 2.\n"; }
					if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Message);}
					#my $TGID = 256 * ord(substr($Message, 4, 1)) + ord(substr($Message, 3, 1));;
					#warn "Not true TalkGroup ID = $TGID\n";
					if ( ($Quant{'IsDigitalVoice'} == 1) or ($Quant{'IsPage'} == 1) ) {
						Tx_to_Network($Message);
					}
				}

				case 0x62 { # dBm, RSSI, BER.
					if ($HDLC_Verbose) {print "UI 0x62 IMBE Voice part 1.\n";}
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RT/RT Enable
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Enabled";}
						}
						case 0x04 { # RT/RT Disable
							$RTRTOn = 0;
							if ($HDLC_Verbose) {print "RT/RT Disabled";}
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x0B { # DVoice
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
							if ($HDLC_Verbose) {print ", Digital Voice";}
						}
						case 0x0F { # Page
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 1;
							if ($HDLC_Verbose) {print ", Page";}
						}
					}
					$SiteID = ord(substr($Message, 7, 1));
					switch ($SiteID) {
						case 0x00 { # DIU3000
							if ($HDLC_Verbose) {print ", SiteID: DIU 3000";}
						}
						case 0xC2 { # Quantar
							if ($HDLC_Verbose) {print ", SiteID: Quantar";}
						}
					}
					if (ord(substr($Message, 9, 1))) {
						$Quant{'RSSI_Is_Valid'} = 1;
						$Quant{'RSSI'} = ord(substr($Message, 8, 1));
						$Quant{'InvertedSignal'} = ord(substr($Message, 10, 1));
						$Quant{'CandidateAdjustedMM'} = ord(substr($Message, 11, 1));
						if ($HDLC_Verbose) {
							print ", RSSI = $Quant{'RSSI'}";
							print ", Inverted signal = $Quant{'InvertedSignal'}";
						}
					} else {
						$Quant{'RSSI_Is_Valid'} = 0;
					}
					if ($HDLC_Verbose) {print "\n";}
					$Quant{'Speech'} = ord(substr($Message, 12, 11));
					$Quant{'Raw0x62'} = $Message;
					$Quant{'SuperFrame'} = $Message;
					$Quant{'SourceDev'} = ord(substr($Message, 23, 1));
					Tx_to_Network($Message);
				}
				case 0x63 {
					if ($HDLC_Verbose) {print "UI 0x63 IMBE Voice part 2.\n";}
					$Quant{'Speech'} = ord(substr($Message, 3, 11));
					$Quant{'Raw0x63'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					$Quant{'SourceDev'} = ord(substr($Message, 14, 1));
					Tx_to_Network($Message);
				}
				case 0x64 { # Group/Direct Call, Clear/Private.
					if ($HDLC_Verbose) {print "UI 0x64 IMBE Voice part 3 + link control.\n";}
					if (ord(substr($Message, 3, 1)) & 0x80) {
						$Quant{'Encrypted'} = 1;
					}
					if (ord(substr($Message, 3, 1))& 0x40) {
						$Quant{'Explicit'} = 1;
					}
					$Quant{'IsTGData'} = 0;
					switch (ord(substr($Message, 3, 1)) & 0x0F) {
						case 0x00 { # Group voice channel user.
							$Quant{'IsTGData'} = 1;
							$Quant{'IndividualCall'} = 0;
						}
						case 0x02 { # Group voice channel update.
							$Quant{'IndividualCall'} = 0;
						}
						case 0x03 { # Unit to unit voice channel user.
							$Quant{'IndividualCall'} = 1;
						}
						case 0x04 { # Group voice channel update - explicit.
							$Quant{'IndividualCall'} = 1;
						}
						case 0x05 { # Unit to unit answer request.
							$Quant{'IndividualCall'} = 1;
						}
						case 0x06 { # Telephone interconnect voice channel user.
							print "Misterious packet.";
						}
						case 0x07 { # Telephone interconnect answer request.
							print "Telephone interconnect answer request.\n";
						}
						case 0x0F { # Call termination/cancellation.
							print "Call termination/cancellation.\n";
						}
						case 0x10 {
							print "Group Affiliation Query\n";
						}
						case 0x11 {
							print "Unit Registration Command\n";
						}
						case 0x12 {
							print "Unit Authentication Command\n";
						}
						case 0x13 {
							print "Status Query\n";
						}
						case 0x14{ 
							print "Status Update\n";
						}
						case 0x15 {
							print "Message Update\n";
						}
						case 0x16 {
							print "Call Alert\n";
						}
						case 0x17 {
							print "Extended Function Command\n";
						}
						case 0x18 {
							print "Channel Identifier Update\n";
						}
						case 0x19 {
							print "Channel Identifier Update ñ Explicit (LCCIUX)\n";
						}
						case 0x20 {
							print "System Service Broadcast\n";
						}
						case 0x21 {
							print "Secondary Control Channel Broadcast\n";
						}
						case 0x22 {
							print "Adjacent Site Status Broadcast\n";
						}
						case 0x23 {
							print "RFSS Status Broadcast\n";
						}
						case 0x24 {
							print "Network Status Broadcast\n";
						}
						case 0x25 {
							print "Protection Parameter Broadcast\n";
						}
						case 0x26 {
							print "Secondary Control Channel Broadcast - Explicit (LCSCBX)\n";
						}
						case 0x27 {
							print "Adjacent Site Status Broadcast ñ Explicit (LCASBX)\n";
						}
						case 0x28 {
							print "RFSS Status Broadcast ñ Explicit (LCRSBX)\n";
						}
						case 0x29 {
							print "Network Status Broadcast ñ Explicit (LCNSBX)\n";
						}
					}
					$Quant{'ManufacturerID'} = ord(substr($Message, 4, 1));
					ManufacturerName ($Quant{'ManufacturerID'});
					if (ord(substr($Message, 5, 1)) and 0x80) {
						$Quant{'Emergency'} = 1;
					} else {
						$Quant{'Emergency'} = 0;
					}
					if (ord(substr($Message, 5, 1)) and 0x40) {
						$Quant{'Protected'} = 1;
					} else {
						$Quant{'Protected'} = 0;
					}
					if (ord(substr($Message, 5, 1)) and 0x20) {
						$Quant{'FullDuplex'} = 1;
					} else {
						$Quant{'FullDuplex'} = 0;
					}
					if (ord(substr($Message, 5, 1)) and 0x10) {
						$Quant{'PacketMode'} = 1;
					} else {
						$Quant{'PacketMode'} = 0;
					}
					$Quant{'Priority'} = ord(substr($Message, 5, 1));
					#switch (ord(substr($Message, 6, 1))) {
					#	case Implicit_MFID {
					#
					#	}
					#	case Explicit_MFID {
					#
					#	}
					#}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'SuperFrame'} .= $Message;
					$Quant{'Raw0x64'} = $Message;
					Tx_to_Network($Message);
				}
				case 0x65 { # Talk Group.
					if ($HDLC_Verbose) {print "UI 0x65 IMBE Voice part 4 + link control.\n";}
					#Bytes_2_HexString($Message);
					if ($Quant{'IsTGData'} == 1) {
						my $MMSB = ord(substr($Message, 3, 1));
						my $MSB = ord(substr($Message, 4, 1));
						my $LSB = ord(substr($Message, 5, 1));
						$Quant{'AstroTalkGroup'} = ($MSB << 8) | $LSB;
						$Quant{'DestinationRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

						# Leave previous line empty.
						if ($Quant{'IndividualCall'}) {
							if ($HDLC_Verbose) {
								print "Destination ID = $Quant{'DestinationID'}\n";
							}
						} else {
							if ($HDLC_Verbose) {
								print "AstroTalkGroup = $Quant{'AstroTalkGroup'}\n";
							}
							AddLinkTG($Quant{'AstroTalkGroup'}, 0);
						}
					}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x65'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x66 { # Source ID.
					if ($HDLC_Verbose) {print "UI 0x66 IMBE Voice part 5. + link control.\n";}
					# Get Called ID.
					if ($Quant{'IsTGData'}) {
						my $MMSB = ord(substr($Message, 3, 1));
						my $MSB = ord(substr($Message, 4, 1));
						my $LSB = ord(substr($Message, 5, 1));
						$Quant{'SourceRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

						# Leave previous line empty.
						if ($HDLC_Verbose) {
							print "HDLC SourceRadioID = $Quant{'SourceRadioID'}\n";
						}
#						QSO_Log($RemoteHostIP);
					} else {
						if ($Verbose) {warn "Misterious packet 0x66\n";}
					}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x66'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x67 { # TBD
					if ($HDLC_Verbose) {print "UI 0x67 IMBE Voice part 6 + link control.\n";}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x67'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x68 {
					if ($HDLC_Verbose) {print "UI 0x68 IMBE Voice part 7 + link control.\n";}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x68'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x69 {
					if ($HDLC_Verbose) {print "UI 0x69 IMBE Voice part 8 + link control.\n";}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x69'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x6A { # Low speed data Byte 1.
					if ($HDLC_Verbose) {print "UI 0x6A IMBE Voice part 9 + low speed data 1.\n";}
					$Quant{'LSD0'} = ord(substr($Message, 4, 1));
					$Quant{'LSD1'} = ord(substr($Message, 5, 1));
					$Quant{'Speech'} = ord(substr($Message, 6, 11));
					$Quant{'Raw0x6A'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					$Quant{'Tail'} = 1;
					Tx_to_Network($Message);
				}
				case 0x6B { # dBm, RSSI, BER.
					if ($HDLC_Verbose) {print "UI 0x6B IMBE Voice part 10.\n";}
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RT/RT Enable
							$RTRTOn = 1;
							if ($HDLC_Verbose) {print "RT/RT Enabled";}
						}
						case 0x04 { # RT/RT Disable
							$RTRTOn = 0;
							if ($HDLC_Verbose) {print "RT/RT Disabled";}
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x0B { # DVoice
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
							if ($HDLC_Verbose) {print ", Digital Voice";}
						}
						case 0x0F { # Page
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 1;
							if ($HDLC_Verbose) {print ", Page";}
						}
					}
					$SiteID = ord(substr($Message, 7, 1));
					switch ($SiteID) {
						case 0x00 { # DIU3000
							if ($HDLC_Verbose) {print ", SiteID: DIU 3000";}
						}
						case 0xC2 { # Quantar
							if ($HDLC_Verbose) {print ", SiteID: Quantar";}
						}
					}
					$Quant{'RSSI'} = ord(substr($Message, 8, 1));
					if (ord(substr($Message, 9, 1))) {
						$Quant{'RSSI_Is_Valid'} = 1;
						if ($HDLC_Verbose) {
							print ", RSSI = $Quant{'RSSI'}";
							print ", Inverted signal = $Quant{'InvertedSignal'}";
						}
					} else {
						$Quant{'RSSI_Is_Valid'} = 0;
					}
					if ($HDLC_Verbose) {print "\n";}
					$Quant{'InvertedSignal'} = ord(substr($Message, 10, 1));
					$Quant{'CandidateAdjustedMM'} = ord(substr($Message, 11, 1));
					$Quant{'Speech'} = ord(substr($Message, 12, 11));
					$Quant{'Raw0x6B'} = $Message;
					$Quant{'SourceDev'} = ord(substr($Message, 23, 1));
					$Quant{'SuperFrame'} = $Message;
					Tx_to_Network($Message);
				}
				case 0x6C {
					if ($HDLC_Verbose) {print "UI 0x6C IMBE Voice part 11.\n";}
					$Quant{'Speech'} = ord(substr($Message, 3, 11));
					$Quant{'Raw0x6C'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x6D {
					if ($HDLC_Verbose) {print "UI 0x6D IMBE Voice part 12 + encryption sync.\n";}
					$Quant{'EncryptionI'} = ord(substr($Message, 3, 4));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x6D'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x6E {
					if ($HDLC_Verbose) {print "UI 0x6E IMBE Voice part 13 + encryption sync.\n";}
					$Quant{'EncryptionII'} = ord(substr($Message, 3,4));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x6E'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x6F {
					if ($HDLC_Verbose) {print "UI 0x6F IMBE Voice part 14 + encryption sync.\n";}
					$Quant{'EncryptionIII'} = ord(substr($Message, 3,4));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x6F'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x70 { # Algorithm.
					if ($HDLC_Verbose) {print "UI 0x70 IMBE Voice part 15 + encryption sync.\n";}
					$Quant{'Algorythm'} = ord(substr($Message, 3,1));
					AlgoName ($Quant{'Algorythm'});
					$Quant{'KeyID'} = ord(substr($Message, 4,2));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x70'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x71 {
					if ($HDLC_Verbose) {print "UI 0x71 IMBE Voice part 16 + encryption sync.\n";}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x71'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x72 {
					if ($HDLC_Verbose) {print "UI 0x72 IMBE Voice part 17 + encryption sync.\n";}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x72'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					Tx_to_Network($Message);
				}
				case 0x73 { # Low speed data Byte 2.
					if ($HDLC_Verbose) {print "UI 0x73 IMBE Voice part 18 + low speed data 2.\n";}
					$Quant{'LSD2'} = ord(substr($Message, 4, 1));
					$Quant{'LSD3'} = ord(substr($Message, 5, 1));
					$Quant{'Speech'} = ord(substr($Message, 6, 11));
					$Quant{'Raw0x73'} = $Message;
					$Quant{'SuperFrame'} .= $Message;
					$Quant{'Tail'} = 1;
					Tx_to_Network($Message);
				}
				case 0x80 {
					print color('yellow'), "UI 0x80.\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
					#print "Raw " . substr($Message, 1, length($Message)) . '\n';
					#my $MMSB = ord(substr($Message, 51, 1));
					#my $MSB = ord(substr($Message, 52, 1));
					#my $LSB = ord(substr($Message, 53, 1));
					#my $SourceID = ($MMSB << 16) | ($MSB << 8) | $LSB;
					#print "SourceID $SourceID\n";
				}
				case 0x85 {
					print color('yellow'), "UI 0x85.\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
					#print "Raw " . substr($Message, 1, length($Message)) . '\n';
					#print "Alias " . substr($Message, 11, 4) . substr($Message, 16, 4) . '\n';
				}
				case 0x87 {
					print color('yellow'), "UI 0x87.\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0x88 {
					print color('yellow'), "UI 0x88.\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0x8D {
					print color('yellow'), "UI 0x8D.\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0x8F {
					print color('yellow'), "UI 0x8F.\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0xA1 { # Page affliate request.
					print color('yellow'), "UI 0xA1 Page call.\n", color('reset');
					my $MMSB = ord(substr($Message, 15, 1));
					my $MSB = ord(substr($Message, 16, 1));
					my $LSB = ord(substr($Message, 17, 1));
					$Quant{'DestinationRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

					# Leave previous line empty.
					$MMSB = ord(substr($Message, 18, 1));
					$MSB = ord(substr($Message, 19, 1));
					$LSB = ord(substr($Message, 20, 1));
					$Quant{'SourceRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

					# Leave previous line empty.
					print color('yellow'), "  Source $Quant{'SourceRadioID'}" .
						", Dest $Quant{'DestinationRadioID'}", color('reset');
					my $Flag = ord(substr($Message, 11, 1));
					switch ($Flag) {
						case 0x98 { # STS
							print " Flag = STS\n";
							#$StatusIndex = ord(substr(Message, 13, 1));
						}
						case 0x9F { # Page
							print " Flag = Page\n";
						}
						case 0xA0 { # Page Ack.
							print " Flag = Page Ack\n";
							#if ($Quant{'DestinationRadioID'} == $MasterRadioID) {Then
								#PageAck_Tx $Quant{'SourceRadioID'},
								#$Quant{'DestinationRadioID'}, 1;
							#}
						}
						case 0xA7 {
							print color('red'), " Flag = EMERGENCY\n", color('reset');
						}
					}
					switch (ord(substr($Message, 12, 1))) {
						case 0x00 { # Individual Page
							print color('yellow'), "  Individual Page 12\n", color('reset');
							Bytes_2_HexString($Message);

						}
						case 0x90 { #Group Page
							print color('yellow'), "  Group Page 12\n", color('reset');
							Bytes_2_HexString($Message);
						}
					}
					switch (ord(substr($Message, 13, 1))) {
						case 0x00 { # Individual Page
							print color('yellow'), "  Individual Page 13.\n", color('reset');
						}
						case 0x80 { # Group Page
							print color('yellow'), "  Group Page 13.\n", color('reset');
						}
						case 0x9F { # Individual Page Ack
							print color('yellow'), "  Individual Page Ack 13.\n", color('reset');
						}
					}
					Tx_to_Network($Message);

				} else {
					print color('yellow'), "UI else 0x" . ord(substr($Message, 2, 1)) . "\n", color('reset');
					Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
			}
		}
		case 0x3F { # SABM Rx
			if ($HDLC_Verbose) {print color('green'), "HDLC_Rx SABM.\n", color('reset');}
			if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Message);}
			$HDLC_Handshake = 0;
			$RR_TimerEnabled = 0;
			if ($HDLC_Verbose > 1) {print "  Calling HDLC_Tx_UA\n";}
			HDLC_Tx_UA(253);
			$SABM_Counter = $SABM_Counter + 1;
			if ($SABM_Counter > 3) {
				HDLC_Tx_Serial_Reset();
				$SABM_Counter = 0;
			}
		}
		case 0x73 { #
			if ($HDLC_Verbose) {print color('green'), "HDLC_Rx UA (case 0x73 Unumbered Ack).\n", color('reset');}
			if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Message);}
		}
		case 0xBF { # XID Quantar to DIU identification packet.
			if ($HDLC_Verbose) {print color('green'), "HDLC_Rx XID.\n", color('reset');}
			if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Message);}
			$SABM_Counter = 0;
			my $MessageType = ord(substr($Message, 2, 1));
			my $StationSiteNumber = (int(ord(substr($Message, 3, 1))) - 1) / 2;
			my $StationType = ord(substr($Message, 4, 1));
			if ($StationType == $C_Quantar) {
				if ($HDLC_Verbose > 1) {print "  Station type = Quantar.\n";}
			}
			if ($StationType == $C_DIU3000) {
				if ($HDLC_Verbose > 1) {print "  Station type = DIU3000.\n";}
			}
			if ($HDLC_Verbose) {print color('yellow'), "  0x0B calling HDLC_Tx_XID\n", color('reset');}
			HDLC_Tx_XID(0x0B);
			$HDLC_Handshake = 1;
			$RR_TimerEnabled = 1;
			if ($HDLC_Verbose) {print color('yellow'), "  0x0B calling HDLC_Tx_RR\n", color('reset');}
#			HDLC_Tx_RR();
		}
	}
	if ($HDLC_Verbose) {
		print "----------------------------------------------------------------------\n";
	}
}


sub RR_Timer { # HDLC Receive Ready keep alive.
	(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();
	if (time() >= $RR_NextTimer) {
		print color('green'), "RR_Timer event\n", color('reset');
		if (($RR_TimerEnabled == 1) and $HDLC_Handshake) {
			#print "  RR Timed out @{[int time - $^T]}\n";
			if (($Mode == 0) or (($Mode == 1) and $STUN_Connected)) {
				if ($HDLC_Verbose) {
					print "$hour:$min:$sec Send RR by timer.\n";
					print "Mode = $Mode, STUN_Connected = $STUN_Connected, and HDLC_TxTraffic = $HDLC_TxTraffic\n";
				}
				HDLC_Tx_RR();
				if ($HDLC_Verbose) {
					print "----------------------------------------------------------------------\n";
				}
			}
		}
		$RR_NextTimer = time() + $RR_TimerInterval;
	}
}

sub HDLC_Tx {
	my ($Data) = @_;
	my $CRC;
	my $MSB;
	my $LSB;
	if ($Mode == 0) { # Mode = 0 Serial
		if ($HDLC_Verbose) {print color('green'), "HDLC_Tx.\n", color('reset');}
		if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Data);}
		$CRC = CRC_CCITT_Gen($Data);
		$MSB = int($CRC / 256);
		$LSB = $CRC - $MSB * 256;
		$Data .= chr($MSB) . chr($LSB);
		# Byte Stuff
		$Data =~ s/\}/\}\]/g; # 0x7D to 0x7D 0x5D
		$Data =~ s/\~/\}\^/g; # 0x7E to 0x7D 0x5E
		if ($HDLC_Verbose >= 2) {print "Len(Data) = ", length($Data), "\n";}
		$SerialPort->write($Data . chr(0x7E));
		my $SerialWait = (8.0 / 9600.0) * length($Data); # Frame length delay.
		nanosleep($SerialWait * 1000000000);
		if ($HDLC_Verbose) {print "Serial nanosleep = $SerialWait\n";}
	} elsif ($Mode == 1) { # Mode = 1 STUN
		STUN_Tx($Data);
	}
	if ($HDLC_Verbose) {print "HDLC_Tx Done.\n";}
}

sub HDLC_Tx_Serial_Reset {
	if ($Mode == 0) {
		#$serialport->write(chr(0x7D) . chr(0xFF));
		$SerialPort->pulse_rts_on(50);
		$HDLC_TxTraffic = 0; 
		print color('yellow'), "HDLC_Tx_Serial_Reset Sent.\n", color('reset');
	}
}

sub HDLC_Tx_UA {
	my ($Address) = @_;
	if ($HDLC_Verbose) {print color('green'), "HDLC_Tx_UA.\n", color('reset');}
	my $Data = chr($Address) . chr(0x73);
	HDLC_Tx ($Data);
}

sub HDLC_Tx_XID {
	my ($Address) = @_;
	if ($HDLC_Verbose) {print color('green'), "HDLC_Tx_XID.\n", color('reset');}
	my $ID = 13;
	my $Data = chr($Address) . chr(0xBF) . chr(0x01) . chr($ID * 2 + 1) . chr(0x00) . 
		chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0xFF);
	HDLC_Tx ($Data);
}

sub HDLC_Tx_RR {
	if ($HDLC_Verbose) {print color('green'), "HDLC_Tx_RR.\n", color('reset');}
	my $Data = chr(253) . chr(0x01);
	HDLC_Tx ($Data);
}

sub Page_Tx {
	my ($DestinationRadioID, $SourceRadioID, $Individual, $Emergency) = @_;
	my $Address = 0x07;
	my $Ind_Group_Page = $C_Group_Page;
	if ($Individual) {
		$Ind_Group_Page = $C_Individual_Page;	
	}
	my $RTRT;
	if ($HDLC_RTRT_Enabled == 1) {
		$RTRT = $C_RTRT_Enabled;
	} else {
		$RTRT = $C_RTRT_Disabled;
	}
	my $DestMMSB = (($DestinationRadioID & 0xFF0000) >> 16);
	my $DestMSB = (($DestinationRadioID & 0xFF00) >> 8);
	my $DestLSB = ($DestinationRadioID & 0xFF);
	my $SrcMMSB = (($SourceRadioID & 0xFF0000) >> 16);
	my $SrcMSB = (($SourceRadioID & 0xFF00) >> 8);
	my $SrcLSB = ($SourceRadioID & 0xFF);

	if ($Emergency) {
		if ($Verbose) {print color('red'), "Emergency_Tx.\n", color('reset');}
		# Emergency packet from radio 1 to TG 65535:
		# 07 03 a1 02 02 0c 0f 00 00 00 00 a7 00 00 00 00 ff ff 00 00 01 3f 11 00 01 48 02
		my $Data = chr($Address) . chr($C_UI) . chr($C_RN_Page) . chr(0x02) . chr($RTRT) .
			chr(0x0C) . chr(0x0F) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr($C_Emergency_Page) . chr($Ind_Group_Page) . chr(0x00) . chr(0x00) .
			chr($DestMMSB) . chr($DestMSB) . chr($DestLSB) . chr($SrcMMSB) . chr($SrcMSB) .
			chr($SrcLSB) . chr(0x3F) . chr(0x11) . chr(0x00) . chr(0x01) .
			chr(0x48) . chr(0x02);
		if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Data);}
		HDLC_Tx ($Data);
		HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr($C_EndTx) . chr($C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00));
		HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr($C_EndTx) . chr($C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00));
		# TG Disabled
		$DestMMSB = 0x00;
		$DestMSB = 0x00;
		$DestLSB = 0x01;
		# Emergency packet No TG from radio 1 to TG 8650753 (yes, weird TG):	
		# 07 03 a1 02 02 0c 0f 00 00 00 00 a7 00 00 00 00 00 01 00 00 01 58 A9 00 01 47 02
		$Data = chr($Address) . chr($C_UI) . chr($C_RN_Page) . chr(0x02) . chr($RTRT) .
			chr(0x0C) . chr(0x0F) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr($C_Emergency_Page) . chr($Ind_Group_Page) . chr(0x00) . chr(0x00) .
			chr($DestMMSB) . chr($DestMSB) . chr($DestLSB) . chr($SrcMMSB) . chr($SrcMSB) .
			chr($SrcLSB) . chr(0x58) . chr(0xA9) . chr(0x00) . chr(0x01) .
			chr(0x47) . chr(0x02);
		HDLC_Tx ($Data);
		HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr($C_EndTx) . chr($C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00));
		HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr($C_EndTx) . chr($C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00));
	}
}


sub Page_Ack_Tx {
	my ($DestinationRadioID, $SourceRadioID, $Individual) = @_;


}

sub TMS_Tx {
	my ($DestinationRadioID, $Message) = @_;


}

sub Bytes_2_HexString {
	my ($Buffer) = @_;
	# Display Rx Hex String.
	#print "HDLC_Rx Buffer:              ";
	for (my $x = 0; $x < length($Buffer); $x++) {
		print sprintf(" %x", ord(substr($Buffer, $x, 1)));
	}
	print "AAA\n";
}

sub CRC_CCITT_Gen {
	my ($Buffer) = @_;
	my $ctx = Digest::CRC->new(type=>"crcccitt");
	$ctx = Digest::CRC->new(width=>16, init=>0xFFFF, xorout=>0xFFFF,
	refout=>1, poly=>0x1021, refin=>1, cont=>0);
	$ctx->add($Buffer);
	my $digest = $ctx->digest;
	my $MSB = int($digest / 256);
	my $LSB = $digest - $MSB * 256;
	$digest = 256 * $LSB + $MSB;
	return $digest;
}

sub ManufacturerName {
	my ($ManID) = @_;
	my $ManufacturerName = "Not Registered";
	switch ($ManID) {
		case 0x00 {
			$ManufacturerName = "Default Value";
		}
		case 0x01 {
			$ManufacturerName = "Another Default Value";
		}
		case 0x09 {
			$ManufacturerName = "Aselan Inc";
		}
		case 0x10 {
			$ManufacturerName = "Relm/BK Radio";
		}
		case 0x18 {
			$ManufacturerName = "Airbus";
		}
		case 0x20 {
			$ManufacturerName = "Cyccomm";
		}
		case 0x28 {
			$ManufacturerName = "Efratom";
		}
		case 0x30 {
			$ManufacturerName = "Com-Net Ericsson";
		}
		case 0x34 {
			$ManufacturerName = "Etherstack";
		}
		case 0x38 {
			$ManufacturerName = "Datron";
		}
		case 0x40 {
			$ManufacturerName = "Icom";
		}
		case 0x48 {
			$ManufacturerName = "Garmin";
		}
		case 0x50 {
			$ManufacturerName = "GTE";
		}
		case 0x55 {
			$ManufacturerName = "IFR Systems";
		}
		case 0x5A {
			$ManufacturerName = "INIT Innovations";
		}
		case 0x60 {
			$ManufacturerName = "GEC-Marconi";
		}
		case 0x64 {
			$ManufacturerName = "Harris Corp (inactive)";
		}
		case 0x68 {
			$ManufacturerName = "Kenwood";
		}
		case 0x70 {
			$ManufacturerName = "Glenayre Electronics";
		}
		case 0x74 {
			$ManufacturerName = "Japan Radio Co.";
		}
		case 0x78 {
			$ManufacturerName = "Kokusai";
		}
		case 0x7C {
			$ManufacturerName = "Maxon";
		}
		case 0x80 {
			$ManufacturerName = "Midland";
		}
		case 0x86 {
			$ManufacturerName = "Daniels Electronics";
		}
		case 0x90 {
			$ManufacturerName = "Motorola";
		}
		case 0xA0 {
			$ManufacturerName = "Thales";
		}
		case 0xA4 {
			$ManufacturerName = "Harris Corporation";
		}
		case 0xAA {
			$ManufacturerName = "NRPC";
		}
		case 0xB0 {
			$ManufacturerName = "Raytheon";
		}
		case 0xC0 {
			$ManufacturerName = "SEA";
		}
		case 0xC8 {
			$ManufacturerName = "Securicor";
		}
		case 0xD0 {
			$ManufacturerName = "ADI";
		}
		case 0xD8 {
			$ManufacturerName = "Tait Electronics";
		}
		case 0xE0 {
			$ManufacturerName = "Teletec";
		}
		case 0xF0 {
			$ManufacturerName = "Transcrypt International";
		}
		case 0xF8 {
			$ManufacturerName = "Vertex Standard";
		}
		case 0xFC {
			$ManufacturerName = "Zetron Inc";
		}
	}
		if ($HDLC_Verbose) { print color('grey12'), "  Manufacturer Name = $ManufacturerName\n", color('reset'); }
}

sub AlgoName {
	my ($AlgoID) = @_;
	my $AlgoName = "Unknown Algo";
	switch ($AlgoID) {
		case 0x0 {
			$AlgoName = "Accordian 1.3";
		}
		case 0x1 {
			$AlgoName = "Baton (Auto/Even)";
		}
		case 0x2 {
			$AlgoName = "FireFly Type 1";
		}
		case 0x3 {
			$AlgoName = "MayFly Type 1";
		}
		case 0x4 {
			$AlgoName = "FASCINATOR/Saville";
		}
		case 0x41 {
			$AlgoName = "Baton (Auto/Odd)";
		}
		case 0x80 {
			$AlgoName = "Unencrypted";
		}
		case 0x81 {
			$AlgoName = "DES";
		}
		case 0x83 {
			$AlgoName = "Triple DES";
		}
		case 0x84 {
			$AlgoName = "AES 256";
		}
		case 0x85 {
			$AlgoName = "AES 128 GCM";
		}
		case 0x88 {
			$AlgoName = "AES CBC";
		}
		case 0x9F {
			$AlgoName = "DES-XL";
		}
		case 0xA0 {
			$AlgoName = "DVI-XL";
		}
		case 0xA1 {
			$AlgoName = "DVP-XL";
		}
		case 0xAA {
			$AlgoName = "ADP";
		}
	}
	if ($HDLC_Verbose) { print color('grey12'), "  Algo Name = $AlgoName\n", color('reset'); }
}



##################################################################
# Cisco STUN  ####################################################
##################################################################
sub STUN_Tx{
	my ($Buffer) = @_;
	my $STUN_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(length($Buffer)) . chr($STUN_ID); # STUN Header.
	my $Data = $STUN_Header . $Buffer;
	if ($STUN_Connected) {
		#$STUN_Sel->can_write(0.0001);
		$STUN_ClientSocket->send($Data);
		if ($STUN_Verbose) { print color('green'), "STUN_Tx sent:\n", color('reset');}
		if ($STUN_Verbose >= 2) { Bytes_2_HexString($Data);}
	}
}



##################################################################
# MMDVM ##########################################################
##################################################################
sub WritePoll {
	my ($TalkGroup) = @_;
	my $Filler = chr(0x20);
	my $Data = chr(0xF0) . $Callsign;
	for (my $x = length($Data); $x < 11; $x++) {
		$Data .= $Filler;
	}

	$TG{$TalkGroup}{'Sock'}->send($Data);
	if ($MMDVM_Verbose) {
		print "WritePoll IP $TalkGroup IP $TG{$TalkGroup}{'MMDVM_URL'}" .
			" Port $TG{$TalkGroup}{'MMDVM_Port'}\n";
	}
	$TG{$TalkGroup}{'MMDVM_Connected'} = 1;
}

sub WriteUnlink {
	my ($TalkGroup) = @_;
	my $Filler = chr(0x20);
	my $Data = chr(0xF1) . $Callsign;
	for (my $x = length($Data); $x < 11; $x++) {
		$Data .= $Filler;
	}
	$TG{$TalkGroup}{'Sock'}->send($Data);
	if ($MMDVM_Verbose) {
		print "WriteUnlink TG $TalkGroup IP $TG{$TalkGroup}{'MMDVM_URL'}" .
			" Port $TG{$TalkGroup}{'MMDVM_Port'}\n";
	}
	$TG{$TalkGroup}{'MMDVM_Connected'} = 0;
	$TG{$TalkGroup}{'Sock'}->close();
}

sub MMDVM_Rx { # Only HDLC UI Frame. Start on Quantar v.24 Byte 3.
	my ($TalkGroup, $Buffer) = @_;
	my $HexData = "";
	#if ($MMDVM_Verbose) {print "MMDVM_Rx Len(Buffer) = " . length($Buffer) . "\n";}
	if (length($Buffer) < 1) {return;}
	my $OpCode = ord(substr($Buffer, 0, 1));
	if ($MMDVM_Verbose) {print "  MMDVM_Rx OpCode = " . sprintf("0x%X", $OpCode) . "\n";}
	switch ($OpCode) {
		case [0x60..0x61] { # Headers data.


#			if (($PauseScan == 0) and ($TG{$TalkGroup}{'Scan'} > $Scan)) {
#				$OutBuffer = $Buffer;
#				$Scan = $TG{$key}{'Scan'};
#			}
#			if ($TalkGroup == $LinkedTalkGroup) {
#				$OutBuffer = $Buffer;
#				last;
#			}




			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case [0x62..0x73] { # Audio data.
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case 0x80 { # End Tx.
			if ($MMDVM_Verbose) {print "  End Tx, TG $TalkGroup.\n";}
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case [0xA1] { # Page data.
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case 0xF0 { # Ref. Poll Ack.
			if ($MMDVM_Verbose) {print "  Poll Reflector Ack, TG $TalkGroup.\n";}
			#$MMDVM_Connected = 1;
		}	
		case 0xF1 { # Ref. Disconnect Ack.
			if ($MMDVM_Verbose) {print "  Ref. Disconnect Ack Rx, TG $TalkGroup.\n";}
			$TG{$TalkGroup}{'MMDVM_Connected'} = 0;
			$TG{$TalkGroup}{'Sock'}->close();
			#$MMDVM_Listen_Enable = 0;
		}
		case 0xF2 { # Start of Tx.
			if ($MMDVM_Verbose) {print "  0xF2, TG $TalkGroup.\n";}
		} else {
			print "  else " . hex(ord(substr($Buffer, 0, 1))) ." else Len = " . length($Buffer) . "\n";
		}
	}
}

sub MMDVM_Tx{
	my ($TalkGroup, $Buffer) = @_;
	if ($TG{$TalkGroup}{'MMDVM_Connected'}) {
		$TG{$TalkGroup}{'Sock'}->send($Buffer);
	}
}



##################################################################
# P25Link ########################################################
##################################################################
sub P25Link_Disconnect {
	my ($TalkGroup) = @_;
	my $MulticastAddress = P25Link_MakeMulticastAddress($TalkGroup);
	$TG{$TalkGroup}{'Sock'}->mcast_drop($MulticastAddress);
#	$TG{$TalkGroup}{'Sel'}->remove($TG{$TalkGroup}{'Sock'});
	$TG{$TalkGroup}{'P25Link_Connected'} = 0;
	$TG{$TalkGroup}{'Sock'}->close();
	print color('green'), "P25Link TG $TalkGroup disconnected.\n", color('reset');
}

sub P25Link_MakeMulticastAddress{
	my ($TalkGroup) = @_;
	my $b = 2;
	my $c = ($TalkGroup & 0xFF00) >> 8;
	my $d = $TalkGroup & 0x00FF;
	my $ThisAddress = "239.$b.$c.$d";
	#if ($P25Link_Verbose) {
		#print "TalkGroup $TalkGroup\tc $c\td $d\n";
		#print "P25Link_MulticastAddress = $ThisAddress\n";
	#}
	return $ThisAddress;
}

sub P25Link_Rx{
	my ($Buffer) = @_;
	if (length($Buffer) < 1) {return;}
	#if ($Verbose) {print "PN25Link_Rx\n";} if ($Verbose) {
		#print "PN25Lnk_Rx HexData = " . StrToHex($Buffer) . "\n";
	#}
	#MMDVM_Tx(substr($Buffer, 9, length($Buffer)));
	P25Link_to_HDLC($Buffer);
}

sub P25Link_Tx{ # This function expect to Rx a formed Cisco STUN Packet.
	my ($Buffer) = @_;
	if ($TG{$LinkedTalkGroup}{'P25Link_Connected'} != 1) {
		return;
	}
	# Tx to the Network.
	if ($P25Link_Verbose >= 2) {
		print "P25Link_Tx Message.\n";
		StrToHex($Buffer);
	}
	my $MulticastAddress = P25Link_MakeMulticastAddress($LinkedTalkGroup);
	my $Tx_Sock = IO::Socket::Multicast->new(
		LocalHost => $MulticastAddress,
		LocalPort => $P25Link_Port,
		Proto => 'udp',
		Blocking => 0,
		Broadcast => 1,
		ReuseAddr => 1,
		PeerPort => $P25Link_Port
		)
		or die "Can not create Multicast : $@\n";
	$Tx_Sock->mcast_ttl(10);
	$Tx_Sock->mcast_loopback(0);
	$Tx_Sock->mcast_send($Buffer, $MulticastAddress . ":" . $P25Link_Port);
	$Tx_Sock->close;
	if ($P25Link_Verbose) {
		print "P25Link_Tx TG $LinkedTalkGroup IP Mcast $MulticastAddress\n";
	}
}



##################################################################
# P25NX ##########################################################
##################################################################
sub P25NX_Disconnect{
	my ($TalkGroup) = @_;
	if ($TalkGroup > 10099 and $TalkGroup < 10600){
		my $MulticastAddress = P25NX_MakeMulticastAddress($TalkGroup);
		$TG{$TalkGroup}{'Sock'}->mcast_drop($MulticastAddress);
	}
	$TG{$TalkGroup}{'P25NX_Connected'} = 0;
	$TG{$TalkGroup}{'Sock'}->close();
	print color('green'), "P25NX TG $TalkGroup disconnected.\n", color('reset');
}

sub P25NX_MakeMulticastAddress{
	my ($TalkGroup) = @_;
	my $x = $TalkGroup - 10099;
	my $b = 0;
	my $c = 0;
	my $i;
	my $Region;
	my $ThisAddress;
	for ($i = 1; $i < 1000; $i++) {
		if ($x < 254) {
			$c = $x;
		} else {
			$x = $x - 254;
			$b = $b + 1;
		}
	}
	$Region = substr($TalkGroup, 2, 1);
	$ThisAddress = "239.$Region.$b.$c";
	#if ($Verbose) {print "P25NX_MakeMulticastAddress = $ThisAddress\n";}
	return $ThisAddress;
}

sub P25NX_Rx{
	my ($Buffer) = @_;
	if (length($Buffer) < 1) {return;}
	#if ($Verbose) {print "P25NX_Rx\n";} if ($Verbose) {
		#print "P25NX_Rx HexData = " . StrToHex($Buffer) . "\n";
	#}
	#MMDVM_Tx(substr($Buffer, 9, length($Buffer)));
	P25NX_to_HDLC($Buffer);

}

sub P25NX_Tx{ # This function expect to Rx a formed Cisco STUN Packet.
	my ($Buffer) = @_;
	if ($TG{$LinkedTalkGroup}{'P25NX_Connected'} != 1) {
		return;
	}
	if ($P25NX_Verbose) {print "P25NX Linked TG *** $LinkedTalkGroup \n";}
	# Tx to the Network.
	if ($P25NX_Verbose >= 2) {print "P25NX_Tx Message " . StrToHex($Buffer) . "\n";}
	my $MulticastAddress = P25NX_MakeMulticastAddress($LinkedTalkGroup);
	my $Tx_Sock = IO::Socket::Multicast->new(
		LocalHost => $MulticastAddress,
		LocalPort => $P25NX_Port,
		Proto => 'udp',
		Blocking => 0,
		Broadcast => 1,
		ReuseAddr => 1,
		PeerPort => $P25NX_Port
		)
		or die "Can not create Multicast : $@\n";
	$Tx_Sock->mcast_ttl(10);
	$Tx_Sock->mcast_loopback(0);
	$Tx_Sock->mcast_send($Buffer, $MulticastAddress . ":" . $P25NX_Port);
	$Tx_Sock->close;
	if ($P25NX_Verbose) {
		print "P25NX_Tx TG $LinkedTalkGroup IP Mcast $MulticastAddress\n";
	}
	if ($P25NX_Verbose) {print "P25NX_Tx Done.\n";}
}

sub StrToHex{
	my ($Data) = @_;
	my $x;
	my $HexData = "";
	for ($x = 0; $x < length($Data); $x++) {
		$HexData = $HexData . " " . sprintf("0x%X", ord(substr($Data, $x, 1)));
	}
	print $HexData . "\n";
}



##################################################################
# Traffic control ################################################
##################################################################
sub Tx_to_Network {
	my ($Buffer) = @_;
	if (($LinkedTalkGroup <= 10) or ($ValidNteworkTG == 0)) {
		return;
	}
#	if ($Verbose) {print color('grey12'), "Tx_to_Network $TG{$LinkedTalkGroup}{'Mode'}" . 
#		" TalkGroup $LinkedTalkGroup\n", color('reset'); }
	if ( $P25Link_Enabled and ($TG{$LinkedTalkGroup}{'Mode'} eq 'P25Link') and 
		($LinkedTalkGroup > 10) and ($LinkedTalkGroup < 65535) ) { # Case P25Link.
		HDLC_to_P25Link($Buffer);
		return;
	}
	if ( $P25NX_Enabled and ($TG{$LinkedTalkGroup}{'Mode'} eq 'P25NX') and
		($LinkedTalkGroup >= 10100) and ($LinkedTalkGroup < 10600) ) { # case P25NX.
		HDLC_to_P25NX($Buffer);
		return;
	}
	if ( $MMDVM_Enabled and ($TG{$LinkedTalkGroup}{'Mode'} eq 'MMDVM') and
		($LinkedTalkGroup > 10) and ($LinkedTalkGroup < 65535) ) { # Case MMDVM.
		HDLC_to_MMDVM($LinkedTalkGroup, $Buffer);
	}
}

sub HDLC_to_MMDVM {
	my ($TalkGroup, $Buffer) = @_;
	switch (ord(substr($Buffer, 2 , 1))) {
		case 0x00 {
			switch (ord(substr($Buffer, 5, 1))) {
				case 0x0C {
					if ($Verbose) {print color('yellow'), "HDLC_to_MMDVM A output:\n", color('reset');}
					MMDVM_Tx($TalkGroup, chr(0x72) . chr(0x7B) . 
						chr(0x3D) . chr(0x9E) . chr(0x44) . chr(0x00)
					);
				}
				case 0x25 {
					if ($Verbose) {print "HDLC_to_MMDVM ICW Terminate output:\n";}
					MMDVM_Tx($TalkGroup, chr(0x80) . chr(0x00). chr(0x00) .
						chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
						chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
						chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
						chr(0x00)
					);
				}
			}
		}
		case [0x60..0x61] {
			$Buffer = substr($Buffer, 2, length($Buffer)); # Here we remove first 2 Quantar Bytes.
			if ($Verbose) {print "HDLC_to_MMDVM Header output:\n";}
			if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Buffer);}
			MMDVM_Tx($TalkGroup, $Buffer);
		}
		case [0x62..0x73] {
			$Buffer = substr($Buffer, 2, length($Buffer)); # Here we remove first 2 Quantar Bytes.
			if ($Verbose) {print "HDLC_to_MMDVM Voice output:\n";}
			if ($HDLC_Verbose >= 2) {Bytes_2_HexString($Buffer);}
			MMDVM_Tx($TalkGroup, $Buffer);
		}
		else {
			warn "HDLC_to_MMDVM Error code " . (ord(substr($Buffer, 2, 1))) . "\n";
			Bytes_2_HexString($Buffer);
			return;
		}
	}
}

sub HDLC_to_P25Link {
	my ($Buffer) = @_;
	my $Stun_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(2 + length($Buffer)) . chr($STUN_ID); #STUN Header.
	$Buffer = $Stun_Header . $Buffer;
	#print "HDLC_to_P25Link.\n";
	P25Link_Tx($Buffer);
}

sub HDLC_to_P25NX {
	my ($Buffer) = @_;
	my $Stun_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(2 + length($Buffer)) . chr($STUN_ID); #STUN Header.
	$Buffer = $Stun_Header . $Buffer;
	#print "HDLC_to_P25NX.\n";
	P25NX_Tx($Buffer);
}

sub MMDVM_to_HDLC {
	my ($Buffer) = @_;
	if ( ($HDLC_Handshake == 0) or (length($Buffer) < 1) ) { return; }
		if ($LocalActive == 1) {
			return;
		}
	if ($MMDVM_Verbose >= 2) {
		print "MMDVM_to_HDLC In.\n";
		Bytes_2_HexString($Buffer);
	}
	my $Address = 0xFD; #0x07 or 0xFD
	$Tx_Started = 1;
	my $OpCode = ord(substr($Buffer, 0, 1));
	switch ($OpCode) {
		case [0x60..0x61] { # Use to bridge MMDVM to HDLC.
			$Buffer = chr($Address) . chr($C_UI) . $Buffer;
			if ($MMDVM_Verbose == 2) {
				print "MMDVM_to_HDLC Header Out:\n";
				Bytes_2_HexString($Buffer);
			}
			$HDLC_TxTraffic = 1;
			HDLC_Tx($Buffer);
		}
		case [0x62..0x73] { # Use to bridge MMDVM to HDLC.
			$Buffer = chr($Address) . chr($C_UI) . $Buffer;
			if ($MMDVM_Verbose == 2) {
				print "MMDVM_to_HDLC Voice Out:\n";
				Bytes_2_HexString($Buffer);
			}
			$HDLC_TxTraffic = 1;
			HDLC_Tx($Buffer);
		}
		case 0x80 {
			$Tx_Started = 0;
			my $RTRT;
			if ($HDLC_RTRT_Enabled == 1) {
				$RTRT = $C_RTRT_Enabled;
			} else {
				$RTRT = $C_RTRT_Disabled;
			}
			HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
				chr($C_EndTx) . chr($C_DVoice) . chr(0x00) . chr(0x00) . chr(0x00) .
				chr(0x00) . chr(0x00));
			HDLC_Tx(chr($Address) . chr($C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
				chr($C_EndTx) . chr($C_DVoice) . chr(0x00) . chr(0x00) . chr(0x00) .
				chr(0x00) . chr(0x00));
			print color('green'), "Network Tail_MMDVM_to_HDLC\n", color('reset');
			if ($UseRemoteCourtesyTone) {
				$Pending_CourtesyTone = 2;
			}
			$HDLC_TxTraffic = 0;
		}
	}
}

sub P25Link_to_HDLC { # P25Link packet contains Cisco STUN and Quantar packet.
	my ($Buffer) = @_;
	if ($LocalActive == 1) {
		return;
	}
	$Buffer = substr($Buffer, 7, length($Buffer)); # Here we remove Cisco STUN.
	$HDLC_TxTraffic = 1;
	HDLC_Tx($Buffer);
	if (ord(substr($Buffer, 2, 1)) eq 0x00 and
		ord(substr($Buffer, 3, 1)) eq 0x02 and
		ord(substr($Buffer, 5, 1)) eq $C_EndTx and
		ord(substr($Buffer, 6, 1)) eq $C_DVoice
	) {
		if ($Quant{'PrevFrame'} ne $Buffer) {
			print color('green'), "Network Tail_P25Link\n", color('reset');
			if ($UseRemoteCourtesyTone) {
				$Pending_CourtesyTone = 2;
			}	
		}
	}
	$Quant{'PrevFrame'} = $Buffer;
# Add a 1s timer to $HDLC_TxTraffic = 0;
}

sub P25NX_to_HDLC { # P25NX packet contains Cisco STUN and Quantar packet.
	my ($Buffer) = @_;
	if ($LocalActive == 1) {
		return;
	}
	$Buffer = substr($Buffer, 7, length($Buffer)); # Here we remove Cisco STUN.
	$HDLC_TxTraffic = 1;
	HDLC_Tx($Buffer);
	if (ord(substr($Buffer, 2, 1)) eq 0x00 and
		ord(substr($Buffer, 3, 1)) eq 0x02 and
		ord(substr($Buffer, 5, 1)) eq $C_EndTx and
		ord(substr($Buffer, 6, 1)) eq $C_DVoice
	) {
		if ($Quant{'PrevFrame'} ne $Buffer) {
			print color('green'), "Network Tail_P25NX\n", color('reset');
			if ($UseRemoteCourtesyTone) {
				$Pending_CourtesyTone = 2;
			}
		}
	}
	$Quant{'PrevFrame'} = $Buffer;
# Add a 1s timer to $HDLC_TxTraffic = 0;
}



##################################################################
sub AddLinkTG {
	my ($TalkGroup, $DoPauseScan) = @_;
	if ($DoPauseScan == 1) {
		PauseTGScan();
	}
	# Local TGs. Keep them Local.
	if (($TalkGroup > 0) and ($TalkGroup <= 10)) {
		if ($TalkGroup != $LinkedTalkGroup) {
			RDAC_Tx($LinkedTalkGroup);
			$VA_Message = $TalkGroup; # Select VA.
			$Pending_VA = 1;
		}
		$LinkedTalkGroup = $TalkGroup;
		$ValidNteworkTG = 0;
		print color('blue'), "Local Talk Group $TalkGroup.\n", color('reset');
		return;
	}
	# Undefined TG > 10, keep it local only.
	if ($TG{$TalkGroup}{'Linked'} eq '') {
			$TG{$TalkGroup}{'Linked'} = '';
			$ValidNteworkTG = 0;
			print color('yellow'), "Undefined TG $TalkGroup.\n", color('reset');
			return;
	}
	# Defined TG, and linked.
	if ($TG{$TalkGroup}{'Linked'} == 1) {
		if ($TalkGroup != $LinkedTalkGroup) {
			$VA_Message = $TalkGroup; # Select VA.
			$Pending_VA = 1;
		}
		$LinkedTalkGroup = $TalkGroup;
		$ValidNteworkTG = 1;
		if ($TG{$TalkGroup}{'Scan'} == 0) {
			$TG{$TalkGroup}{'Timer'} = time();
		}
		print color('blue'), "  System already linked to TG $TalkGroup.\n", color('reset');
		return;
	}

	# Defined TG but not linked, create a link by connecting to the network.
	if ($P25Link_Enabled and ($TG{$TalkGroup}{'Mode'} eq 'P25Link')) { # Case P25Link.
		my $MulticastAddress = P25Link_MakeMulticastAddress($TalkGroup);
		if ($Verbose) {print color('magenta'), "  P25Link connecting to $TalkGroup" .
			" Multicast Addr. $MulticastAddress on Port $P25Link_Port\n", color('reset');
		}
		$TG{$TalkGroup}{'Sock'} = IO::Socket::Multicast->new(
			LocalHost => $MulticastAddress,
			LocalPort => $P25Link_Port,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 1,
			ReuseAddr => 1,
			PeerPort => $P25Link_Port
			)
			or die "Can not create Multicast : $@\n";
		$TG{$TalkGroup}{'Sel'} = IO::Select->new($TG{$TalkGroup}{'Sock'});
		$TG{$TalkGroup}{'Sock'}->mcast_add($MulticastAddress);
		$TG{$TalkGroup}{'Sock'}->mcast_ttl(10);
		$TG{$TalkGroup}{'Sock'}->mcast_loopback(0);
		$TG{$TalkGroup}{'P25Link_Connected'} = 1;
print "P25Link AddLink $TalkGroup\n";
	}

	if ( $P25NX_Enabled and ($TalkGroup >= 10100) and ($TalkGroup < 10600)
		and ($TG{$TalkGroup}{'Mode'} eq 'P25NX')) { # case P25NX.
		my $MulticastAddress = P25NX_MakeMulticastAddress($TalkGroup);
		if ($Verbose) {print color('magenta'), "  P25NX connecting to $TalkGroup" .
			" Multicast Addr. $MulticastAddress on Port $P25NX_Port\n", color('reset');
		}
		$TG{$TalkGroup}{'Sock'} = IO::Socket::Multicast->new(
			LocalHost => $MulticastAddress,
			LocalPort => $P25NX_Port,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 1,
			ReuseAddr => 1,
			PeerPort => $P25NX_Port
			)
			or die "Can not create Multicast : $@\n";
		$TG{$TalkGroup}{'Sel'} = IO::Select->new($TG{$TalkGroup}{'Sock'});
		$TG{$TalkGroup}{'Sock'}->mcast_add($MulticastAddress);
		$TG{$TalkGroup}{'Sock'}->mcast_ttl(10);
		$TG{$TalkGroup}{'Sock'}->mcast_loopback(0);
		$TG{$TalkGroup}{'P25NX_Connected'} = 1;
	}

	# Disconnect previous Reflector
	if ($MMDVM_TG != 0 ) {
		RemoveLinkTG ($MMDVM_TG);
	}
	if ( $MMDVM_Enabled and ($TG{$TalkGroup}{'Mode'} eq 'MMDVM') ) { # Case MMDVM.
		# Search if reflector exist
		if (exists($TG{$TalkGroup}{'MMDVM_URL'}) != 1) {
			if ($Verbose) {warn color('red'), "This is a local only TG and program shold not reach here.\n",
			 color('reset');}
			return;
		}
		# Connect to TG.
		if ($Verbose) {print color('magenta'), "  MMDVM connecting to TG $TalkGroup" .
			" IP $TG{$TalkGroup}{'MMDVM_URL'} on Port $TG{$TalkGroup}{'MMDVM_Port'}\n", color('reset');
		}
		$TG{$TalkGroup}{'Sock'} = IO::Socket::INET->new(
			LocalPort => $MMDVM_LocalPort,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 0,
			ReuseAddr => 1,
			PeerHost => $TG{$TalkGroup}{'MMDVM_URL'},
			PeerPort => $TG{$TalkGroup}{'MMDVM_Port'}
		) || MMDVM_Sock_Error($TalkGroup);

		# Test Socket
		if ($TG{$TalkGroup}{'Linked'} == -1) {
			$LinkedTalkGroup = $TalkGroup;
			$ValidNteworkTG = 0;
			return;
		}

		$TG{$TalkGroup}{'Sel'} = IO::Select->new($TG{$TalkGroup}{'Sock'});
		$MMDVM_TG = $TalkGroup;
		WritePoll($TalkGroup);
		WritePoll($TalkGroup);
		WritePoll($TalkGroup);
	}

	# Finalize linking new TG.
	$TG{$TalkGroup}{'Linked'} = 1;
	$LinkedTalkGroup = $TalkGroup;
	$ValidNteworkTG = 1;
	if ($TG{$TalkGroup}{'Scan'} == 0) {
		$TG{$TalkGroup}{'Timer'} = time();
	}
	$VA_Message = $TalkGroup; # Linked TalkGroup.
	$Pending_VA = 1;
	print color('green'), "  System Linked to TG $TalkGroup\n", color('reset');
}

sub MMDVM_Sock_Error {
	my ($TalkGroup) = @_;
	warn color('yellow'), "Can not Bind MMDVM : $@\n",  color('reset');
	$TG{$TalkGroup}{'Linked'} = -1;
}

##################################################################
sub RemoveLinkTG {
	my ($TalkGroup) = @_;
	print "RemoveLinkTG $TalkGroup\n";
	if ($TG{$TalkGroup}{'Linked'} == 0) {
		return;
	}
	print color('magenta'), "RemoveLinkTG $TalkGroup\n", color('reset');
	# Disconnect from current network.
	if ($TG{$TalkGroup}{'MMDVM_Connected'}) {
		WriteUnlink($MMDVM_TG); 
		$MMDVM_TG = 0;
	}
	if ($TG{$TalkGroup}{'MMDVM_Connected'}) { WriteUnlink($TalkGroup); }
	if ($TG{$TalkGroup}{'P25Link_Connected'}) { P25Link_Disconnect($TalkGroup); }
	if ($TG{$TalkGroup}{'P25NX_Connected'}) { P25NX_Disconnect($TalkGroup); }
	$TG{$TalkGroup}{'Linked'} = 0;
	#print "  System Disconnected from TG $TalkGroup\n";
}

sub PauseTGScan {
	print color('yellow'), "PauseTGScan starting.\n", color('reset');
	$PauseScan = 1;
	$PauseTGScanTimer = time() + $MuteTGTimeout;
}

sub PauseTGScan_Timer {
	if (($PauseScan == 1) and ($PauseTGScanTimer <= time())) {
		print color('yellow'), "PauseTGScan_Timer expired.\n", color('reset');
		$PauseScan = 0;
		RDAC_Tx($LinkedTalkGroup);
		#$VA_Message = 0xFFFF13; # Default Revert.
		#$Pending_VA = 1;
	}
}

sub RemoveDynamicTGLink {
	foreach my $key (keys %TG) {
		if ( ($TG{$key}{'P25Link_Connected'} or $TG{$key}{'P25NX_Connected'} or 
			$TG{$key}{'MMDVM_Connected'} ) and ($TG{$key}{'Scan'} == 0) ) {
			if (time() > ($TG{$key}{'Timer'} + $Hangtime)) {
				print color('yellow'), "RemoveDinamicTGLink $key.\n", color('reset');
				RemoveLinkTG($key);
				RDAC_Tx($PriorityTG);
				$VA_Message = 0xFFFF13; # Default Revert.
				$Pending_VA = 1;
			}
		}
	}
}

sub TxLossTimeout_Timer { # End of Tx timmer (1 sec).
	if (($Quant{'LocalRx'} > 0) and (int($Quant{'LocalRx_Time'} + 2000) <= getTickCount() )) {
		print color('green'), "Timer 1 event $Quant{'LocalRx'}\n", color('reset');
		#if (int($Quant{'LocalRx_Time'} + 1000) <= $TickCount) {
		#	print "bla\n" ;
		#}
		$Quant{'LocalRx'} = 0;
		$Pending_CourtesyTone = 1; # Let the system know we wish a courtesy tone when possible.
	}
}



#################################################################################
# Voice Announce ################################################################
#################################################################################
sub SaySomething {
	my ($ThingToSay) = @_;
	my @Speech;
	if ($Verbose) {print color('green'), "Voice Announcement: ", color('reset');}
	$HDLC_TxTraffic = 1;
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
		$Message = HexString_2_Bytes($Speech[$x]);
		HDLC_Tx($Message);
		my $SerialWait = (8.0 / 9600.0) * 1.0; # 1 Byte length delay for VA.
		nanosleep($SerialWait * 1000000000);
	}
	nanosleep(0.0001 * 1000000000); # Needed for playing complete voice announcements.
	$HDLC_TxTraffic = 0;
	if ($Verbose) {print " done.\n";}
}

sub HexString_2_Bytes{
	my ($Buffer) = @_;
	my $Data = "";
	for (my $x = 0; $x < length($Buffer); $x = $x + 6) {
		#print "Dat = " . substr($Buffer, $x, 4) . "\n";
		#print "Dat2 = " . sprintf("%d", hex(substr($Buffer, $x, 4))) . "\n";
		$Data .= chr(sprintf("%d", hex(substr($Buffer, $x, 4))));
	}
	#print "Data Length =" . length($Data) . "\n";
	#Bytes_2_HexString($Data);
	return $Data;
}



#################################################################################
# Misc Subs #####################################################################
#################################################################################
sub getTickCount {
	my ($epochSecs, $epochUSecs) = Time::HiRes::gettimeofday();
	#print $Epock secs $epochSecs Epoch usec $epochUSecs.\n";
	my $TickCount = ($epochSecs * 1000 + int($epochUSecs / 1000));
	return $TickCount;
}


sub Pin5_Interrupt_Handler {
	print color('yellow'), "Pin5 Interrupt Handler.\n", color('reset');
}

sub HotKeys {
	# Hot Keys.
	if ($HotKeys) {
		if (not defined (my $key = ReadKey(-1))) {
			# No key yet.
		} else {
			switch (ord($key)) {
				case 0x1B { # Escape
					print "EscKey Pressed.\n";
					$Run = 0;
				}

				case ord('A') { # 'A'
					APRS_Update();
					$APRS_NextTimer = time() + $APRS_Interval;
					$APRS_Verbose = 1;
				}
				case ord('a') { # 'a'
					$APRS_Verbose = 0;
				}
				case ord('C') { # 'C'
					$VA_Test = 0xFFFF11;
					$VA_Message = $VA_Test;
					$Pending_VA = 1;
				}
				case ord('c') { # 'c'
					$VA_Test = $VA_Test + 1;
					$VA_Message = $VA_Test;
					$Pending_VA = 1;
				}
				case ord('E') {
					# Emergency packet from radio 1 to TG 65535:
					Page_Tx(1, 1, 1, 1);
				}
				case ord('e') {
					# Play Alarm
					$VA_Message = 0xFFFF00;
					$Pending_VA = 1;
				}
				case ord('f') {
					SearchUser(0, 3341010);
#					SearchRepeater(0, 334004);
				}
				case ord('H') { # 'H'
					$HDLC_Verbose = 1;
				}
				case ord('h') { # 'h'
					PrintMenu();
					$HDLC_Verbose = 0;
				}
				case ord('L') { # 'L'
					$P25Link_Verbose = 1;
				}
				case ord('l') { # 'l'
					$P25Link_Verbose = 0;
				}
				case ord('M') { # 'M'
					$MMDVM_Verbose = 1;
				}
				case ord('m') { # 'm'
					$MMDVM_Verbose = 0;
				}
				case ord('P') { # 'P'
					$P25NX_Verbose = 1;
				}
				case ord('p') { # 'p'
					$P25NX_Verbose = 0;
				}
				case ord('Q') { # 'Q'
					$Run = 0;
				}
				case ord('q') { # 'q'
					$Run = 0;
				}
				case ord('S') { # 'S'
					$STUN_Verbose = 1;
				}
				case ord('s') { # 's'
					$STUN_Verbose = 0;
				}
				case ord('t') { # 't'
					P25Link_MakeMulticastAddress($TGVar);
					$TGVar++;
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
	if ($HDLC_Handshake and ($Quant{'LocalRx'} == 0) and $Pending_VA) {
		if ($VA_Message <= 0xFFFF) { APRS_Update_TG($VA_Message); }
		if ($VA_Message == 0xFFFF13) { APRS_Update_TG($PriorityTG); }
		if ($UseVoicePrompts == 1) {
			SaySomething($VA_Message);
		}
		$Pending_VA = 0;
	}

	# Courtesy tone.
	if ($HDLC_Handshake and ($Quant{'LocalRx'} == 0) and ($Pending_CourtesyTone > 0)) {
		if ($UseLocalCourtesyTone > 0 and $Pending_CourtesyTone >= 1) {
			#if ($Verbose) {print "Courtesy tone expected $Pending_CourtesyTone\n";}
			if ($Pending_CourtesyTone == 1){
				SaySomething(0xFFFF00 | $UseLocalCourtesyTone);
			}
			if ($Pending_CourtesyTone == 2){
				SaySomething(0xFFFF00 | $UseRemoteCourtesyTone);
			}
			$Pending_CourtesyTone = 0;
		}
	}
}



#################################################################################
# Main Loop #####################################################################
#################################################################################
sub MainLoop {
	while ($Run) {
		my $Scan = 0;
		(my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst) = localtime();

		RR_Timer();
		Read_Serial(); # Serial Port Receiver when Mode == 0.

		# Cisco STUN TCP Receiver.
		if (($Mode == 1) and ($STUN_Connected == 1)) {
			for $STUN_fh ($STUN_Sel->can_read($Read_Timeout)) {
				my $RemoteHost = $STUN_fh->recv(my $Buffer, $MaxLen);
				if ($RemoteHost) {
					print "RemoteHost = $RemoteHost\n";
					die;
				}
				if (length($Buffer) > 7) {
					#my $RemoteHost = $STUN_ClientSocket->recv(my $Buffer, $MaxLen);
					if ($STUN_Verbose) {
						print "$hour:$min:$sec $RemoteHost STUN Rx Buffer len(" . length($Buffer) . ")\n";
						Bytes_2_HexString($Buffer);
					}
					HDLC_Rx(substr($Buffer, 7, length($Buffer)));
				}
			}
		}

		# MMDVM WritePoll beacon.
		my $MMDVM_Timeout = $MMDVM_Poll_NextTimer - time();
		#if ($Verbose) {print "Countdown to send WritePoll = $MMDVM_Timeout\n";}
		if ($MMDVM_Timeout <= 0) {
			#print "$hour:$min:$sec Sending WritePoll beacon.\n";
			#warn "MMDVM_Poll Timed out @{[int time - $^T]}\n";
			foreach my $key (keys %TG) {
				if ($TG{$key}{'MMDVM_Connected'}) {
					WritePoll($key);
				}
			}
			$MMDVM_Poll_NextTimer = $MMDVM_Poll_Timer_Interval + time();
		}
		# MMDVM Receiver.
		foreach my $key (keys %TG) {
			if ($TG{$key}{'MMDVM_Connected'}) {
				my $TalkGroup;
				my $OutBuffer;
				for my $MMDVM_fh ($TG{$key}{'Sel'}->can_read($Read_Timeout)) {
					$MMDVM_RemoteHost = $MMDVM_fh->recv(my $Buffer, $MaxLen);
					$MMDVM_RemoteHost = $MMDVM_fh->peerhost;
print "MMDVM Receiving $key\n";
					if ($MMDVM_Verbose) {print "MMDVM_RemoteHost = $MMDVM_RemoteHost\n";}
					if (($MMDVM_RemoteHost cmp $MMDVM_LocalHost) != 0) {
						#if ($Verbose) {print "$hour:$min:$sec $MMDVM_RemoteHost" .
						#	" MMDVM Data len(" . length($Buffer) . ")\n";
						#}
						my $OpCode = ord(substr($Buffer, 0, 1));
						if ($MMDVM_Verbose) {
							print "  MMDVM_Receiver OpCode = " . sprintf("0x%X", $OpCode) . "\n";
						}
						if ($OpCode == 0xF0) { # Ref. Poll Ack.
							MMDVM_Rx($key, $Buffer);
						} else {
							if (($PauseScan == 0) and ($TG{$key}{'Scan'} > $Scan)) {
								$TalkGroup = $key;
								$OutBuffer = $Buffer;
								$Scan = $TG{$key}{'Scan'};
							}
							if ($key == $LinkedTalkGroup) {
								$TalkGroup = $key;
								$OutBuffer = $Buffer;
							}
						}
					}
					if ($TalkGroup) {
						MMDVM_Rx($key, $OutBuffer);
					}
				}
			}
		}

		# P25Link Receiver
		foreach my $key (keys %TG) {
			if ($TG{$key}{'P25Link_Connected'}) {
				my $TalkGroup;
				my $OutBuffer;
				for my $P25Link_fh ($TG{$key}{'Sel'}->can_read($Read_Timeout)) {
					my $RemoteHost = $P25Link_fh->recv(my $Buffer, $MaxLen);
					$RemoteHost = $P25Link_fh->peerhost;
					#if ($Verbose) {print "P25Link_LocalHost = $PN25Link_LocalHost\n";}
					my $MulticastAddress = P25Link_MakeMulticastAddress($key);
					if (($RemoteHost cmp $MulticastAddress) != 0) {
						if ($P25Link_Verbose) {print "$hour:$min:$sec P25Link Receiving $key " .
							"from IP $RemoteHost Data len(" . length($Buffer) . ")\n";
						}
						if (($PauseScan == 0) and ($TG{$key}{'Scan'} > $Scan)) {
							$TalkGroup = $key;
							$OutBuffer = $Buffer;
							$Scan = $TG{$key}{'Scan'};
						}
						if ($key == $LinkedTalkGroup) {
							$TalkGroup = $key;
							$OutBuffer = $Buffer;
							last;
						}
					}
				}
				if ($TalkGroup) {
					P25Link_Rx($OutBuffer);
				}
			}
		}

		# P25NX Receiver
		foreach my $key (keys %TG) {
			if ($TG{$key}{'P25NX_Connected'}) {
				my $TalkGroup;
				my $OutBuffer;
				for my $P25NX_fh ($TG{$key}{'Sel'}->can_read($Read_Timeout)) {
					my $P25NX_RemoteHost = $P25NX_fh->recv(my $Buffer, $MaxLen);
					$P25NX_RemoteHost = $P25NX_fh->peerhost;
					#if ($P25NX_Verbose) {print "P25NX_LocalHost $P25NX_LocalHost\n";}
					my $MulticastAddress = P25NX_MakeMulticastAddress($key);
					if (($P25NX_RemoteHost cmp $MulticastAddress) != 0) {
						if ($P25NX_Verbose) {print "$hour:$min:$sec P25NX Receiving $key " .
							"from IP $P25NX_RemoteHost Data len(" . length($Buffer) . ")\n";
						}
						if (($PauseScan == 0) and ($TG{$key}{'Scan'} > $Scan)) {
							$TalkGroup = $key;
							$OutBuffer = $Buffer;
							$Scan = $TG{$key}{'Scan'};
						}
						if ($key == $LinkedTalkGroup) {
							$TalkGroup = $key;
							$OutBuffer = $Buffer;
							last;
						}
					}
				}
				if ($TalkGroup) {
					P25NX_Rx($OutBuffer);
				}
			}
		}

		PauseTGScan_Timer();
		TxLossTimeout_Timer(); # End of Tx timmer (1 sec).
		Announcements_Player();
		RemoveDynamicTGLink(); # Remove Dynamic Talk Group Link.
		APRS_Timer(); # APRS-IS Timer to send position/objects to APRS-IS.
		RDAC_Timer(); # RDAC Timer.
		HotKeys(); # Keystrokes events.
		if ($Verbose >= 5) { print "Looping the right way.\n"; }
		#my $NumberOfTalkGroups = scalar keys %TG;
		#print "Total number of links is: $NumberOfTalkGroups\n\n";
	}
}

