package DMR;
# DMR.pm

use strict;
use warnings;
use Switch;
use Config::IniFiles;
use IO::Socket::IP;
use Term::ANSIColor;
use Digest::SHA qw(sha256 sha256_hex);



#use constant SoftwareID => 20221231;
use constant SoftwareID => "20230306_v2.40.6";
#use constant SoftwareID => "20210617_PS4";
use constant PackageID => "MMDVM_Unknown";
#use constant PackageID => "MMDVM_DMO";
#use constant PackageID => "MMDVM Motorola Quantar";
#use constant PackageID => "MMDVM Motorola DIU 3000";

use constant BMPasword => "passw0rd";
use constant DMRPlusPasword => "PASSWORD";

use constant Waiting_Connect => 0x00;
use constant Waiting_Login => 0x01;
use constant Waiting_Authorization => 0x02;
use constant Waiting_Config => 0x03;
use constant Waiting_Options => 0x04;
use constant Running => 0x05;

my $MaxLen = 1024; # Max Socket Buffer length.
my $Read_Timeout = 0.003;

my %DMR;
my $My_RxFreq;
my $My_ColorCode;
my $My_HeightAGL;
my $My_TxPower;
my $My_Location;
my $My_Description;
my $My_URL;
my $Verbose; 
my $LocalHost;
my $IPV6Addr;
my $My_Latitude;
my $My_Longitude;
my $My_Freq;



#################################################################################
# DMR ###########################################################################
#################################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init DMR.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$DMR{'Enabled'} = $cfg->val('DMR', 'Enabled');
	$DMR{'Callsign'} = $cfg->val('DMR', 'Callsign');
	$DMR{'RepeaterID'} = $cfg->val('DMR', 'RepeaterID');
	$DMR{'MMDVM_Host_Mode'} = $cfg->val('DMR', 'MMDVM_Host_Mode');
	$DMR{'ServerAddress'} = $cfg->val('DMR', 'ServerAddress');
	$DMR{'ServerPort'} = $cfg->val('DMR', 'ServerPort');
	#$DMR{'Jitter'} = $cfg->val('DMR', 'Jitter');
	$DMR{'LocalPort'} = $cfg->val('DMR', 'LocalPort');
	$DMR{'Password'} = $cfg->val('DMR', 'Password');
	$DMR{'Options'} = "" . $cfg->val('DMR', 'Options');
	if (length($DMR{'Options'}) <= 0) {$DMR{'Options'} = ""}
	$My_RxFreq = $cfg->val('DMR', 'RxFrequency');
	$My_ColorCode = $cfg->val('DMR', 'ColorCode');
	$My_HeightAGL = $cfg->val('DMR', 'HeightAGL');
	$My_TxPower = $cfg->val('DMR', 'TxPower');
	$My_Location = $cfg->val('DMR', 'Location');
	$My_Description = $cfg->val('DMR', 'Description');
	$My_URL = $cfg->val('DMR', 'URL');
	$Verbose = $cfg->val('DMR', 'Verbose');
	print "  Enabled = $DMR{'Enabled'}\n";
	print "  Callsign = $DMR{'Callsign'}\n";
	print "  RepeaterID = $DMR{'RepeaterID'}\n";
	print "  MMDVM_Host_Mode = $DMR{'MMDVM_Host_Mode'}\n";
	print "  ServerAddress = $DMR{'ServerAddress'}\n";
	print "  ServerPort = $DMR{'ServerPort'}\n";
	#print "  Jitter = $DMR{'Jitter'}\n";
	print "  LocalPort = $DMR{'LocalPort'}\n";
	print "  Password = $DMR{'Password'}\n";
	print "  Options = $DMR{'Options'}\n";
	print "  My_RxFreq = $My_RxFreq\n";
	print "  My_ColorCode = $My_ColorCode\n";
	print "  My_HeightAGL = $My_HeightAGL\n";
	print "  My_TxPower = $My_TxPower\n";
	print "  My_Location = My_Location\n";
	print "  My_Description = $My_Description\n";
	print "  My_URL = $My_URL\n";
	print "  Verbose = $Verbose\n";

	$LocalHost = $cfg->val('Settings', 'LocalHost');
		#my($LocalIPAddr) = inet_ntoa((gethostbyname(hostname))[4]);
		my($LocalHostIP) = inet_ntoa((gethostbyname($LocalHost))[4]);
	$IPV6Addr = $cfg->val('Settings', 'IPV6Addr');
	#	my($IPV6AddrIP) = inet_ntop((gethostbyname($IPV6Addr))[4]);
	$DMR{'LocalHost'} = $LocalHost; # Bind Address.
	$DMR{'RemoteHost'} = 0; # Buffer for Rx data IP.

	$DMR{'RepeaterID'} = sprintf("%08d", $DMR{'RepeaterID'});
	$DMR{'RepeaterID8'} = sprintf("%08X", $DMR{'RepeaterID'});
	$DMR{'RepeaterID4'} = pack("N", $DMR{'RepeaterID'});
	print "  RepeaterID  = $DMR{'RepeaterID'}\n";
	print "  RepeaterID8 = $DMR{'RepeaterID8'}\n";
	print "  RepeaterID4 = $DMR{'RepeaterID4'}\n";

	$My_Latitude = $cfg->val('APRS', 'Latitude');
	$My_Longitude = $cfg->val('APRS', 'Longitude');
	$My_Freq = $cfg->val('APRS', 'Frequency');

	# Timers
	$DMR{'RetryTimer'}{'Enabled'} = 0;
	$DMR{'RetryTimer'}{'Interval'} = 10;
	$DMR{'RetryTimer'}{'NextTime'} = P25Link::GetTickCount() + 1;
	$DMR{'TimeoutTimer'}{'Enabled'} = 0;
	$DMR{'TimeoutTimer'}{'Interval'} = 60;
	$DMR{'TimeoutTimer'}{'NextTime'} = P25Link::GetTickCount() + 6;

	$DMR{'State'} = Waiting_Connect;
	$DMR{'Linked'} = 0;
	$DMR{'SeqNum'} = 0;

	#if ($DMR{'Enabled'}) {
	#	$DMR{'RetryTimer'}{'Enabled'} = 1;
	#	$DMR{'TimeoutTimer'}{'Enabled'} = 1;
	#}
	if ($DMR{'Enabled'}) {
		if (DMR_Init() != 1) {
			print color('red'), "Unable to init DMR.\n", color('reset');
		}
	}
	print "----------------------------------------------------------------------\n";
}

