package CiscoSTUN;
# CiscoSTUN.pm

use strict;
use warnings;
use Config::IniFiles;
use IO::Socket::IP;
use Term::ANSIColor;



# Needed for FAP:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use Quantar;



use constant MaxLen => 1024; # Max Socket Buffer length.
use constant Read_Timeout => 0.003;



our $STUN_ID;
my $Verbose = 1;
my $ServerSocket;
use constant Port => 1994; # Cisco STUN port is 1994;
my $Connected = 0;
my $Sel;
my $ClientSocket;
my $ClientAddr;
my $ClientPort;
my $ClientIP;
my $DataIndex = 0;
my @Data = [];



##################################################################
# Cisco STUN  ####################################################
##################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init Cisco STUN.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$STUN_ID = sprintf("%x", hex($cfg->val('STUN', 'STUN_ID')));
	$Verbose =$cfg->val('STUN', 'Verbose');
	print "  Stun ID = 0x$STUN_ID\n";
	print "  Verbose = $Verbose\n";

	if ($STUN_ID < 1 or $STUN_ID >255) {
		die "STUN_ID must be between 1 and 255.\n";
	}
	$ServerSocket = IO::Socket::IP->new (
		#LocalHost => '172.31.7.162',
		LocalPort => Port,
		Proto => 'tcp',
		Listen => SOMAXCONN,
		ReuseAddr =>1,
		Blocking => 0
		) || die "  cannot create CiscoUSTUN_ServerSocket $!\n";
	print "  Server waiting for client connection on port " . Port . ".\n";

	# Set timeouts -- may not really be needed
	$ServerSocket->timeout(1);
	#IO::Socket::Timeout->enable_timeouts_on($ServerSocket);
	#$ServerSocket->read_timeout(0.0001);
	#$ServerSocket->write_timeout(0.0001);
	$DataIndex = 0;
	@Data = [];
	print "----------------------------------------------------------------------\n";
}

sub Open {
	if(($ClientSocket, $ClientAddr) = $ServerSocket->accept()) {
		my ($Port, $Client_IP) = sockaddr_in($ClientAddr);
		$ClientIP = inet_ntoa($Client_IP);
		print color('green'),"CiscoSTUN Connected to client " . inet_ntoa($Client_IP) .
			":" . Port . "\n", color('reset');
		$ClientSocket->autoflush(1);
		$Sel = IO::Select->new($ClientSocket);
		$Connected = 1;
		return 1;
	} else {
		print color('yellow'), "CiscoSTUN can not connect.\n", color('reset');
		$Connected = 0;
		return 0;
	}
}

sub Disconnect {
	$ServerSocket->close();
}

sub Tx {
	my ($Buffer) = @_;
	my $STUN_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(length($Buffer)) . chr($STUN_ID); # STUN Header.
	my $Data = $STUN_Header . $Buffer;
	if ($Connected) {
		$ClientSocket->send($Data);
		if ($Verbose) { print color('green'), "STUN_Tx sent:\n", color('reset');}
		if ($Verbose >= 3) {
			print color('magenta');
			P25Link::Bytes_2_HexString($Data);
			print color('reset');
		}
	}
}


sub Events {
	# Cisco STUN TCP Receiver.
	if ($Connected == 1) {
		for my $fh ($Sel->can_read(Read_Timeout)) {
			my $RemoteHost = $fh->recv(my $Buffer, MaxLen);
			if ($Verbose and $RemoteHost) {
				print "RemoteHost = $RemoteHost\n";
			}
			if (length($Buffer) > 7) {
				#my $RemoteHost = $SClientSocket->recv(my $Buffer, $MaxLen);
				if ($Verbose >= 2) {
					print "  $RemoteHost STUN Rx Buffer len(" . length($Buffer) . ")\n";
				}
				if ($Verbose >= 3) {
					print color('cyan');
					P25Link::Bytes_2_HexString(substr($Buffer, 7, length($Buffer) - 7));
					print color('reset');
				}
				Quantar::HDLC_Rx(substr($Buffer, 7, length($Buffer) - 7));
			}
		}
	}
}



sub GetSTUN_ID {
	return($STUN_ID);
}

sub GetSTUN_Connected {
	return $Connected;
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;