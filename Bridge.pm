package Bridge;
# Bridge.pm

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



my $STUN_ID;
my $RxPort;
my $TxPort;
my $Verbose = 1;
my $BridgeSocket;
my $Connected = 0;
my $Sel;
my $ClientSocket;
my $ClientAddr;
my $ClientPort;
my $ClientIP;
my $fh;
my $DataIndex = 0;
my @Data = [];



##################################################################
# Bridge #########################################################
##################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init Bridge.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$TxPort = 34100;
	$RxPort = 34103;
	$STUN_ID = sprintf("%x", hex($cfg->val('STUN', 'STUN_ID')));
	$Verbose =$cfg->val('Bridge', 'Verbose');
	print "  TxPort = $TxPort\n";
	print "  RxPort = $RxPort\n";
	print "  Stun ID = 0x$STUN_ID\n";
	print "  Verbose = $Verbose\n";

	if ($STUN_ID < 1 or $STUN_ID >255) {
		die "STUN_ID must be between 1 and 255.\n";
	}

	$BridgeSocket = IO::Socket::IP->new (
#		LocalHost => "127.0.0.1",
		LocalPort => $RxPort,
		Proto => 'udp',
		Blocking => 0,
		Broadcast => 0,
		ReuseAddr => 1,
		PeerHost => "127.0.0.1",
		PeerPort => $TxPort
	) || Sock_Error();

	$Sel = IO::Select->new($BridgeSocket);
	$Connected = 1;
	
	$DataIndex = 0;
	@Data = [];
	print "----------------------------------------------------------------------\n";
}

sub Sock_Error {
	warn color('yellow'), "Can not Bind Quantar Bridge.\n",  color('reset');
}

sub Disconnect {
	$BridgeSocket->close();
	$Connected = 0;
}

sub Tx {
	my ($Buffer) = @_;
	my $STUN_Header = chr(0x08) . chr(0x31) . chr(0x00) . chr(0x00) . chr(0x00) .
		chr(length($Buffer)) . chr($STUN_ID); # STUN Header.
	my $Data = $STUN_Header . $Buffer;
	if ($Connected) {
		$BridgeSocket->send($Data);
		if ($Verbose) { print color('green'), "Bridge_Tx sent:\n", color('reset'); }
		if ($Verbose >= 3) {
			print color('magenta');
			P25Link::Bytes_2_HexString($Data);
			print color('reset');
		}
	}
}



sub Events {
	# Bridge UDP Receiver.
	if ($Connected) {
		for $fh ($Sel->can_read(Read_Timeout)) {
			my $RemoteHost = $fh->recv(my $Buffer, MaxLen);
			if ($Verbose and $RemoteHost) {
				print "RemoteHost = $RemoteHost\n";
			}
			if (length($Buffer) > 7) {
				#my $RemoteHost = $ClientSocket->recv(my $Buffer, $MaxLen);
				if ($Verbose >= 2) {
					print "  Bridge::Events   $RemoteHost STUN Rx Buffer len(" .
						length($Buffer) . ")\n";
				}
				if ($Verbose >= 3) {
					print color('cyan');
					P25Link::Bytes_2_HexString($Buffer);
					#P25Link::Bytes_2_HexString(substr($Buffer, 7, length($Buffer) - 7));
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

sub GetBridge_Connected {
	return $Connected;
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;