sub DMR_Init {
	# Connect to DMR.
	if ($Verbose) { print color('green'), "DMR connecting to Master Server " .
		"$DMR{'ServerAddress'} on Port $DMR{'ServerPort'}\n", color('reset');
	}
	$DMR{'Sock'} = IO::Socket::IP->new(
		LocalPort => $DMR{'LocalPort'},
		Proto => 'udp',
		Blocking => 0,
		Broadcast => 0,
		ReuseAddr => 1,
		PeerHost => $DMR{'ServerAddress'},
		PeerPort => $DMR{'ServerPort'}
	) || Sock_Error();
	# Test Socket
	if ($DMR{'Linked'} == -1) {
		$DMR{'State'} = Waiting_Connect;
		return;
	}
	$DMR{'Sel'} = IO::Select->new($DMR{'Sock'});

	$DMR{'Linked'} = 1;
	if ($Verbose) { print "  UDP Connected\n"; }
	$DMR{'State'} = Waiting_Connect;
	StopTimeoutTimer();
	StartRetryTimer();
	return 1;
}

sub Sock_Error {
	my ($TalkGroup) = @_;
	warn color('yellow'), "Can not Bind DMR : $@\n", color('reset');
	$DMR{'Linked'} = -1;
}

sub Close {
	my ($SayGoodbye) = @_;
	if ($Verbose) { print "Closing DMR Network.\n"; }
	if ($SayGoodbye == 1 and $DMR{'State'} == Running) {
		RPTCL_Tx();
		$DMR{'Sock'}->close();
		$DMR{'Connected'} = 0;
	}
	StopTimeoutTimer();
	StopRetryTimer();
}

