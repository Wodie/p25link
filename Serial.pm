package Serial;
# Serial.pm

use strict;
use warnings;
use Device::SerialPort;
use Digest::CRC; # For HDLC CRC.
use Time::HiRes qw(nanosleep);
use Term::ANSIColor;



# Needed for FAP:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use Quantar;



my $OS;
my $SerialPort_Configuration;
my $Verbose;
my $SerialPort;
my $Serial_Data = "";



##################################################################
# Serial #########################################################
##################################################################
sub Init {
	my ($ConfigFile) = @_;
	# Detect Target OS.
	$OS = $^O;
	print color('green'), "Current OS is $OS\n", color('reset');
	# Init Serial Port for HDLC.
	print color('green'), "Init Serial Port.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$SerialPort_Configuration = "SerialConfig.cnf";
	$Verbose =$cfg->val('Serial', 'Verbose');
	print "  Serial Verbose = $Verbose\n";

	# For Mac:
	if ($OS eq "darwin") {
		$SerialPort = Device::SerialPort->new('/dev/tty.usbserial') ||
			die "Cannot Init Serial Port : $!\n";
	}
	# For Linux:
	if ($OS eq "linux") {
		$SerialPort = Device::SerialPort->new('/dev/ttyUSB0') ||
			die "Cannot Init Serial Port : $!\n";
	}
	$SerialPort->baudrate(19200);
	$SerialPort->databits(8);
	$SerialPort->parity('none');
	$SerialPort->stopbits(1);
	$SerialPort->handshake('none');
	$SerialPort->buffers(4096, 4096);
	$SerialPort->datatype('raw');
	#$SerialPort->debug(1);
	#$SerialPort->write_settings || undef $SerialPort;
	#$SerialPort->save($SerialPort_Configuration);
	#$TickCount = sprintf("%d", $SerialPort->get_tick_count());
	#$FutureTickCount = $TickCount + 5000;
	#print "  TickCount = $TickCount\n\n";
	print color('yellow'),
		"To use Raspberry Pi UART you need to disable Bluetooth by editing: /boot/config.txt\n" .
		"Add line: dtoverlay=pi3-disable-bt-overlay\n", color('reset'),;
	print "----------------------------------------------------------------------\n";
}

sub Close {
	$SerialPort->close || die "Failed to close SerialPort.\n";
}

sub Read { # Read the serial port, look for 0x7E characters and extract data between them.
	my ($NumChars, $Buffer) = $SerialPort->read(255);
	if ($NumChars >= 1 ){ #Perl data Arrival test.
		#P25Link::Bytes_2_HexString($Buffer);
		for (my $x = 0; $x <= $NumChars; $x++) {
			if (ord(substr($Buffer, $x, 1)) == 0x7E) {
				if (length($Serial_Data) > 0) {
					#Printer($Serial_Data);
					print  color('cyan');
					P25Link::Bytes_2_HexString(Decode_HDLC($Serial_Data));
					print  color('reset');
					Quantar::HDLC_Rx(Decode_HDLC($Serial_Data)); # Process a full data stream.
					#print "Serial Str Data Rx len() = " . length($Serial_Buffer) . "\n";
#if (length$Serial_Buffer >10) {
#	print "Serial Str Data Rx len() = " . length($Serial_Buffer) . "\n";
#	P25Link::Bytes_2_HexString(substr($Serial_Buffer, 0, length($SerialBuffer)));
#}
					$Serial_Data = ""; # Clear Rx buffer.
					#$Buffer = substr($Buffer, $x, length($Buffer) - $x);
					#$x = 0;
				}
				$Serial_Data = ""; # Clear Rx buffer.
			} else {
				# Add Bytes until the end of data stream (0x7E):
				$Serial_Data .= substr($Buffer, $x, 1);
			}
		}
	}
	return "";
}

sub Printer {
	my ($Buffer) = @_;
	print color('blue'),"Serial Str Data Rx len() = " . length($Buffer) . "\n";
	print "Printer:";
	P25Link::Bytes_2_HexString($Buffer);
	print " End\n", color('reset');
}



sub Tx {
	my ($Data) = @_;
	$Data = Encode_HDLC($Data);
	$SerialPort->write($Data . chr(0x7E));
	my $SerialWait = (8.0 / 9600.0) * (length($Data) + 2); # Frame length delay.
	nanosleep($SerialWait * 1000000000.0);
	#if ($Verbose = 2) { print "  nanosleep = $SerialWait\n"; }
}



sub Encode_HDLC {
	my ($Data) = @_;
	my $CRC;
	my $MSB;
	my $LSB;
	#print color('magenta');
	#P25Link::Bytes_2_HexString($Data);
	#print color('reset');

	$CRC = CRC_CCITT_Gen($Data);
	$MSB = int($CRC / 256);
	$LSB = $CRC - $MSB * 256;
	$Data .= chr($MSB) . chr($LSB);
	# Byte Stuff
	$Data =~ s/\}/\}\]/g; # 0x7D to 0x7D 0x5D
	$Data =~ s/\~/\}\^/g; # 0x7E to 0x7D 0x5E
	return($Data);
}

sub Decode_HDLC {
	my ($Buffer) = @_;
	my $Message = "";

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
	P25Link::Bytes_2_HexString($Buffer);


	# CRC CCITT.
	if (length($Buffer) < 2) {
		print color('red'), "*** Warning ***   HDLC_Rx Buffer < 2 Bytes = " . length($Buffer) .
			"\n", color('reset');
		P25Link::Bytes_2_HexString($Message);
		return;
	}
	$Message = substr($Buffer, 0, length($Buffer) - 2);
	#print "Len(Message) = ", length($Message), "\n";
	my $CRC_Rx = 256 * ord(substr($Buffer, length($Buffer) - 2, 1 )) + 
		ord(substr($Buffer, length($Buffer) - 1, 1));
	#print "CRC_Rx  = $CRC_Rx\n";
	if (length($Message) == 0) {
		print color('red'), "*** Warning ***   HDLC_Rx Message is Null.\n", color('reset');
		return;
	}
	my $CRC_Gen = CRC_CCITT_Gen($Message);
	#print "CRC_Gen = $CRC_Gen\n";
	#print "CRCH ", sprintf("0x%x", ord(substr($CRC_Gen, 0, 1))), "\n";
	#print "CRCL ", sprintf("0x%x", ord(substr($CRC_Gen, 1, 1))), "\n";
	#print "Calc CRC16 in hex: ", unpack('H*', pack('S', $Message)), "\n";
	if ($CRC_Rx != $CRC_Gen) {
		print color('red'), "*** Warning ***   HDLC_Rx CRC does not match " . $CRC_Rx . " <> " .
		$CRC_Gen . ".\n", color('reset');
		return;
	}
	return($Message);
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



sub Reset {
	#$serialport->write(chr(0x7D) . chr(0xFF));
	$SerialPort->pulse_rts_on(50);
	print color('yellow'), "HDLC_Tx_Serial_Reset Sent.\n", color('reset');
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;