package Packets;
# Packets.pm

use strict;
use warnings;
use Switch;
use Config::IniFiles;
use IO::Socket::IP;
use Term::ANSIColor;



# Local modules:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
use CiscoSTUN;
use SuperFrame;



our $Mode;
our $Hotkeys;
my $LocalHost;
my $LocalHostIP;
my $IPV6Addr;
our $PriorityTG;
my $Hangtime;
my $MuteTGTimeout;
our $UseVoicePrompts;
our $UseLocalCourtesyTone;
our $UseRemoteCourtesyTone;
my $SiteName;
my $SiteInfo;
my $Verbose;

my $TalkGroupsFile;
our %TG;
our $Scan = 0;
my $LocalActive = 0;
our $PauseScan = 0;
my $ValidNteworkTG = 0;
our $Pending_CourtesyTone = 0;
my $PauseTGScanTime = 0;
my $LinkedTalkGroup;

our $Pending_VA = 0;
our $VA_Message = 0;

our $Trigger = 0;



##################################################################
# Settings #######################################################
##################################################################
sub Load_Settings {
	my ($ConfigFile) = @_;
	# Load Settings ini file.
	print color('green'), "Loading Settings...\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	# Settings:
	$Mode = $cfg->val('Settings', 'HardwareMode'); #0 = v.24, no other modes coded at the momment.
	$Packets::HotKeys = $cfg->val('Settings', 'HotKeys');
	$LocalHost = $cfg->val('Settings', 'LocalHost');
		#my($LocalIPAddr) = inet_ntoa((gethostbyname(hostname))[4]);
		($LocalHostIP) = inet_ntoa((gethostbyname($LocalHost))[4]);
	$IPV6Addr = $cfg->val('Settings', 'IPV6Addr');
	#	my($IPV6AddrIP) = inet_ntop((gethostbyname($IPV6Addr))[4]);

	$PriorityTG = $cfg->val('Settings', 'PriorityTG');
	$Hangtime = $cfg->val('Settings', 'Hangtime');
	$MuteTGTimeout = $cfg->val('Settings', 'MuteTGTimeout');
	$UseVoicePrompts = $cfg->val('Settings', 'UseVoicePrompts');
	$UseLocalCourtesyTone = $cfg->val('Settings', 'UseLocalCourtesyTone');
	$UseRemoteCourtesyTone = $cfg->val('Settings', 'UseRemoteCourtesyTone');
	$SiteName = $cfg->val('Settings', 'SiteName');
	$SiteInfo = $cfg->val('Settings', 'SiteInfo');
	$Verbose = $cfg->val('Settings', 'Verbose');
	print "  Mode = $Mode\n";
	print "  HotKeys = $Packets::HotKeys\n";
	print "  LocalHost = $LocalHost    ntoa($LocalHostIP)\n";
	print "  IPV6Addr = $IPV6Addr    \n";
	print "  Mute Talk Group Timeout = $MuteTGTimeout seconds.\n";
	print "  Use Voice Prompts = $UseVoicePrompts\n";
	print "  Use Local Courtesy Tone = $UseLocalCourtesyTone\n";
	print "  Use Remote Courtesy Tone = $UseRemoteCourtesyTone\n";
	print "  Site Name = $SiteName\n";
	print "  Site Info = $SiteInfo\n";
	print "  Verbose = $Verbose\n";
	if ($SiteName eq "Default" or $SiteInfo eq "Default") {
		die("Please review all fields on your config file, you can not use Default as a value.");
	}
	print "----------------------------------------------------------------------\n";

	# TalkGroups:
	print color('green'), "Init TalkGroups...\n", color('reset');
	$TalkGroupsFile = $cfg->val('TalkGroups', 'HostsFile');
	print "  Talk Groups File: " . $TalkGroupsFile ."\n";
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
			if ($Verbose) {
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
		if ($Verbose > 2) {
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
	print "----------------------------------------------------------------------\n";
}

sub InitScanList {
	print color('green'), "Init Priority and Scan TGs...\n", color('reset');
	$ValidNteworkTG = 0;
	# Voice Announce.
	$Pending_CourtesyTone = 0;

	# Connect to Priority and scan TGs.
	$LocalActive = 0;
	$PauseScan = 0;
	$PauseTGScanTime = P25Link::GetTickCount();
	$LinkedTalkGroup = $PriorityTG;

	foreach my $key (keys %TG) {
		if ($TG{$key}{'Scan'}) {
			print "  Scan TG " . $key . "\n";
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
}



##################################################################
# Traffic control ################################################
##################################################################
sub Tx_to_Network {
	my ($Buffer) = @_;
	if (($LinkedTalkGroup <= 10) or ($ValidNteworkTG == 0)) {
		return;
	}
	if ($Verbose) {print color('grey12'), "Tx_to_Network " . $TG{$LinkedTalkGroup}{'Mode'} . 
		" TalkGroup " . $LinkedTalkGroup . "\n", color('reset'); }

	if ( P25Link::GetEnabled() and ($TG{$LinkedTalkGroup}{'Mode'} eq 'P25Link') and 
		($LinkedTalkGroup > 10) and ($LinkedTalkGroup < 65535) ) { # Case P25Link.
		HDLC_to_P25Link($Buffer);
		return;
	}
	if ( P25NX::GetEnabled() and ($TG{$LinkedTalkGroup}{'Mode'} eq 'P25NX') and
		($LinkedTalkGroup >= 10100) and ($LinkedTalkGroup < 10600) ) { # case P25NX.
		HDLC_to_P25NX($Buffer);
		return;
	}
	if ( MMDVM::GetEnabled() and ($TG{$LinkedTalkGroup}{'Mode'} eq 'MMDVM') and
		($LinkedTalkGroup > 10) and ($LinkedTalkGroup < 65535) ) { # Case MMDVM.
		HDLC_to_MMDVM($LinkedTalkGroup, $Buffer);
	}
}

sub HDLC_to_MMDVM {
	my ($TalkGroup, $Buffer) = @_;
	my $OpCode = ord(substr($Buffer, 2 , 1));
	switch ($OpCode) {
		case 0x00 {
			switch (ord(substr($Buffer, 5, 1))) {
				case 0x0C {
					if ($Verbose) {print color('yellow'), "HDLC_to_MMDVM A output:\n", color('reset');}
					if ($MMDVM::Version1) {
						MMDVM::Tx($TalkGroup, chr(0x72) . chr(0x7B) . 
							chr(0x3D) . chr(0x9E) . chr(0x44) . chr(0x00) );
					}
				}
				case 0x25 {
					if ($Verbose) {print "HDLC_to_MMDVM ICW Terminate output:\n";}
					if ($MMDVM::Version1) {
						MMDVM::Tx($TalkGroup, chr(0x80) . chr(0x00). chr(0x00) .
							chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
							chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
							chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) .
							chr(0x00) );
					}
				}
			}
		}
		case [0x60..0x61] {
			$Buffer = substr($Buffer, 2, length($Buffer)); # Here we remove first 2 Quantar Bytes.
			if ($Verbose) {print "HDLC_to_MMDVM Header output:\n";}
			if ($Verbose >= 2) {P25Link::Bytes_2_HexString($Buffer);}
			if ($MMDVM::Version1) {
				MMDVM::Tx($TalkGroup, $Buffer);
				SuperFrame::AddVoiceFrame($TalkGroup, $Buffer);
			} else {
				SuperFrame::AddVoiceFrame($TalkGroup, $Buffer);
			}
		}
		case [0x62..0x73] {
			$Buffer = substr($Buffer, 2, length($Buffer)); # Here we remove first 2 Quantar Bytes.
			if ($Verbose) {print "HDLC_to_MMDVM Voice output:\n";}
			if ($Verbose >= 2) {P25Link::Bytes_2_HexString($Buffer);}
			if ($MMDVM::Version1) {
				MMDVM::Tx($TalkGroup, $Buffer);
				SuperFrame::AddVoiceFrame($TalkGroup, $Buffer);
			} else {
				SuperFrame::AddVoiceFrame($TalkGroup, $Buffer);
				if ($OpCode == 0x73) {
#					MMDVM::Tx($TalkGroup, $SuperFrame::SuperFrame);
				}
			}
		}
		else {
			warn "HDLC_to_MMDVM Error code " . (ord(substr($Buffer, 2, 1))) . "\n";
			P25Link::Bytes_2_HexString($Buffer);
			return;
		}
	}
}

sub HDLC_to_P25Link {
	my ($Buffer) = @_;
	my $Stun_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(2 + length($Buffer)) . chr(CiscoSTUN::GetSTUN_ID()); #STUN Header.
	$Buffer = $Stun_Header . $Buffer;
	#print "HDLC_to_P25Link.\n";
	P25Link::Tx($LinkedTalkGroup, $Buffer);
}

sub HDLC_to_P25NX {
	my ($Buffer) = @_;
	my $Stun_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(2 + length($Buffer)) . chr(CiscoSTUN::GetSTUN_ID()); #STUN Header.
	$Buffer = $Stun_Header . $Buffer;
	print "HDLC_to_P25NX.\n";
	P25NX::Tx($LinkedTalkGroup, $Buffer);
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
			RDAC::Tx($TalkGroup, Quantar::GetLocalRx(), Quantar::GetLocalTx(),
				Quantar::GetIsDigitalVoice(), Quantar::GetIsPage(), Quantar::GetStationType());
			$VA_Message = $TalkGroup; # Select VA.
			$Pending_VA = 1;
		}
		$LinkedTalkGroup = $TalkGroup;
		$ValidNteworkTG = 0;
		print color('blue'), "Local Talk Group $TalkGroup.\n", color('reset');
		return;
	} elsif ($TG{$TalkGroup}{'Linked'} eq '') { # Undefined TG > 10, keep it local only.
			$TG{$TalkGroup}{'Linked'} = '';
			$ValidNteworkTG = 0;
			print color('yellow'), "Undefined TG $TalkGroup.\n", color('reset');
			return;
	} elsif ($TG{$TalkGroup}{'Linked'} == 1) { # Defined TG, and linked.
		if ($TalkGroup != $LinkedTalkGroup) {
			$VA_Message = $TalkGroup; # Select VA.
			$Pending_VA = 1;
		}
		$LinkedTalkGroup = $TalkGroup;
		$ValidNteworkTG = 1;
		if ($TG{$TalkGroup}{'Scan'} == 0) {
			$TG{$TalkGroup}{'Timer'} = P25Link::GetTickCount();
		}
		print color('blue'), "  System already linked to TG $TalkGroup.\n", color('reset');
		return;
	}

	# Defined TG but not linked, create a link by connecting to the network.
	if (P25Link::GetEnabled() and ($TG{$TalkGroup}{'Mode'} eq 'P25Link')) { # Case P25Link.
		P25Link::JoinTG($TalkGroup);
	} elsif ( P25NX::GetEnabled() and ($TalkGroup >= 10100) and ($TalkGroup < 10600)
		and ($TG{$TalkGroup}{'Mode'} eq 'P25NX')) { # case P25NX.
		P25NX::JoinTG($TalkGroup);
	} elsif ( MMDVM::GetEnabled() and ($TG{$TalkGroup}{'Mode'} eq 'MMDVM') ) { # Case MMDVM.
		# Disconnect previous Reflector
		if (MMDVM::GetLinkedTG() != 0 ) {
			RemoveLinkTG (MMDVM::GetLinkedTG());
		}

		# Search if reflector exist
		if (exists($TG{$TalkGroup}{'MMDVM_URL'}) != 1) {
			if ($Verbose) {warn color('red'), "This is a local only TG and program shold not reach here.\n",
			 color('reset');}
			return;
		}
		# Connect to TG.
		MMDVM::Join($TalkGroup, $TG{$TalkGroup}{'MMDVM_URL'}, $TG{$TalkGroup}{'MMDVM_Port'});
	}

	# Finalize linking new TG.
	$TG{$TalkGroup}{'Linked'} = 1;
	$LinkedTalkGroup = $TalkGroup;
	$ValidNteworkTG = 1;
	if ($TG{$TalkGroup}{'Scan'} == 0) {
		$TG{$TalkGroup}{'Timer'} = P25Link::GetTickCount();
	}
	$VA_Message = $TalkGroup; # Linked TalkGroup.
	$Pending_VA = 1;
	print color('grey12'), "  System Linked to TG $TalkGroup\n", color('reset');
}



sub RemoveLinkTG {
	my ($TalkGroup) = @_;
	if ($TG{$TalkGroup}{'Linked'} == 0) {
		return;
	}
	print color('magenta'), "RemoveLinkTG $TalkGroup\n", color('reset');
	# Disconnect from current network.
	if ($TG{$TalkGroup}{'MMDVM_Connected'}) {
		MMDVM::WriteUnlink($TalkGroup); 
		MMDVM::SetLinkedTG(0);
	}
	if ($TG{$TalkGroup}{'MMDVM_Connected'}) { MMDVM::WriteUnlink($TalkGroup); }
	if ($TG{$TalkGroup}{'P25Link_Connected'}) { P25Link::Disconnect($TalkGroup); }
	if ($TG{$TalkGroup}{'P25NX_Connected'}) { P25NX::Disconnect($TalkGroup); }
	$TG{$TalkGroup}{'Linked'} = 0;
	#print "  System Disconnected from TG $TalkGroup\n";
}

sub Disconnect {
	foreach my $key (keys %TG){ # Close Socket connections:
		if (($TG{$key}{'MMDVM_Connected'} >= 1) or ($TG{$key}{'P25Link_Connected'} >= 1) or
				($TG{$key}{'P25NX_Connected'} >= 1)) {
			RemoveLinkTG($key);
		}
	}
}

sub PauseTGScan {
	print color('yellow'), "PauseTGScan starting.\n", color('reset');
	$PauseScan = 1;
	$PauseTGScanTime = P25Link::GetTickCount() + $MuteTGTimeout;
}

sub PauseTGScan_Timer {
	if (($PauseScan == 1) and (P25Link::GetTickCount() >= $PauseTGScanTime)) {
		print color('yellow'), "PauseTGScan_Timer expired.\n", color('reset');
		$PauseScan = 0;
		RDAC::Tx($LinkedTalkGroup, Quantar::GetLocalRx(), Quantar::GetLocalTx(), 
			Quantar::GetIsDigitalVoice(), Quantar::GetIsPage(), Quantar::GetStationType());
		#$VA_Message = 0xFFFF13; # Default Revert.
		#$Pending_VA = 1;
	}
}

sub RemoveDynamicTGLink {
	foreach my $key (keys %TG) {
		if ( ($TG{$key}{'P25Link_Connected'} or $TG{$key}{'P25NX_Connected'} or 
			$TG{$key}{'MMDVM_Connected'} ) and (Packets::GetTGScan($key) == 0) ) {
			if (P25Link::GetTickCount() > ($TG{$key}{'Timer'} + $Hangtime)) {
				print color('yellow'), "RemoveDinamicTGLink $key.\n", color('reset');
				RemoveLinkTG($key);
				RDAC::Tx($PriorityTG, Quantar::GetLocalRx(), Quantar::GetLocalTx(),
					Quantar::GetIsDigitalVoice(), Quantar::GetIsPage(), Quantar::GetStationType());
				$VA_Message = 0xFFFF13; # Default Revert.
				$Pending_VA = 1;
			}
		}
	}
}

sub TxLossTimeout_Timer { # End of Tx timmer (1 sec).
	if ((Quantar::GetLocalRx() > 0) and (P25Link::GetTickCount() >= int(Quantar::GetLocalRx_Time()) + 2)) {
		print color('green'), "TxLosTimeout_Timer event " . Quantar::GetLocalRx() . "\n", color('reset');
		#if (int(Quant::GetLocalRx_Time()) + 1000) <= $TickCount) {
		#	print "bla\n" ;
		#}
		Quantar::SetLocalRx(0);
		$Pending_CourtesyTone = 1; # Let the system know we wish a courtesy tone when possible.
	}
}



sub GetLocalActive {
	return($LocalActive);
}

sub GetPauseTGScanTime {
	return($PauseTGScanTime);
}

sub GetLinkedTalkGroup {
	return($LinkedTalkGroup);
}

sub SetLinkedTalkGroup {
	my ($Value) = @_;
	$LinkedTalkGroup = $Value;
}

sub GetValidNteworkTG {
	return($ValidNteworkTG);
}

sub SetValidNteworkTG {
	my ($Value) = @_;
	$ValidNteworkTG = $Value;
}







sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;