sub Rx {
	my ($Buffer) = @_;
	my $RepID4;
	my $RepID8;
	if ($Verbose) {
		print color('green'),"DMR_Rx Len = " . length($Buffer) . "   $Buffer\n", color('reset');
	}
	if ($Verbose >= 2) {
		print color('grey12'),"  DMR State = $DMR{'State'}\n", color('reset');
	}

	if (substr($Buffer,0,4) eq "DMRD" and $DMR{'Enabled'}) {
		$RepID4 = unpack("N", substr($Buffer, 4, 4));
		if ($Verbose) { print "DMR Incomming DMR Data.\n"; }
		DMRD_Rx($Buffer);
		return;
	} elsif (substr($Buffer,0,6) eq "MSTNAK" and $DMR{'RepeaterID'} == unpack("N", substr($Buffer, 6, 4))) {
		$RepID4 = unpack("N", substr($Buffer, 6, 4));
		if ($DMR{'State'} == Running) {
			print color('yellow'), "MSTNAK $RepID4 login to Master has failed, retrying login...\n",
				color('reset');
			if ($Verbose) { print "  Rx RepID4 = $RepID4\n"; }
			$DMR{'State'} = Waiting_Login;
			StartTimeoutTimer();
			StartRetryTimer();
		} else {
			print color('yellow'), "DMR_Rx RepID $RepID4 Login to Master has failed, retrying network...\n",
				color('reset');
			Close(0);

			if ($DMR{'Enabled'}) {
				if (DMR_Init() != 1) {
					print color('red'), "Unable to init DMR.\n", color('reset');
				}
			}
			$DMR{'State'} = Waiting_Connect;
			return;
		}
# MMDVMHost
	} elsif (substr($Buffer,0,6) eq "RPTACK") {
		$RepID4 = unpack("N", substr($Buffer, 6, 4));
		if ($Verbose) { print "  MMDVMHost   RPTACK Rx RepID4 = $RepID4\n"; }
		switch ($DMR{'State'}) {
			case [Waiting_Login] {
				if ($Verbose) { print "  MMDVMHost   Connection succeded, sending RPTK.\n"; }
				$DMR{'Salt'} = sprintf("%02x", ord(substr($Buffer, 6, 1))) .
					sprintf("%02x", ord(substr($Buffer, 7, 1))) .
					sprintf("%02x", ord(substr($Buffer, 8, 1))) .
					sprintf("%02x", ord(substr($Buffer, 9, 1)));
				if ($Verbose) {print "  Salt = $DMR{'Salt'}\n"; }
				$DMR{'Salt4'} = substr($Buffer, 6, 4);
				#$DMR{'Salt'} = "0A7ED498";
				#$DMR{'Password'} = "DL5DI";
				RPTK_Tx();
				$DMR{'State'} = Waiting_Authorization;
				StartTimeoutTimer();
				StartRetryTimer();
			}
			case [Waiting_Authorization] {
				if ($DMR{'RepeaterID'} == $RepID4) {
					if ($Verbose) { print "  MMDVMHost   Login succeded, sending RPTC.\n"; }
					RPTC_Tx();
					$DMR{'State'} = Waiting_Config;
					StartTimeoutTimer();
					StartRetryTimer();
				}
			}
			case [Waiting_Config] {
				if ($DMR{'RepeaterID'} == $RepID4) {
					if (length($DMR{'Options'}) == 0) {
						if ($Verbose) { print color('green'),
							"MMDVMHost   Configuration succeded, logged into the master.\n",
							color('reset');
						}
						$DMR{'State'} = Running;
					} else {
						if ($Verbose) { print color('green'),
							"MMDVMHost   Configuration succeded, sending RPTO.\n",
							color('reset'); }
						RPTPING();
						$DMR{'State'} = Waiting_Options;
					}
					StartTimeoutTimer();
					StartRetryTimer();
				}
			}
			case [Waiting_Options] {
				if ($DMR{'RepeaterID'} == $RepID4) {
					if ($Verbose) { print "  MMDVMHost   Options succeded, logged into the master.\n"; }
					$DMR{'State'} = Running;
					StartTimeoutTimer();
					StartRetryTimer();
				}
			}
			case [Running] {

			}
		}
	} elsif (substr($Buffer,0,5) eq "MSTCL" and $DMR{'RepeaterID'} == unpack("N", substr($Buffer, 5, 4))) {
		$RepID4 = unpack("N", substr($Buffer, 5, 4));
		if ($Verbose) { print "MSTCL Rx for Repeater $RepID4\n"; }
		if ($Verbose) {
			print color('yellow'), "MMDVMHost   DMR MSTCL Master is closing down.\n", color('reset');
		}
	} elsif (substr($Buffer,0,7) eq "MSTPONG") {
		$RepID4 = unpack("N", substr($Buffer, 7, 4));
		if ($RepID4 == $DMR{'RepeaterID'}) {
			if ($Verbose) {
				print color('green'),"MMDVMHost   MSTPONG Rx for Repeater $RepID4\n", color('reset');
			}
		} else {
			if ($Verbose) { print "MMDVMHost   MSTPONG Rx for Repeater $RepID4\n"; }
		}
		StartTimeoutTimer();
	} elsif (substr($Buffer,0,7) eq "RPTSBKN" and $DMR{'RepeaterID'} == unpack("N", substr($Buffer, 7, 4))) {
		my $Beacon = 1;
# DL5DI version
	} elsif (substr($Buffer,0,6) eq "MSTACK" and
			unpack("c", $DMR{'RepeaterID8'}) == unpack("c", substr($Buffer, 6, 8))) {
		$RepID8 = substr($Buffer, 6, 8);
		if ($Verbose) { print "DL5DI   MSTACK Rx for Repeater $RepID8\n"; }
		switch ($DMR{'State'}) {
			case [Waiting_Login] {
				if (length($Buffer) == 22) {
					if ($Verbose) { print "DL5DI   Connection succeded, sending RPTK.\n"; }
					$DMR{'Salt'} = substr($Buffer, 14, 8);
					if ($Verbose) {print "  Salt = $DMR{'Salt'}\n"; }
					RPTK_Tx();
					$DMR{'State'} = Waiting_Authorization;
					StartTimeoutTimer();
					StartRetryTimer();
				}
			}
			case [Waiting_Authorization] {
				if (length($Buffer) == 14) {
					if ($Verbose) { print "DL5DI   Login succeded, sending RPTC.\n"; }
					RPTC_Tx();
					$DMR{'State'} = Waiting_Config;
					StartTimeoutTimer();
					StartRetryTimer();
				}
			}
			case [Waiting_Config] {
				if (length($Buffer) == 14) {
					if ($Verbose) { print "DL5DI   Configuration succeded, sending RPTO.\n"; }
					if (length($DMR{'Options'}) == 0) {
						$DMR{'State'} = Running;
						MSTPING_Tx();
					} else {
						if ($Verbose) { print "DL5DI   Configuration succeded, sending RPTO.\n"; }
						RPTO_Tx();
						$DMR{'State'} = Waiting_Options;
					}
					StartTimeoutTimer();
					StartRetryTimer();
				}
			}
			case [Waiting_Options] {
					if ($Verbose) { print "DL5DI   Options succeded, logged into the master.\n"; }
					$DMR{'State'} = Running;
					StartTimeoutTimer();
					StartRetryTimer();
			}
			case [Running] {
			}
		}
	} elsif (substr($Buffer,0,7) eq "RPTPONG" and
			unpack("c", $DMR{'RepeaterID8'}) == unpack("c", substr($Buffer, 7, 8))) {
		if ($Verbose) { print "DL5DI   RPTPONG $DMR{'RepeaterID8'} received.\n"; }
		$DMR{'State'} = Running;
	} else {
		if ($Verbose) {
			print color('yellow'), "DMR   Unkown Data from Master = $Buffer\n", color('reset');
		}
	}
}

