package Recorder;
# Recorder.pm

use strict;
use warnings;
use Config::IniFiles;
use Term::ANSIColor;



my $Record_Enabled;
my $RecordFile;
my $Verbose;
my $Recfh;



#################################################################################
# Recorder ######################################################################
#################################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init data recorder...\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$Record_Enabled = $cfg->val('Settings', 'RecordEnable');
	$RecordFile = $cfg->val('Settings', 'RecordFile');
	$Verbose =$cfg->val('HDLC', 'Verbose');
	print "  Record_Enabled = $Record_Enabled\n";
	print "  File Name = $RecordFile\n";
	open $Recfh, ">", $RecordFile || die "Can't open the recording file: $!";
	print "----------------------------------------------------------------------\n";
}

sub RecorderBytes_2_HexString {
	my ($Buffer) = @_;
	if ($Record_Enabled == 1) { # Audio recoreder
		# Display Rx Hex String.
		#print "HDLC_Rx Buffer:              ";
		my $x = 0;
		print $Recfh sprintf("byte = 0x02%X", ord(substr($Buffer, $x, 1)));
		if ($Verbose eq 'R') { print sprintf("byte = 0x%02X", ord(substr($Buffer, $x, 1)));}
		for (my $x = 1; $x < length($Buffer); $x++) {
			print $Recfh sprintf(", 0x%02X", ord(substr($Buffer, $x, 1)));
			if ($Verbose eq 'R') {print sprintf(", 0x%02X", ord(substr($Buffer, $x, 1)));}
		}
		print $Recfh "\n";
		if ($Verbose eq 'R') {print "\n";}
	}
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;