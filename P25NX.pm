package P25NX;
# P25NX.pm

use strict;
use warnings;
use Switch;
use Config::IniFiles;
#use IO::Socket::Multicast;
use Term::ANSIColor;



# Local modules:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use Quantar;



use constant MaxLen => 1024; # Max Socket Buffer length.
use constant Read_Timeout => 0.003;



my $LocalHost;
my $IPV6Addr;
my $UseRemoteCourtesyTone;
my $Enabled;
my $Verbose;
my $Port = 30000;
my %P25NX;



##################################################################
# P25NX ##########################################################
##################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init P25NX.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$UseRemoteCourtesyTone = $cfg->val('Settings', 'UseRemoteCourtesyTone');
	$Enabled = $cfg->val('P25NX', 'P25NX_Enabled');
	$Verbose =$cfg->val('P25NX', 'Verbose');
	print "  Enabled = $Enabled\n";
	print "  Verbose = $Verbose\n";
	print "----------------------------------------------------------------------\n";
}

sub JoinTG {
	my ($TalkGroup) = @_;
	if ($Enabled and ($TalkGroup >= 10100) and ($TalkGroup < 10600)) { # case P25NX.
		my $MulticastAddress = MakeMulticastAddress($TalkGroup);
		if ($Verbose) {print color('magenta'), "  P25NX connecting to $TalkGroup" .
			" Multicast Addr. $MulticastAddress:$Port\n", color('reset');
		}
		$P25NX{$TalkGroup}{'Sock'} = IO::Socket::Multicast->new(
			LocalHost => $MulticastAddress,
			LocalPort => $Port,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 1,
			ReuseAddr => 1,
			PeerPort => $Port
			)
			or die "Can not create Multicast : $@\n";
		$P25NX{$TalkGroup}{'Sel'} = IO::Select->new($P25NX{$TalkGroup}{'Sock'});
		$P25NX{$TalkGroup}{'Sock'}->mcast_add($MulticastAddress);
		$P25NX{$TalkGroup}{'Sock'}->mcast_ttl(10);
		$P25NX{$TalkGroup}{'Sock'}->mcast_loopback(0);
		$P25NX{$TalkGroup}{'Connected'} = 1;
		print "P25NX Joined $TalkGroup\n";
	}
}

sub Disconnect {
	my ($TalkGroup) = @_;
	if ($TalkGroup > 10099 and $TalkGroup < 10600){
		my $MulticastAddress = MakeMulticastAddress($TalkGroup);
		$P25NX{$TalkGroup}{'Sock'}->mcast_drop($MulticastAddress);
	}
	$P25NX{$TalkGroup}{'Connected'} = 0;
	$P25NX{$TalkGroup}{'Sock'}->close();
	print color('green'), "P25NX TG $TalkGroup Disconnected.\n", color('reset');
}

sub MakeMulticastAddress {
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
	#if ($Verbose) {print "MakeMulticastAddress = $ThisAddress\n";}
	return $ThisAddress;
}

sub Rx {
	my ($Buffer) = @_;
	if (length($Buffer) < 1) {return;}
	#if ($Verbose) {print "P25NX_Rx\n";} if ($Verbose) {
		#print "P25NX_Rx HexData = " . Bytes_2_HexString($Buffer) . "\n";
	#}
	#MMDVM_Tx(substr($Buffer, 9, length($Buffer)));
	P25NX_to_HDLC($Buffer);

}

sub Tx { # This function expect to Rx a formed Cisco STUN Packet.
	my ($LinkedTalkGroup, $Buffer) = @_;
	if ($P25NX{$LinkedTalkGroup}{'Connected'} != 1) {
		return;
	}
	if ($Verbose) {print "P25NX Linked TG *** $LinkedTalkGroup \n";}
	# Tx to the Network.
	if ($Verbose >= 2) {print "P25NX_Tx Message " . Bytes_2_HexString($Buffer) . "\n";}
	my $MulticastAddress = MakeMulticastAddress($LinkedTalkGroup);
	for (my $x = 0; $x < length($x); $x++) {
		if (substr($Buffer, $x, 1) > 255) {
			die;
		}
	}
	$P25NX{$LinkedTalkGroup}{'Sock'}->mcast_ttl(10);
	$P25NX{$LinkedTalkGroup}{'Sock'}->mcast_loopback(0);
	$P25NX{$LinkedTalkGroup}{'Sock'}->mcast_send($Buffer, $MulticastAddress . ":" . $Port);
	if ($Verbose) {
		print "P25NX_Tx TG $LinkedTalkGroup IP Mcast $MulticastAddress\n";
	}
	if ($Verbose) {print "P25NX_Tx Done.\n";}
}

sub P25NX_to_HDLC { # P25NX packet contains Cisco STUN and Quantar packet.
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
		if ($Quantar::Quant{'PrevFrame'} ne $Buffer) {
			print color('green'), "Network Tail_P25NX\n", color('reset');
			if ($UseRemoteCourtesyTone) {
				$Packets::Pending_CourtesyTone = 2;
			}
		}
	}
	Quantar::SetPrevFrame($Buffer);
# Add a 1s timer to Quantar::SetHDLC_TxTraffic(0);
}

sub Events {
	my $Scan = 0;
	if (!$Enabled) { return; }
	# P25NX Receiver
	foreach my $key (keys %P25NX) {
		if ($P25NX{$key}{'Connected'}) {
			my $TalkGroup;
			my $OutBuffer;
			for my $fh ($P25NX{$key}{'Sel'}->can_read(Read_Timeout)) {
				my $RemoteHost = $fh->recv(my $Buffer, MaxLen);
				$RemoteHost = $fh->peerhost;
				$P25NX{$key}{'RemoteHost'} = $RemoteHost;
print "Key $key Con: $P25NX{$key}{'Connected'}\n";
				#if ($Verbose) {print "P25NX_LocalHost $LocalHost\n";}
				my $MulticastAddress = MakeMulticastAddress($key);
				if (($RemoteHost cmp $MulticastAddress) != 0) {
					if ($Verbose >= 2) {print "  P25NX Receiving TG $key " .
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



1;