# Request to connect to Master Server
sub RPTL_Tx {
	my $Data = "RPTL";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
	} else {
		$Data .= $DMR{'RepeaterID8'};
	}
	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print "DMR RPTL_Tx Sent. $Data\n"; }
}

# Send Secret token to Master Server
sub RPTK_Tx {
	my $Data = "RPTK";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
	} else {
		$Data .= $DMR{'RepeaterID8'};
	}
	# Salt stuff
	# DMR{$'Salt'} = "0A7ED498";
	# $DMR{'Password'} = "DL5DI";
	if ($Verbose > 1) {
		print "  Salt = $DMR{'Salt'} Len(Salt) = " . length($DMR{'Salt'}) . "\n";
		print "  A = " . substr($DMR{'Salt'}, 0, 2) . "\n";
		print "  B = " . substr($DMR{'Salt'}, 2, 2) . "\n";
		print "  C = " . substr($DMR{'Salt'}, 4, 2) . "\n";
		print "  D = " . substr($DMR{'Salt'}, 6, 2) . "\n";
		print "  Salt + Password = " . $DMR{'Salt'} . $DMR{'Password'} . "\n";
	}
	my $HexKey = sha256_hex($DMR{'Salt'} . $DMR{'Password'});
	my $Key4 = sha256($DMR{'Salt4'} . $DMR{'Password'});
	if ($Verbose > 1) { print "  HexKey = $HexKey\n"; }
	# if ($Verbose) { print "  len(Key) = " . length($Key) . "\n"; }

	#my $Key2;
	#for (my $x = 0; $x < length($HexKey); $x = $x + 2) {
	#	$Key2 .= chr(hex(substr($HexKey, $x, 2)));
	#}
	#if ($Key eq $Key2) { print "  Equal keys: $HexKey\n"; }

	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $Key4;
	} else {
		$Data .= $HexKey;
	}
	#if ($Verbose) { print "RPTK_Tx len(Data) = " . length($Data) . ", Data = $Data\n"; }
	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print color('green'), "DMR RPTK_Tx Sent.\n", color('reset'); }
}

