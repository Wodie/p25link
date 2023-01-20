package RDAC;
# RDAC.pm

use strict;
use warnings;
use Config::IniFiles;
use IO::Socket::IP;

use Term::ANSIColor;

# Local modules:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
use P25Link;



my $VersionInfo;
my $MinorVersionInfo;
my $RevisionInfo;
my %RDAC;
my $Verbose;
my $Tx_Sock;
my $LocalHost;
my $IPV6Addr;
my $PriorityTG; 
my $SiteName;
my $SiteInfo;
my $Callsign;
my $P25Link_Enabled;
my $APRS_Suffix;



# Init RDAC.
sub Init {
	my ($ConfigFile, $VersionInfoRef, $MinorVersionInfoRef, $RevisionInfoRef) = @_;
	print color('green'), "Init RDAC.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$VersionInfo = $VersionInfoRef;
	$MinorVersionInfo = $MinorVersionInfoRef;
	$RevisionInfo = $RevisionInfoRef;
	$RDAC{'Enabled'} = $cfg->val('RDAC', 'Enabled');
	$RDAC{'VPN_Enabled'} = $cfg->val('RDAC', 'VPN_Enabled');
	$RDAC{'ServerAddress'} = $cfg->val('RDAC', 'ServerAddress');
	$RDAC{'ServerPort'} = $cfg->val('RDAC', 'ServerPort');
	$RDAC{'Interval'} = $cfg->val('RDAC', 'Interval');
	$Verbose = $cfg->val('RDAC', 'Verbose');
	print "  Enabled = $RDAC{'Enabled'}\n";
	print "  VPN Enabled = $RDAC{'VPN_Enabled'}\n";
	print "  ServerAddress = $RDAC{'ServerAddress'}\n";
	print "  ServerPort = $RDAC{'ServerPort'}\n";
	print "  Interval = $RDAC{'Interval'}\n";
	print "  Verbose = $Verbose\n";
	use constant OpPollReply => 0x2100;
	$RDAC{'NextTimer'} = P25Link::GetTickCount(); # Make it run as soon as Mail Loop is running.
	$RDAC{'Port'} = 30002;
	$RDAC{'MulticastAddress'} = P25Link::MakeMulticastAddress(100);

	$LocalHost = $cfg->val('Settings', 'LocalHost');
		#my($LocalIPAddr) = inet_ntoa((gethostbyname(hostname))[4]);
		my($LocalHostIP) = inet_ntoa((gethostbyname($LocalHost))[4]);
	$IPV6Addr = $cfg->val('Settings', 'IPV6Addr');
	#	my($IPV6AddrIP) = inet_ntop((gethostbyname($IPV6Addr))[4]);
	$PriorityTG = $cfg->val('Settings', 'PriorityTG');
	$SiteName = $cfg->val('Settings', 'SiteName');
	$SiteInfo = $cfg->val('Settings', 'SiteInfo');
	$Callsign = $cfg->val('MMDVM', 'Callsign');
	$APRS_Suffix = $cfg->val('APRS', 'Suffix');

	$RDAC{'TalkGroup'} = $PriorityTG;

	if ($RDAC{'VPN_Enabled'}) {
		$RDAC{'Sock'} = IO::Socket::Multicast->new(
			LocalHost => $RDAC{'MulticastAddress'},
			LocalPort => $RDAC{'Port'},
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 1,
			ReuseAddr => 1,
			PeerPort => $RDAC{'Port'}
			)
			or die "Can not create Multicast : $@\n";
		$RDAC{'Sock'}->mcast_ttl(10);
		$RDAC{'Sock'}->mcast_loopback(0);
	} else {
		$RDAC{'Sock'} = IO::Socket::IP->new(
			LocalPort => $RDAC{'ServerPort'},
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 0,
			ReuseAddr => 1,
			PeerHost => $RDAC{'ServerAddress'},
			PeerPort => $RDAC{'ServerPort'}
		) || die "  Can not create RDAC UDP Sock $!\n";
	}
	print "----------------------------------------------------------------------\n";
}



