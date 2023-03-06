package MMDVM;
# MMDVM.pm

use strict;
use warnings;
use Config::IniFiles;
use Switch;
use IO::Socket::IP;
use Term::ANSIColor;



# Local modules:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use P25Link;
use Quantar;



use constant MaxLen => 1024; # Max Socket Buffer length.
use constant Read_Timeout => 0.003;

my $LocalHost;
my $IPV6Addr;
my $MMDVM_Enabled;
my $Callsign;
my $RadioID;
our $Version2 = 0;
my $Verbose;
my $MMDVM_LocalPort = 41020; # Local Port.
my $MMDVM_RemoteHost;
my $MMDVM_TG = 0;
my %MMDVM;
my $Tx_Started = 0;
my $OldBuffer = 0;



#################################################################################
# MMDVM #########################################################################
#################################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init MMDVM.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$LocalHost = $cfg->val('Settings', 'LocalHost');
	#my($LocalIPAddr) = inet_ntoa((gethostbyname(hostname))[4]);
	my($LocalHostIP) = inet_ntoa((gethostbyname($LocalHost))[4]);
	$IPV6Addr = $cfg->val('Settings', 'IPV6Addr');
#	my($IPV6AddrIP) = inet_ntop((gethostbyname($IPV6Addr))[4]);
	$MMDVM_Enabled = $cfg->val('MMDVM', 'MMDVM_Enabled');
	$Callsign = $cfg->val('MMDVM', 'Callsign');
	$RadioID = $cfg->val('MMDVM', 'RadioID');
	$Version2 = $cfg->val('MMDVM', 'Version2');
	$Verbose = $cfg->val('MMDVM', 'Verbose');
	print "  Enabled = $MMDVM_Enabled\n";
	print "  Callsign = $Callsign\n";
	print "  RadioID = $RadioID\n";
	print "  Version2 = $Version2\n";
	print "  Verbose = $Verbose\n";

	$MMDVM{'TimeoutTimer'}{'Interval'} = 5; # sec.
	$MMDVM{'TimeoutTimer'}{'NextTime'} = P25Link::GetTickCount() + $MMDVM{'TimeoutTimer'}{'Interval'};
	$MMDVM{'TimeoutTimer'}{'Enabled'} = 1;
	$MMDVM{'Linked'} = 0;
	$MMDVM{'Prev_UI'} = 0;
	print "----------------------------------------------------------------------\n";
}

sub Join {
	my ($TalkGroup, $URL, $Port) = @_;
	if ($MMDVM_Enabled) { # Case MMDVM.
		# Connect to TG.
		if ($Verbose) {print color('magenta'), "  MMDVM connecting to TG $TalkGroup" .
			" IP $Packets::TG{$TalkGroup}{'MMDVM_URL'} on Port $Packets::TG{$TalkGroup}{'MMDVM_Port'}\n", color('reset');
		}
		$MMDVM{'Sock'} = IO::Socket::IP->new(
			LocalPort => $MMDVM_LocalPort,
			Proto => 'udp',
			Blocking => 0,
			Broadcast => 0,
			ReuseAddr => 1,
			PeerHost => $Packets::TG{$TalkGroup}{'MMDVM_URL'},
			PeerPort => $Packets::TG{$TalkGroup}{'MMDVM_Port'}
		) || Sock_Error($TalkGroup);

		# Test Socket
		if ($MMDVM{'Linked'} == -1) {
			Packets::SetLinkedTalkGroup($TalkGroup);
			Packets::SetValidNteworkTG(0);
			return;
		}

		$MMDVM{'Sel'} = IO::Select->new($MMDVM{'Sock'});
		$MMDVM_TG = $TalkGroup;
		WritePoll($TalkGroup);
		WritePoll($TalkGroup);
		WritePoll($TalkGroup);
	}

}

sub Sock_Error {
	my ($TalkGroup) = @_;
	warn color('yellow'), "Can not Bind MMDVM : $@\n",  color('reset');
	Packets::SetTG_Linked(-1);
}

sub WritePoll {
	my ($TalkGroup) = @_;
	my $Filler = chr(0x20);
	my $Data = chr(0xF0) . $Callsign;
	for (my $x = length($Data); $x < 11; $x++) {
		$Data .= $Filler;
	}

	$MMDVM{'Sock'}->send($Data);
	if ($Verbose) {
		print "  MMDVM WritePoll IP $TalkGroup IP $Packets::TG{$TalkGroup}{'MMDVM_URL'} Port $Packets::TG{$TalkGroup}{'MMDVM_Port'}\n";
	}
	$MMDVM{'Connected'} = 1;
}

sub WriteUnlink {
	my ($TalkGroup) = @_;
	my $Filler = chr(0x20);
	my $Data = chr(0xF1) . $Callsign;
	for (my $x = length($Data); $x < 11; $x++) {
		$Data .= $Filler;
	}
	$MMDVM{'Sock'}->send($Data);
	if ($Verbose) {
		print "MMDVM WriteUnlink TG $TalkGroup IP $Packets::TG{$TalkGroup}{'MMDVM_URL'} Port $Packets::TG{$TalkGroup}{'MMDVM_Port'}\n";
	}
	$MMDVM{'Connected'} = 0;
	$MMDVM{'Sock'}->close();
}