# Configuration
sub RPTC_Tx {
	my $Data = "RPTC";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
		$Data .= sprintf("%-8.8s", uc($DMR{'Callsign'}));
	} else {
		$Data .= sprintf("%-8s", uc($DMR{'Callsign'}));
		$Data .= $DMR{'RepeaterID8'};
	}
	$Data .= sprintf("%09u", $My_Freq * 1000000);
	$Data .= sprintf("%09u", $My_RxFreq * 1000000);
	if ($My_TxPower > 99) {
		$Data .= 99;
	} else {
		$Data .= sprintf("%02u", $My_TxPower);
	}
	$Data .= sprintf("%02u", $My_ColorCode);
	if ($My_Latitude >= 0) {
		if ($My_Latitude >= 10) {
			$Data .= sprintf("%2.5f", abs($My_Latitude));
		} else {
			$Data .= sprintf("%1.6f", abs($My_Latitude));
		}
	} else {
		if ($My_Latitude <= -10) {
			$Data .= "-" . sprintf("%2.4f", abs($My_Latitude));
		} else {
			$Data .= "-" . sprintf("%1.5f", abs($My_Latitude));
		}
	}
	if ($My_Longitude >= 0) {
		if ($My_Longitude >= 100) {
			$Data .= sprintf("%3.5f", abs($My_Longitude));
		} elsif ($My_Longitude < 100 and $My_Longitude >= 10) {
			$Data .= sprintf("%2.6f", abs($My_Longitude));
		} elsif ($My_Longitude < 10) {
			$Data .= sprintf("%1.7f", abs($My_Longitude));
		}
	} else {
		if ($My_Longitude <= -100) {
			$Data .= "-" . sprintf("%3.4f", abs($My_Longitude));
		} elsif ($My_Longitude > -100 and $My_Longitude <= -10) {
			$Data .= "-" . sprintf("%2.5f", abs($My_Longitude));
		} elsif ($My_Longitude > -10) {
			$Data .= "-" . sprintf("%1.6f", abs($My_Longitude));
		}
	}
	if ($My_HeightAGL > 999) {
		$Data .= 999;
	} else {
		$Data .= sprintf("%03d", $My_HeightAGL);
	}
	$Data .= sprintf("%-20.20s", $My_Location);
	$Data .= sprintf("%-19.19s", $My_Description);
	my $Slots = 0;
	if ($My_Freq == $My_RxFreq) {
		$Slots = 4;
	} else {
		$Slots = 1;
	}
	$Data .= $Slots;
	$Data .= sprintf("%-124.124s", $My_URL);
	$Data .= sprintf("%-40.40s", SoftwareID);
	$Data .= sprintf("%-40.40s", PackageID);

#	$Data .= sprintf("%-40.40s", "MMDVM_DMO");
#	$Data .= sprintf("%-40.40s", PackageID);

	$DMR{'Sock'}->send($Data);
	if ($Verbose) {
		print color('green'), "DMR RPTC_Tx Sent, len = " . length($Data) .
			"\n", color('reset');
	}
}

# Options for DMR Plus
sub RPTO_Tx {
	my $Data = "RPTO";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
	} else {
		$Data .= $DMR{'RepeaterID8'};
	}
	$Data .= $DMR{'Options'};
	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print color('green'), "DMR RPTO_Tx Sent, len = " . length($Data) . "\n"; }
}