##################################################################
# RDAC ###########################################################
##################################################################
sub Disconnect {
	my ($TalkGroup) = @_;
	$RDAC{'Sock'}->mcast_drop($RDAC{'MulticastAddress'});
	$RDAC{'Sel'}->remove($RDAC{'Sock'});
	$RDAC{'Sock'}{'Connected'} = 0;
	$RDAC{'Sock'}{'Sock'}->close();
	print color('green'), "RDAC::Disconnected.\n", color('reset');
}

sub Timer {
	if ($RDAC{'Enabled'} and P25Link::GetTickCount() >= $RDAC{'NextTimer'}) {
		Tx($RDAC{'TalkGroup'}, Quantar::GetLocalRx(), Quantar::GetLocalTx(), 
			Quantar::GetIsDigitalVoice(), Quantar::GetIsPage(), Quantar::GetStationType());
		$RDAC{'NextTimer'} = P25Link::GetTickCount() + $RDAC{'Interval'};
	}
}

sub Tx {
	my ($TalkGroup, $LocalRx, $LocalTx, $IsDigitalVoice, $IsPage, $StationType) = @_;
	if (!$RDAC{'Enabled'}) { return; }

	$RDAC{'TalkGroup'} = $TalkGroup;
	my $Buffer;
	$Buffer = 'P25Link' . chr(0x00);
	$Buffer .= chr(OpPollReply & 0xFF) . chr((OpPollReply & 0xFF00) >> 8);
	$Buffer .= inet_aton($LocalHost);
	$Buffer .= chr($RDAC{'Port'} & 0xFF) . chr(($RDAC{'Port'} & 0xFF00) >> 8);
	$Buffer .= chr($VersionInfo); # Software Mayor Version
	# 6
	$Buffer .= chr($MinorVersionInfo); # Software Minor Version
	$Buffer .= chr($RevisionInfo); # Software Revision Version
	# Flags
	my $Byte = 0;
	if ($LocalRx) {$Byte = 0x01;} # Receive
	if ($LocalRx) {$Byte = $Byte | 0x02;} # Transmit
	if ($IsDigitalVoice == 1) { # Mode Digital
		$Byte = $Byte | 0x04;
	}
	if ($IsDigitalVoice == 0) { # Mode Analog
		$Byte = $Byte | 0x08;
	}
	if ($IsPage == 1) { # Mode Data
		$Byte = $Byte | 0x10;
	}
	$Buffer = $Buffer . chr($Byte); # Flags
	# Callsign
	my $RDAC_Callsign = $Callsign . "/" . $APRS_Suffix;
	$Buffer .= $RDAC_Callsign;
	for (my $x = length($RDAC_Callsign); $x < 10; $x++) {
		$Buffer .= ' ';
	}
	# Site Name
	if (length($SiteName) > 30) {
		$SiteName = substr($SiteName, 0, 30);
	}
	$Buffer .= $SiteName;
	for (my $x = length($SiteName); $x < 30; $x++) {
		$Buffer .= ' ';
	}
	# Tak Group
	$Buffer .= chr($TalkGroup & 0xFF) . chr(($TalkGroup & 0xFF00) >> 8);
	# Info
	if (length($SiteInfo) > 30) {
		$SiteInfo = substr($SiteInfo, 0, 30);
	}
	$Buffer .= $SiteInfo;
	for (my $x = length($SiteInfo); $x < 30; $x++) {
		$Buffer .= ' ';
	}
	$Buffer .= chr($StationType); # Hardware
	#Spare 10
	$Buffer .= chr(0) . chr(0) . chr(0) . chr(0) . chr(0) .
		chr(0) . chr(0) . chr(0) . chr(0) . chr(0);
	#print " Len4 " . length($Buffer) . "\n";

	# Tx to the Network.
	if ($Verbose > 1) {
		print "RDAC_Tx Message.\n";
		StrToHex($Buffer);
	}
	if ($RDAC{'VPN_Enabled'}) {
		$RDAC{'Sock'}->mcast_send($Buffer, $RDAC{'MulticastAddress'} . ":" . $RDAC{'Port'});
		if ($Verbose) {
			print color('green'), "RDAC::Tx IP Mcast " . $RDAC{'MulticastAddress'} . "\n", color('reset');
		}
	} else {
		$RDAC{'Sock'}->send($Buffer);
		if ($Verbose) {
			print color('green'), "RDAC::Tx UDP IP " . $RDAC{'ServerAddress'} . "\n", color('reset');
		}
	}
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}




1;