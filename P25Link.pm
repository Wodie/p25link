package P25Link;
# P25Link.pm

use strict;
use warnings;
use Switch;
use Config::IniFiles;
use IO::Socket::IP;
use IO::Socket::Multicast;
#use IO::Socket::Multicast6;
use Term::ANSIColor;



# Local modules:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
use Quantar;



use constant MaxLen => 1024; # Max Socket Buffer length.
use constant Read_Timeout => 0.003;

use constant ServerPort => 30002;



my $cfg;

my $LocalHost;
my $IPV6Addr;
my $UseRemoteCourtesyTone;
my $Enabled;
my $ServerAddr;
my $Verbose;
my $Port = 30001;
my %P25Link;
my %IPv6;
my $FrameTx_NextTimer = 0;
my $FrameTx_TimerInterval = 0.1;
my $FrameTx_TimerEnabled = 0;
#my $Flags1 = 0x00;
#my $FrameToTx = 0;
#my $P25Link_Exp = 1;
my $Prev_OpCode = 0;
my $OldBuffer = 0;


#################################################################################
# P25Link #######################################################################
#################################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init P25Link.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$LocalHost = $cfg->val('Settings', 'LocalHost');
		#my($LocalIPAddr) = inet_ntoa((gethostbyname(hostname))[4]);
		my($LocalHostIP) = inet_ntoa((gethostbyname($LocalHost))[4]);
	$IPV6Addr = $cfg->val('Settings', 'IPV6Addr');
	#	my($IPV6AddrIP) = inet_ntop((gethostbyname($IPV6Addr))[4]);
	$UseRemoteCourtesyTone = $cfg->val('Settings', 'UseRemoteCourtesyTone');
	$Enabled = $cfg->val('P25Link', 'P25Link_Enabled');
	$ServerAddr = $cfg->val('P25Link', 'ServerAddr');
	$Verbose =$cfg->val('P25Link', 'Verbose');
	print "  Enabled = $Enabled\n";
	print "  ServerAddr = $ServerAddr\n";
	print "  Verbose = $Verbose\n";

	$IPv6{'Prev_UI'} = 0;
	$IPv6{'Connected'} = 0;
	print "----------------------------------------------------------------------\n";
}

sub JoinTG {
	my ($TalkGroup) = @_;
	# Defined TG but not linked, create a link by connecting to the network.
	if ($Enabled) { # Case P25Link.
		my $MulticastAddress = MakeMulticastAddress($TalkGroup);
		if ($Verbose) {print color('magenta'), "  Joining to $TalkGroup" .
			" Multicast Addr. $MulticastAddress:$Port\n", color('reset');
		}
		$P25Link{$TalkGroup}{'Sock'} = IO::Socket::Multicast->new(
			LocalHost => $MulticastAddress,
			LocalPort => $Port,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 1,
			ReuseAddr => 1,
			PeerPort => $Port
			)
			or die "Can not create Multicast : $@\n";
		$P25Link{$TalkGroup}{'Sel'} = IO::Select->new($P25Link{$TalkGroup}{'Sock'});
		$P25Link{$TalkGroup}{'Sock'}->mcast_add($MulticastAddress);
		$P25Link{$TalkGroup}{'Sock'}->mcast_ttl(10);
		$P25Link{$TalkGroup}{'Sock'}->mcast_loopback(0);
		$P25Link{$TalkGroup}{'Connected'} = 1;
		if ($Verbose) { print "  Joined $TalkGroup\n"; }
	}
}

sub Disconnect {
	my ($TalkGroup) = @_;
	my $MulticastAddress = MakeMulticastAddress($TalkGroup);
	$P25Link{$TalkGroup}{'Sock'}->mcast_drop($MulticastAddress);
	#$P25Link{$TalkGroup}{'Sel'}->remove($P25Link{$TalkGroup}{'Sock'});
	$P25Link{$TalkGroup}{'Connected'} = 0;
	$P25Link{$TalkGroup}{'Sock'}->close();
	if ($Verbose) { print color('green'), "P25Link TG $TalkGroup Disconnected.\n", color('reset'); }
}

sub MakeMulticastAddress {
	my ($TalkGroup) = @_;
	my $b = 2;
	my $c = ($TalkGroup & 0xFF00) >> 8;
	my $d = $TalkGroup & 0x00FF;
	my $ThisAddress = "239.$b.$c.$d";
	#if ($Verbose) {
	#	print "TalkGroup $TalkGroup\tc $c\td $d\n";
	#	print "  MulticastAddress = $ThisAddress\n";
	#}
	return $ThisAddress;
}

sub Rx {
	my ($Buffer) = @_;
	if (length($Buffer) < 1) {return;}
	if ($OldBuffer eq $Buffer) {
		return;
	}
	$OldBuffer = $Buffer;
	#if ($Verbose) {print "P25Link_Rx\n";} if ($Verbose) {
		#print "Rx HexData = " . StrToHex($Buffer) . "\n";
	#}
	#MMDVM_Tx(substr($Buffer, 9, length($Buffer)));

	if ($Packets::SuperFrame) {
		SuperFrame::To_HDLC($Buffer);
		return;
	}

	P25Link_to_HDLC($Buffer);

	my $OpCode = ord(substr($Buffer, 9, 1));
	if ($Verbose) {
		if ($Verbose) { print "  OpCode = " . sprintf("0x%02X", $OpCode) . "\n"; }
		if ($Prev_OpCode < 0x73 or $Prev_OpCode < 0x80) {
			if ($OpCode - 1 != $Prev_OpCode and $OpCode > 0x62) {
				if ($Verbose) {
					print color('yellow'), "P25Link_Rx UI " . sprintf("0x%02X", $Prev_OpCode) .
						" / " . sprintf("0x%02X", $OpCode) . " Voice Frame order jump.\n", color('reset');
				}
			}
		
		}
	}
	$Prev_OpCode = $OpCode;
}