# This is sent by Client, MMDVM-Host version
sub RPTPING_Tx {
	my $Data = "RPTPING";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
	} else {
		$Data .= $DMR{'RepeaterID8'};
	}
	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print "DMR RPTPING Sent, len = " . length($Data) . "\n"; }
}

# This is sent by Client, DL5DI version
sub MSTPING_Tx {
	my $Data = "MSTPING";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
	} else {
		$Data .= $DMR{'RepeaterID8'};
	}
	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print "DMR MSTPING Sent, len = " . length($Data) . "\n"; }
}

# Close Connection
sub RPTCL_Tx {
	my $Data = "RPTCL";
	if ($DMR{'MMDVM_Host_Mode'}) {
		$Data .= $DMR{'RepeaterID4'};
	} else {
		$Data .= $DMR{'RepeaterID8'};
	}
	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print "DMR RPTCL Sent, len = " . length($Data) . "\n"; }
}

sub DMRD_Rx {
	my ($Buffer) = @_;
	my $StatusByte = ord(substr($Buffer, 16, 1));
	my $Slot;
	if (($StatusByte && 0x01) > 0) {
		$Slot = 2;
	} else {
		$Slot = 1;
	}
	my $IndividualCall;
	if (($StatusByte && 0x02) > 0) {
		$IndividualCall = 1;
	}
	my $VoiceSync;
	if (($StatusByte && 0x04) > 0) {
		$VoiceSync = 1;
	}
	my $DataSync;
	if (($StatusByte && 0x01) > 0) {
		$DataSync = 1;
	}
	my $VoiceSeq = ($StatusByte && 0xF0) / 16;
	#CopyMemory StreamID, ord(substr($Buffer, 17,1)), length($StreamID);
	my $DMRData = ord(substr($Buffer, 21, 33));

}

sub DMRD_Tx {
	my ($SrcID, $DstID, $Slot, $IndividualCall, $VoiceSync, $DataSync, $StreamID, $DMR_Data) = @_;
	my $Data = "DMRD";
	if ($DMR{'SeqNo'} + 1 > 0x100) {
		$DMR{'SeqNo'} = 0;
	} else {
		$DMR{'SeqNo'}++;
	}
	$Data .= $DMR{'SeqNo'};
	$Data .= sprintf("%08.0f", $SrcID);
	$Data .= sprintf("%08.0f", $DstID);
	my $RepeaterIDHex = sprintf("%08X", $DMR{'RepeaterID'});
	$Data .= $RepeaterIDHex;
	$Data .= $Slot;
	my $SignalingByte;
	if ($Slot == 2) { $SignalingByte = 1; }
	if ($IndividualCall) { $SignalingByte = $SignalingByte + 2; }
	if ($VoiceSync) { $SignalingByte = $SignalingByte + 4; }
	if ($DataSync) { $SignalingByte = $SignalingByte + 8; }
# Datatype Missing
	$Data .= sprintf("%08X", $StreamID);
	$Data .= $DMR_Data;

	$DMR{'Sock'}->send($Data);
	if ($Verbose) { print "DMR DMRD_Tx Sent.\n"; }
}

#sub RPTRSSI {
#	my ($Slot, $RSSI) = @_;
#	my $Data = "RPTRSSI" . $DMR{'RepeaterID8'} . ":" . $Slot . "-" . sprintf("%03.1f", $RSSI);;
#	$DMR{'Sock'}->send($Data);
#	if ($Verbose) { print "DMR RPTRSSI RSSI $RSSI Sent.\n"; }
#}

#sub TRMSUB_Tx {
#	my ($TG) = @_;
#	my $Data = "TRMSUB" . $DMR{'RepeaterID8'} . ":TG" . $TG;
#	$DMR{'Sock'}->send($Data);
#	if ($Verbose) { print "DMR TRMSUB TG $TG Sent.\n"; }
#}

#sub TRMUNS_Tx {
#	my ($TG) = @_;
#	my $Data = "TRMUNS" . $DMR{'RepeaterID8'} . ":TG" . $TG;
#	$DMR{'Sock'}->send($Data);
#	if ($Verbose) { print "DMR TRMUNS TG $TG Sent.\n"; }
#}

