package APRS_IS;
# APRS_IS.pm

use strict;
use warnings;
use Config::IniFiles;
use Ham::APRS::IS;
use Term::ANSIColor;



# Needed for FAP:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
# Use custom version of FAP:
use FAP;
use P25Link;



my $AppName;
my $Version;
my $My_Latitude;
my $My_Longitude;
my $My_Symbol;
my $My_Altitude;
my $My_Freq;
my $My_Tone;
my $My_Offset;
my $My_NAC;
my $My_Comment;
my $Verbose;
my $Callsign;
my $APRS_IS;
my %APRS_Data;

my %APRS;



##################################################################
# APRS-IS ########################################################
##################################################################
sub Init {
	my ($ConfigFile, $AppNameRef, $VersionRef) = @_;
	$AppName = $AppNameRef;
	$Version = $VersionRef;
	print color('green'), "Loading APRS-IS...\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$APRS{'Enabled'} = $cfg->val('APRS', 'Enabled');
	$APRS{'Passcode'} = $cfg->val('APRS', 'Passcode');
	$APRS{'Suffix'} = $cfg->val('APRS', 'Suffix');
	$APRS{'Server'} = $cfg->val('APRS', 'Server');
	$APRS{'File'} = $cfg->val('APRS', 'APRS_File');
	$APRS{'Refresh_Timer'}{'Interval'} = $cfg->val('APRS', 'APRS_Interval') * 60;
	$APRS{'Refresh_Timer'}{'NextTime'} = P25Link::GetTickCount();
	$APRS{'Refresh_Timer'}{'Enabled'} = 1;
	$My_Latitude = $cfg->val('APRS', 'Latitude');
	$My_Longitude = $cfg->val('APRS', 'Longitude');
	$My_Symbol = $cfg->val('APRS', 'Symbol');
	$My_Altitude = $cfg->val('APRS', 'Altitude');
	$My_Freq = $cfg->val('APRS', 'Frequency');
	$My_Tone = $cfg->val('APRS', 'AccessTone');
	$My_Offset = $cfg->val('APRS', 'Offset');
	$My_NAC = $cfg->val('APRS', 'NAC');
	$My_Comment = $cfg->val('APRS', 'APRSComment');
	$Verbose = $cfg->val('APRS', 'Verbose');
	print "  Enabled = $APRS{'Enabled'}\n";
	print "  Passcode = $APRS{'Passcode'}\n";
	print "  Suffix = $APRS{'Suffix'}\n";
	print "  Server = $APRS{'Server'}\n";
	print "  APRS File $APRS{'File'}\n";
	print "  APRS Interval $APRS{'Refresh_Timer'}{'Interval'}\n";
	print "  Latitude = $My_Latitude\n";
	print "  Longitude = $My_Longitude\n";
	print "  Symbol = $My_Symbol\n";
	print "  Altitude = $My_Altitude\n";
	print "  Freq = $My_Freq\n";
	print "  Tone = $My_Tone\n";
	print "  Offset = $My_Offset\n";
	print "  NAC = $My_NAC\n";
	print "  Comment = $My_Comment\n";
	print "  Verbose = $Verbose\n";

	$Callsign = $cfg->val('MMDVM', 'Callsign');

	if ($APRS{'Passcode'} ne Ham::APRS::IS::aprspass($Callsign)) {
		$APRS{'Server'} = undef;
		$APRS{'Enabled'} = 0;
		warn color('red'), "APRS invalid pasword.\n", color('reset');
	}
	$APRS{'CallsignAndSuffix'} = $Callsign . '-' . $APRS{'Suffix'};
	print "  APRS Callsign = $APRS{'CallsignAndSuffix'}\n";
	if ($APRS{'Enabled'}) {
		$APRS_IS = new Ham::APRS::IS($APRS{'Server'}, $APRS{'CallsignAndSuffix'},
			'appid' => "$AppName $Version",
			'passcode' => $APRS{'Passcode'},
			'filter' => 't/m');
		if (!$APRS_IS) {
			warn color('red'), "Failed to create APRS-IS Server object: " . $APRS_IS->{'error'} .
				"\n", color('reset');
		}
		#Ham::APRS::FAP::debug(1);
	}
	print "----------------------------------------------------------------------\n";
}

sub Connect {
	my $Ret = $APRS_IS->connect('retryuntil' => 2);
	if (!$Ret) {
		warn color('red'), "Failed to connect APRS-IS server: " . $APRS_IS->{'error'} . "\n", color('reset');
		return;
	}
	print "  APRS-IS: connected.\n";
}

sub Disconnect {
	if ($APRS_IS and $APRS_IS->connected()) {
		$APRS_IS->disconnect();
		print color('yellow'), "APRS-IS Disconected.\n", color('reset');
	}
}