sub Rx { # Only HDLC UI Frame. Start on Quantar v.24 Byte 3.
	my ($TalkGroup, $Buffer) = @_;
	my $HexData = "";
	if ($Verbose) {print "MMDVM_Rx Len(Buffer) = " . length($Buffer) . "\n";}
	if (length($Buffer) < 1) { return; }
	my $OpCode = ord(substr($Buffer, 0, 1));
	if ($Verbose) {print "MMDVM_Rx OpCode = " . sprintf("0x%02X", $OpCode) . ", TG $TalkGroup.\n";}
	switch ($OpCode) {
		case [0x60..0x61] { # Headers data.
			if ($OldBuffer eq $Buffer) {
				if ($Verbose) { print color('yellow'), "MMDVM::Rx Ignoring duplicated packet\n", color('reset'); }
				return;
			}
			if ($Verbose) { print "MMDVM_Rx Header Rx.\n"; }
			$MMDVM{'Prev_UI'} = $OpCode;

#			if (($Packets::PauseScan == 0) and ($TG{$TalkGroup}{'Scan'} > $Scan)) {
#				$OutBuffer = $Buffer;
#				$Scan = $TG{$key}{'Scan'};
#			}
#			if ($TalkGroup == P25Link::GetLinkedTalkGroup()) {
#				$OutBuffer = $Buffer;
#				last;
#			}
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case [0x62..0x73] { # Audio data.
			if ($OldBuffer eq $Buffer) {
				if ($Verbose) { print color('yellow'), "MMDVM::Rx Ignoring duplicated packet\n", color('reset'); }
				return;
			}
			if ($OpCode == 0x62 and ($MMDVM{'Prev_UI'} == 0x00 or $MMDVM{'Prev_UI'} == 0x80)) {
				warn color('red'), "MMDVM_Rx UI " . sprintf("0x%02X", $OpCode) .
					" Voice Header missing.\n", color('reset');
			}
			if ($MMDVM{'Prev_UI'} < 0x73) {

				if ($OpCode - 1 != $MMDVM{'Prev_UI'}) {
					warn color('red'), "MMDVM_Rx UI " . sprintf("0x%02X", $MMDVM{'Prev_UI'}) .
						" Voice Frame missing.\n", color('reset');
				}

			}
			$MMDVM{'Prev_UI'} = $OpCode;
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case 0x80 { # End Tx.
			if ($OldBuffer eq $Buffer) {
				if ($Verbose) { print color('yellow'), "MMDVM::Rx Ignoring duplicated packet\n", color('reset'); }
				return;
			}
			if ($Verbose) { print "MMDVM_Rx Footer Rx.\n"; }
			$MMDVM{'Prev_UI'} = $OpCode;
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case [0xA1] { # Page data.
			if ($OldBuffer eq $Buffer) {
				if ($Verbose) { print color('yellow'), "MMDVM::Rx Ignoring duplicated packet\n", color('reset'); }
				return;
			}
			$MMDVM{'Prev_UI'} = $OpCode;
			MMDVM_to_HDLC($Buffer); # Use to bridge MMDVM to HDLC.
		}
		case 0xF0 { # Ref. Poll Ack.
			$MMDVM{'Prev_UI'} = $OpCode;
			if ($Verbose) {print "  Poll Reflector Ack, TG $TalkGroup.\n";}
			#$MMDVM{'Connected'} = 1;
		}	
		case 0xF1 { # Ref. Disconnect Ack.
			if ($Verbose) {print "  Ref. Disconnect Ack Rx, TG $TalkGroup.\n";}
			$MMDVM{'Prev_UI'} = $OpCode;
			$MMDVM{'Connected'} = 0;
			$MMDVM{'Sock'}->close();
			#$MMDVM_Listen_Enable = 0;
		}
		case 0xF2 { # Start of Tx.
			if ($Verbose) {print "  0xF2, TG $TalkGroup.\n";}
			$MMDVM{'Prev_UI'} = $OpCode;
		} else {
			print "  else " . hex(ord(substr($Buffer, 0, 1))) ." else Len = " . length($Buffer) . "\n";
			$MMDVM{'Prev_UI'} = $OpCode;
		}
	}
	$OldBuffer = $Buffer;
}

sub Tx {
	my ($TalkGroup, $Buffer) = @_;
	if ($MMDVM{'Connected'}) {
		$MMDVM{'Sock'}->send($Buffer);
	}
}

sub TimeoutTimer {
	if (P25Link::GetTickCount() >= $MMDVM{'TimeoutTimer'}{'NextTime'}) {
		#if ($Verbose) { print color('green'), "MMDVM_TimeoutTimer event " .
		#	P25Link::GetTickCount() . "\n", color('reset'); }
		if (($MMDVM{'TimeoutTimer'}{'Enabled'} == 1)) {
			if ($Verbose) { print color('green'), "MMDVM_TimeoutTimer event\n", color('reset'); }
			if ($MMDVM{'Connected'}) {
				WritePoll($MMDVM_TG);
			}
		}
		if ($Verbose) {
			print "----------------------------------------------------------------------\n";
		}
		$MMDVM{'TimeoutTimer'}{'NextTime'} = P25Link::GetTickCount() + $MMDVM{'TimeoutTimer'}{'Interval'};
	}
}



sub MMDVM_to_HDLC {
	my ($Buffer) = @_;
	if ( (Quantar::GetHDLC_Handshake() == 0) or (length($Buffer) < 1) ) { return; }
		if (Packets::GetLocalActive() == 1) {
			return;
		}
	if ($Verbose >= 2) {
		print "MMDVM_to_HDLC In.\n";
		P25Link::Bytes_2_HexString($Buffer);
	}
	my $Address = 0xFD; #0x07 or 0xFD
	$Tx_Started = 1;
	my $OpCode = ord(substr($Buffer, 0, 1));
	switch ($OpCode) {
		case [0x60..0x61] { # Use to bridge MMDVM to HDLC.
			$Buffer = chr($Address) . chr(Quantar::C_UI) . $Buffer;
			if ($Verbose == 2) {
				print "MMDVM_to_HDLC Header Out:\n";
				P25Link::Bytes_2_HexString($Buffer);
			}
			Quantar::SetHDLC_TxTraffic(1);
			Quantar::HDLC_Tx($Buffer, 1);
		}
		case [0x62..0x73] { # Use to bridge MMDVM to HDLC.
			$Buffer = chr($Address) . chr(Quantar::C_UI) . $Buffer;
			if ($Verbose == 2) {
				print "MMDVM_to_HDLC Voice Out:\n";
				P25Link::Bytes_2_HexString($Buffer);
			}
			Quantar::SetHDLC_TxTraffic(1);
			Quantar::HDLC_Tx($Buffer, 1);
		}
		case 0x80 {
			$Tx_Started = 0;
			my $RTRT;
			if ($Quantar::HDLC_RTRT_Enabled == 1) {
				$RTRT = Quantar::C_RTRT_Enabled;
			} else {
				$RTRT = Quantar::C_RTRT_Disabled;
			}
			Quantar::HDLC_Tx(chr($Address) . chr(Quantar::C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
				chr(Quantar::C_EndTx) . chr(Quantar::C_DVoice) . chr(0x00) . chr(0x00) . chr(0x00) .
				chr(0x00) . chr(0x00), 1);
			Quantar::HDLC_Tx(chr($Address) . chr(Quantar::C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
				chr(Quantar::C_EndTx) . chr(Quantar::C_DVoice) . chr(0x00) . chr(0x00) . chr(0x00) .
				chr(0x00) . chr(0x00), 1);
			if ($Verbose) { print color('green'), "Network Tail_MMDVM_to_HDLC\n", color('reset'); }
			if ($Packets::UseRemoteCourtesyTone) {
				$Packets::Pending_CourtesyTone = 2;
			}
			Quantar::SetHDLC_TxTraffic(0);
		}
	}
}

sub Events {
	my $Scan = 0;
	# MMDVM Receiver.
	if ($MMDVM{'Connected'}) {
		my $OutBuffer;
		my $ValidScan = 0;
		for my $fh ($MMDVM{'Sel'}->can_read(Read_Timeout)) {
			my $RemoteHost = $fh->recv(my $Buffer, MaxLen);
			$RemoteHost = $fh->peerhost;
			if ($Verbose > 1) { print "  MMDVM_RemoteHost = $RemoteHost\n"; }
			if (($RemoteHost cmp $LocalHost) != 0) {
				#if ($Verbose) {print "$hour:$min:$sec $RemoteHost" .
				#	" MMDVM Data len(" . length($Buffer) . ")\n";
				#}
				my $OpCode = ord(substr($Buffer, 0, 1));
				if ($Verbose > 1) {
					print "  MMDVM_Receiver OpCode = " . sprintf("0x%X", $OpCode) . "\n";
				}
				if ($OpCode == 0xF0) { # Ref. Poll Ack.
					Rx($MMDVM_TG, $Buffer);
				} else {
					if (($Packets::PauseScan == 0) and ($Packets::TG{$MMDVM_TG}{'Scan'} > $Scan)) {
						$OutBuffer = $Buffer;
						$Scan = $Packets::TG{$MMDVM_TG}{'Scan'};
					}
					if ($MMDVM_TG == Packets::GetLinkedTalkGroup()) {
						$ValidScan = 1;
						$OutBuffer = $Buffer;
					}
				}
			}
			if ($ValidScan) {
				Rx($MMDVM_TG, $OutBuffer);
			}
		}
	}
}



sub GetLinkedTG {
	return($MMDVM_TG);
}

sub SetLinkedTG {
	my ($Value) = @_;
	$$MMDVM_TG = $Value;
}

sub GetEnabled {
	return($MMDVM_Enabled);
}

sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;