#sub TRMUNS_All_Tx {
#	my $Data = "TRMUNS" . $DMR{'RepeaterID8'} . "&ALL";
#	$DMR{'Sock'}->send($Data);
#	if ($Verbose) { print "DMR TRMUNS_All Sent.\n"; }
#}






sub RetryTimer {
	if (P25Link::GetTickCount() >= $DMR{'RetryTimer'}{'NextTime'}) {
		if (($DMR{'RetryTimer'}{'Enabled'})) {
			if ($Verbose) { print color('green'),"DMR_RetryTimer event\n", color('reset'); }
			if ($Verbose) { print "State = $DMR{'State'}\n"; }
			switch ($DMR{'State'}) {
				case [Waiting_Connect] {
					if ($DMR{'Sock'} != 0) {
						RPTL_Tx();
						$DMR{'State'} = Waiting_Login;
					}
				}
				case [Waiting_Login] {
					RPTL_Tx();
				}
				case [Waiting_Authorization] {
#					RPTK_Tx();
				}
				case [Waiting_Options] {
#					RPTO_Tx();
				}
				case [Waiting_Config] {
#					RPTC_Tx();
				}
				case [Running] {
					if ($DMR{'MMDVM_Host_Mode'}) {
						RPTPING_Tx();
					} else {
						RPTPING_Tx();
#						MSTPING_Tx();
					}
				} else {

				}
			}
			StartRetryTimer();
#			$DMR{'RetryTimer'}{'NextTime'} = P25Link::GetTickCount() + $DMR{'RetryTimer'}{'Interval'};
			if ($Verbose) {
				print "----------------------------------------------------------------------\n";
			}
		}
	}
}

sub TimeoutTimer {
	if (P25Link::GetTickCount() >= $DMR{'TimeoutTimer'}{'NextTime'}) {
		if (($DMR{'TimeoutTimer'}{'Enabled'})) {
			if ($Verbose) { print color('yellow'), "DMR_TimeoutTimer event\n", color('reset'); }
			print color('yellow'), "DMR, Connection to the master has timed out, retrying connection\n",
				color('reset');
			Close(0);
			DMR_Init();
			$DMR{'State'} = Waiting_Login;
			if ($Verbose) {
				print "----------------------------------------------------------------------\n";
			}
		}
		$DMR{'TimeoutTimer'}{'NextTime'} = P25Link::GetTickCount() + $DMR{'TimeoutTimer'}{'Interval'};
	}
}



sub StartRetryTimer {
	$DMR{'RetryTimer'}{'NextTime'} = P25Link::GetTickCount() + $DMR{'RetryTimer'}{'Interval'};
	$DMR{'RetryTimer'}{'Enabled'} = 1;
}

sub StopRetryTimer {
	$DMR{'RetryTimer'}{'Enabled'} = 0;
}

sub StartTimeoutTimer {
	$DMR{'TimeoutTimer'}{'NextTime'} = P25Link::GetTickCount() + $DMR{'TimeoutTimer'}{'Interval'};
	$DMR{'TimeoutTimer'}{'Enabled'} = 1;
}

sub StopTimeoutTimer {
	$DMR{'TimeoutTimer'}{'Enabled'} = 0;
}


sub Events {
	if ($DMR{'Enabled'}) {
		if ($DMR{'Linked'}) {
			# DMR UDP Receiver
			for my $DMR_fh ($DMR{'Sel'}->can_read($Read_Timeout)) {
				$DMR{'RemoteHost'} = $DMR_fh->recv(my $Buffer, $MaxLen);
				$DMR{'RemoteHost'} = $DMR_fh->peerhost;
				if ($Verbose > 1) { print "  DMR Remote Host = " . $DMR{'RemoteHost'} . "\n"; }
				if ($Verbose > 1) { print "  DMR Receiving...\n"; }
				if (($DMR{'RemoteHost'} cmp $DMR{'LocalHost'}) != 0) {
					#if ($Verbose) {print "$hour:$min:$sec IP = $DMR{'RemoteHost'}" .
					#	" DMR Data len(" . length($Buffer) . ")\n";
					#}
					Rx($Buffer);
				}
			}
		}
		RetryTimer();
		TimeoutTimer();
	}
}

sub Get_RepeaterID4 {
	return $DMR{'RepeaterID4'};

}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}












1;