sub Refresh_Timer { # APRS-IS
	if (P25Link::GetTickCount() >= $APRS{'Refresh_Timer'}{'NextTime'}) {
		if ($APRS{'Refresh_Timer'}{'Enabled'}) {
			if ($Verbose) { print color('green'), "APRS::Refresh_Timer event\n", color('reset'); }
			if ($APRS_IS) {
				if (!$APRS_IS->connected()) {
					Connect();
				}
				if ( $APRS_IS->connected() ) {
					if ($Verbose) {print color('green'), "APRS-IS Refresh_Timer.\n", color('reset');}
					Update_All(Packets::GetLinkedTalkGroup());
				}
			}
		}
		Start_Refresh_Timer();
	}
}

sub Start_Refresh_Timer {
	$APRS{'Refresh_Timer'}{'NextTime'} = P25Link::GetTickCount() + $APRS{'Refresh_Timer'}{'Interval'};
	$APRS{'Refresh_Timer'}{'Enabled'} = 1;
}

sub Make_Pos {
	my ($Call, $Latitude, $Longitude, $Speed, $Course, $Altitude, $Symbol, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "  APRS-IS does not exist.\n", color('reset'); 
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "  APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		Connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	my %Options;
	$Options{'timestamp'} = 0;
	$Options{'comment'} = 'Hola';
	
	my $APRS_position = Ham::APRS::FAP::make_position(
		$Latitude,
		$Longitude,
		$Speed, # speed
		$Course, # course
		$Altitude, # altitude
		(defined $Symbol) ? $Symbol : '/[', # symbol
		{
		#'compression' => 1,
		#'ambiguity' => 1, # still can not make it work.
		#'timestamp' => time(), # still can not make it work.
		'comment' => $Comment,
		#'dao' => 1
	});
	if ($Verbose > 1) {print color('green'), "  APRS Position is: $APRS_position\n", color('reset');}
	my $Packet = sprintf('%s>APTR01:%s', $Call, $APRS_position . $Comment);
	print color('blue'), "  $Packet\n", color('reset');
	if ($Verbose > 2) {print "  APRS Packet is: $Packet\n";}




	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "Error sending APRS-IS Pos packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	print color('grey12'),"  Make_Pos done for $APRS{'CallsignAndSuffix'}\n", color('reset');
}

sub Make_Object {
	my ($Name, $TimeStamp, $Latitude, $Longitude, $Symbol, $Speed, 
		$Course, $Altitude, $Alive, $UseCompression, $PosAmbiguity, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "  APRS-IS does not exist.\n", color('reset');
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "  APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		Connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}

	my $APRS_object = Ham::APRS::FAP::make_object(
		$Name, # Name
		$TimeStamp,
		$Latitude,
		$Longitude,
		$Symbol, # symbol
		$Speed, # speed
		$Course,
		$Altitude, # altitude
		$Alive,
		$UseCompression,
		$PosAmbiguity,
		$Comment
	);
	if ($Verbose > 0) {print "  APRS Object is: $APRS_object\n";}
	my $Packet = sprintf('%s>APTR01:%s', $APRS{'CallsignAndSuffix'}, $APRS_object);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "*** Error *** sending APRS-IS Object $Name packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	if ($Verbose) { print color('grey12'), "  Make_Object $Name sent.\n", color('reset'); }
}

sub Make_Item {
	my ($Name, $Latitude, $Longitude, $Symbol, $Speed, 
		$Course, $Altitude, $Alive, $UseCompression, $PosAmbiguity, $Comment) = @_;
	if (!$APRS_IS) {
		warn color('red'), "  APRS-IS does not exist.\n", color('reset');
		return;
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "  APRS-IS not connected, trying to reconnect.\n", color('reset'); 
		Connect();
	}
	if (!$APRS_IS->connected()) {
		warn color('red'), "APRS-IS can not connect.\n", color('reset'); 
		return;
	}
	
	my $APRS_item = Ham::APRS::FAP::make_item(
		$Name, # Name
		$Latitude,
		$Longitude,
		$Symbol, # symbol
		$Speed, # speed
		$Course,
		$Altitude, # altitude
		$Alive,
		$UseCompression,
		$PosAmbiguity,
		$Comment
	);
	if ($Verbose > 0) {print "  APRS Item is: $APRS_item\n";}
	my $Packet = sprintf('%s>APTR01:%s', $APRS{'CallsignAndSuffix'}, $APRS_item);
	print color('blue'), "  $Packet\n", color('reset');
	my $Res = $APRS_IS->sendline($Packet);
	if (!$Res) {
		warn color('red'), "*** Error *** sending APRS-IS Item $Name packet $Res\n", color('reset');
		$APRS_IS->disconnect();
		return;
	}
	if ($Verbose) { print color('grey12'), "  Make_Item $Name sent.\n", color('reset'); }
}

sub Update_TG {
	my ($TG) = @_;
	Make_Item(
		$Callsign . '/' . $APRS{'Suffix'},
		$My_Latitude,
		$My_Longitude,
		$My_Symbol,
		-1,
		-1,
		undef,
		1,
		0,
		0,
		$My_Freq . 'MHz ' . $My_Tone . ' ' . $My_Offset . ' NAC-' . $My_NAC . ' ' .
		' TG=' . $TG . ' ' . $My_Comment . ' alt ' . $My_Altitude . 'm');
}

sub Update_All {
	my ($TG) = @_;
	# Station position as Object
	if ($Verbose) { print color('green'), "APRS-IS Update:\n", color('reset'); }
	Make_Item(
		$Callsign . '/' . $APRS{'Suffix'},
		$My_Latitude,
		$My_Longitude,
		$My_Symbol,
		-1,
		-1,
		undef,
		1,
		0,
		0,
		$My_Freq . 'MHz ' . $My_Tone . ' ' . $My_Offset . ' NAC-' . $My_NAC . ' ' .
		' TG=' . $TG . ' ' . $My_Comment . ' alt ' . $My_Altitude . 'm');

	# Objects and Items refresh list loading file.
	my $fh;
	if ($Verbose) { print color('grey12'), "  Loading APRS File...\n", color('reset'); }
	if (!open($fh, "<", $APRS{'File'})) {
		print color('red'), "  *** Error ***   $APRS{'File'} File not found.\n", color('reset');
	} else {
		if ($Verbose) { print color('grey12'), "  File Ok.\n", color('reset'); }
		my %result;
		while (my $Line = <$fh>) {
			chomp $Line;
			## skip comments and blank lines and optional repeat of title line
			next if $Line =~ /^\#/ || $Line =~ /^\s*$/ || $Line =~ /^\+/;
			#split each line into array
			my @Line = split(/\t+/, $Line);
			my $Index = $Line[0];
			$APRS_Data{$Index}{'Name'} = $Line[0];
			$APRS_Data{$Index}{'Type'} = $Line[1];
			$APRS_Data{$Index}{'Lat'} = $Line[2];
			$APRS_Data{$Index}{'Long'} = $Line[3];
			$APRS_Data{$Index}{'Speed'} = $Line[4];
			$APRS_Data{$Index}{'Course'} = $Line[5];
			if ($Line[6] >= 0) {
				$APRS_Data{$Index}{'Altitude'} = $Line[6];
			} else {
				$APRS_Data{$Index}{'Altitude'} = -1;
			}
			$APRS_Data{$Index}{'Alive'} = $Line[7];
			$APRS_Data{$Index}{'Symbol'} = $Line[8];
			$APRS_Data{$Index}{'Comment'} = $Line[9];
			if ($Verbose > 1) {
				print "  APRS Index = $Index";
				print ", Name = $APRS_Data{$Index}{'Name'}";
				print ", Type = $APRS_Data{$Index}{'Type'}";
				print ", Lat = $APRS_Data{$Index}{'Lat'}";
				print ", Long = $APRS_Data{$Index}{'Long'}";
				print ", Speed = $APRS_Data{$Index}{'Speed'}";
				print ", Course = $APRS_Data{$Index}{'Course'}";
				print ", Altitude = $APRS_Data{$Index}{'Altitude'}";
				print ", Alive = $APRS_Data{$Index}{'Alive'}";
				print ", Symbol = $APRS_Data{$Index}{'Symbol'}";
				print ", Comment = $APRS_Data{$Index}{'Comment'}";
				print "\n";
			}
			if ($APRS_Data{$Index}{'Type'} eq 'O') {
				Make_Object(
					$APRS_Data{$Index}{'Name'},
					0, # Timestamp
					$APRS_Data{$Index}{'Lat'},
					$APRS_Data{$Index}{'Long'},
					$APRS_Data{$Index}{'Symbol'},
					$APRS_Data{$Index}{'Speed'},
					$APRS_Data{$Index}{'Course'},
					$APRS_Data{$Index}{'Altitude'},
					$APRS_Data{$Index}{'Alive'},
					0, # Compression 
					0, # Position Ambiguity
					$APRS_Data{$Index}{'Comment'},
				);
			}
			if ($APRS_Data{$Index}{'Type'} eq 'I') {
				Make_Item(
					$APRS_Data{$Index}{'Name'},
					$APRS_Data{$Index}{'Lat'},
					$APRS_Data{$Index}{'Long'},
					$APRS_Data{$Index}{'Symbol'},
					$APRS_Data{$Index}{'Speed'},
					$APRS_Data{$Index}{'Course'},
					$APRS_Data{$Index}{'Altitude'},
					$APRS_Data{$Index}{'Alive'},
					0, # Compression 
					0, # Position Ambiguity
					$APRS_Data{$Index}{'Comment'},
				);
			}



		}
		close $fh;
		if ($Verbose > 2) {
			foreach my $key (keys %APRS)
			{
				print color('green'), "  Key field: $key\n";
				foreach my $key2 (keys %{$APRS_Data{$key}})
				{
					print "  - $key2 = $APRS_Data{$key}{$key2}\n";
				}
				print color('reset');
			}
		}
	}
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;