sub Tx { # This function expect to Rx a formed Cisco STUN Packet.
	my ($LinkedTalkGroup, $Buffer) = @_;
	if ($P25Link{$LinkedTalkGroup}{'Connected'} != 1) {
		return;
	}
	# Tx to the Network.
	if ($Verbose >= 2) { print "P25NLink_Tx Message " . Bytes_2_HexString($Buffer) . "\n"; }
	my $MulticastAddress = MakeMulticastAddress($LinkedTalkGroup);

	for (my $x = 0; $x < length($x); $x++) {
		if (substr($Buffer, $x, 1) > 255) {
			die;
		}
	}
	$P25Link{$LinkedTalkGroup}{'Sock'}->mcast_ttl(10);
	$P25Link{$LinkedTalkGroup}{'Sock'}->mcast_loopback(0);
	$P25Link{$LinkedTalkGroup}{'Sock'}->mcast_send($Buffer, $MulticastAddress . ":" . $Port);

	if ($Verbose >= 2) {
		print "P25Link_Tx TG " . $LinkedTalkGroup . " IP Mcast $MulticastAddress:$Port\n";
	}
	if ($Verbose) {print "P25Link_Tx Done.\n";}
}



sub P25Link_to_HDLC { # P25Link packet contains Cisco STUN and Quantar packet.
	my ($Buffer) = @_;
	if (Packets::GetLocalActive() == 1) {
		return;
	}
	$Buffer = substr($Buffer, 7, length($Buffer)); # Here we remove Cisco STUN.
	Quantar::SetHDLC_TxTraffic(1);
	Quantar::HDLC_Tx($Buffer, 1);
	if (ord(substr($Buffer, 2, 1)) eq 0x00 and
		ord(substr($Buffer, 3, 1)) eq 0x02 and
		ord(substr($Buffer, 5, 1)) eq Quantar::C_EndTx and
		ord(substr($Buffer, 6, 1)) eq Quantar::C_DVoice
	) {
		if ($Verbose) { print color('green'), "Network Tail_P25Link\n", color('reset'); }
		if ($UseRemoteCourtesyTone) {
			$Packets::Pending_CourtesyTone = 2;
		}
	}
#Qunatar::SetPrevFrame($Buffer);
# Add a 1s timer to Quantar::SetHDLC_TxTraffic(0);
;
}



sub Events {
	if (!$Enabled) { return; }
	# P25Link Receiver
	foreach my $key (keys %P25Link) {
		if ($P25Link{$key}{'Connected'}) {
			my $TalkGroup;
			my $OutBuffer;
			for my $fh ($P25Link{$key}{'Sel'}->can_read(Read_Timeout)) {
				my $RemoteHost = $fh->recv(my $Buffer, MaxLen);
				$RemoteHost = $fh->peerhost;
				$P25Link{$key}{'RemoteHost'} = $RemoteHost;
#print "Key $key Con: $P25Link{$key}{'Connected'}\n";
				#if ($Verbose) {print "LocalHost = $LocalHost\n";}
				my $MulticastAddress = MakeMulticastAddress($key);
				if (($RemoteHost cmp $MulticastAddress) != 0) {
					if ($Verbose) {print "  P25Link Receiving TG $key " .
						"from IP $RemoteHost Data len(" . length($Buffer) . ")\n";
					}
					if (($Packets::PauseScan == 0) and ($Packets::TG{$key}{'Scan'} > $Packets::Scan)) {
						$TalkGroup = $key;
						$OutBuffer = $Buffer;
						$Packets::Scan = $Packets::TG{$key}{'Scan'};
					}
					if ($key == Packets::GetLinkedTalkGroup()) {
						$TalkGroup = $key;
						$OutBuffer = $Buffer;
						last;
					}
				}
			}
			if ($TalkGroup) {
				Rx($OutBuffer);
			}
		}
	}
}

sub GetEnabled {
	return($Enabled);
}

sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



#################################################################################
# Misc ##########################################################################
#################################################################################
sub GetTickCount {
	my ($epochSecs, $epochUSecs) = Time::HiRes::gettimeofday();
	my $num = $epochSecs . '.' . $epochUSecs;
	#print "Hello " . "$epochSecs $epochUSecs $Time::HiRes::VERSION \n";
	#print "Hello $num\n";
}

sub Bytes_2_HexString {
	my ($Buffer) = @_;
	# Display Rx Hex String.
	#print "Hex:\t";
	for (my $x = 0; $x < length($Buffer); $x++) {
		print sprintf("%02X ", ord(substr($Buffer, $x, 1)));
	}
	print "\n";
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


















1;