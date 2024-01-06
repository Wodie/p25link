package Quantar;
# Quantar.pm

use strict;
use warnings;
use Switch;
use Config::IniFiles;
use Term::ANSIColor;



# Custom files:
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;
#use Packets;



#my $CiscoDebug = 1;



# ICW (Infrastructure Control Word).
# Byte 1 address.
# Bte 2 frame type.
use constant C_RR => 0x41;
use constant C_UI => 0x03;
use constant C_SABM => 0x3F;
use constant C_XID => 0xBF;
# Byte 3.
#0x60 thru 0x73, etc
use constant C_RN_Page => 0xA1;
# Byte 4.
# Byte 5 RT mode flag.
use constant C_RTRT_Enabled => 0x02;
use constant C_RTRT_Disabled => 0x04;
use constant C_RTRT_DCRMode => 0x05;
# Byte 6 Op Code Start/Stop flag.
use constant C_ChangeChannel => 0x06;
use constant C_StartTx => 0x0C;
use constant C_EndTx => 0x25;
# Byte 7 OpArg, type flag.
use constant C_AVoice => 0x00;
use constant C_TMS_Data_Payload => 0x06;
use constant C_DVoice => 0x0B;
use constant C_TMS_Data => 0x0C;
use constant C_From_Comparator_Start => 0x0D;
use constant C_From_Comparator_Stop => 0x0E;
use constant C_Page => 0x0F;
# Byte 8 ICW flag.
use constant C_DIU3000 => 0x00;
use constant C_Quantar => 0xC2;
use constant C_QuantarAlt => 0x1B;
# Byte 9 LDU1 RSSI.
# Byte 10 1A flag.
use constant C_RSSI_Is_Valid => 0x1A;
# Byte 11 LDU1 RSSI.
#
# Byte 12.
use constant C_Normal_Page => 0x9F;
use constant C_Emergency_Page => 0xA7;

# Byte 13 Page.
use constant C_Individual_Page => 0x00;
use constant C_Group_Page => 0x90;
#
use constant C_SystemCallTG => 0xFFFF;



our $HDLC_RTRT_Enabled;
our $HDLC_ATAC_Enabled;
my $Verbose;
my %Quant;
use constant C_Implicit_MFID => 0;
use constant C_Explicit_MFID => 1;
my $SuperframeCounter = 0;
my %HDLC;
my $HDLC_Handshake = 0;
my $SABM_Counter = 0;
my $StationType = 0;

my $SuperFrameCounter = 0;
my $HDLC_TxTraffic = 0;
my $LocalRx_Time;

my $NewTG  = 0;
my $RptEnabled = 1;



##################################################################
# Qunatar ########################################################
##################################################################
sub Init {
	my ($ConfigFile) = @_;
	print color('green'), "Init HDLC.\n", color('reset');
	my $cfg = Config::IniFiles->new( -file => $ConfigFile);
	$HDLC_RTRT_Enabled = $cfg->val('HDLC', 'RTRT_Enabled');
	$HDLC_ATAC_Enabled = $cfg->val('HDLC', 'ATAC_Enabled');
	$Verbose =$cfg->val('HDLC', 'Verbose');
	print "  RT/RT Enabled = $HDLC_RTRT_Enabled\n";
	print "  ATAC Enabled = $HDLC_ATAC_Enabled\n";
	print "  Verbose = $Verbose\n";

	$Quant{'FrameType'} = 0;
	$Quant{'LocalRx'} = 0;
	$Quant{'LocalRx_Time'} = 0;
	$Quant{'IsDigitalVoice'} = 1;
	$Quant{'IsPage'} = 0;
	$Quant{'dBm'} = 0;
	$Quant{'RSSI'} = 0;
	$Quant{'RSSI_Is_Valid'} = 0;
	$Quant{'InvertedSignal'} = 0;
	$Quant{'CandidateAdjustedMM'} = 0;
	$Quant{'BER'} = 0;
	$Quant{'SourceDev'} = 0;
	$Quant{'Encrypted'} = 0;
	$Quant{'Explicit'} = 0;
	$Quant{'IndividualCall'} = 0;
	$Quant{'ManufacturerID'} = 0;
	$Quant{'ManufacturerName'} = "";
	$Quant{'Emergency'} = 0;
	$Quant{'Protected'} = 0;
	$Quant{'FullDuplex'} = 0;
	$Quant{'PacketMode'} = 0;
	$Quant{'Priority'} = 0;
	$Quant{'IsTGData'} = 0;
	$Quant{'AstroTalkGroup'} = 0;
	$Quant{'DestinationRadioID'} = 0;
	$Quant{'SourceRadioID'} = 0;
	$Quant{'LSD'} = [0, 0, 0, 0];
	$Quant{'LSD0'} = 0;
	$Quant{'LSD1'} = 0;
	$Quant{'LSD2'} = 0;
	$Quant{'LSD3'} = 0;
	$Quant{'EncryptionI'} = 0;
	$Quant{'EncryptionII'} = 0;
	$Quant{'EncryptionIII'} = 0;
	$Quant{'EncryptionIV'} = 0;
	$Quant{'Algorythm'} = 0;
	$Quant{'AlgoName'} = "";
	$Quant{'KeyID'} = 0;
	$Quant{'Speech'} = "";
	$Quant{'Raw0x60'} = "";
	$Quant{'Raw0x61'} = "";
	$Quant{'Raw0x62'} = "";
	$Quant{'Raw0x63'} = "";
	$Quant{'Raw0x64'} = "";
	$Quant{'Raw0x65'} = "";
	$Quant{'Raw0x66'} = "";
	$Quant{'Raw0x67'} = "";
	$Quant{'Raw0x68'} = "";
	$Quant{'Raw0x69'} = "";
	$Quant{'Raw0x6A'} = "";
	$Quant{'Raw0x6B'} = "";
	$Quant{'Raw0x6C'} = "";
	$Quant{'Raw0x6D'} = "";
	$Quant{'Raw0x6E'} = "";
	$Quant{'Raw0x6F'} = "";
	$Quant{'Raw0x70'} = "";
	$Quant{'Raw0x71'} = "";
	$Quant{'Raw0x72'} = "";
	$Quant{'Raw0x73'} = "";
	$Quant{'IMBEFrame'} = "";
	$Quant{'Tail'} = 0;
	$Quant{'PrevFrame'} = "";

	$Quant{'Prev_UI'} = "";

	$HDLC{'RR_Timer'}{'Enabled'} = 0;
	$HDLC{'RR_Timer'}{'Interval'} = 4; # Seconds.
	$HDLC{'RR_Timer'}{'NextTime'} = 0;
	$HDLC{'Connection_WD_Timer'}{'Enabled'} = 1;
	$HDLC{'Connection_WD_Timer'}{'Interval'} = 10; # Seconds.
	$HDLC{'Connection_WD_Timer'}{'NextTime'} = P25Link::GetTickCount();
	$HDLC{'SABM_Timer'}{'Enabled'} = 1;
	$HDLC{'SABM_Timer'}{'Interval'} = 0.5; # Seconds.
	$HDLC{'SABM_Timer'}{'NextTime'} = 0;
	print "----------------------------------------------------------------------\n";
}



##################################################################
# HDLC ###########################################################
##################################################################
sub HDLC_Rx {
	my ($Message, $RemoteHostIP) = @_;
	my $RTRTOn;
	my $OpCode;
	my $OpArg;
	my $SiteID;
	my $IsChannelChange;
	my $Channel;
	my $IsStart;
	my $IsEnd;

	if ($Verbose) {
		print color('green'), "HDLC_Rx Message.\n", color('reset');
	}
	if ($Verbose >= 2) {
		P25Link::Bytes_2_HexString($Message);
	}
	Recorder::RecorderBytes_2_HexString($Message);
	# 01 Address
	my $Address = ord(substr($Message, 0, 1));
	#print "Address = ", sprintf("0x%x", $Address), "\n";
	#P25Link::Bytes_2_HexString($Message);

	$Quant{'FrameType'} = ord(substr($Message, 1, 1));
	#print "Frame Types = ", sprintf("0x%x", $Quant{'FrameType'}), "\n";
	switch ($Quant{'FrameType'}) {
		case 0x01 { # RR Receive Ready.
			if ($Address == 0xFD) { # 253
				Start_Connection_WD_Timer(); # Reset HDLC connection timer.
			} else {
				print color('red'), "*** Warning ***   HDLC_Rx RR Address 0xFD (253) != $Address\n",
					color('reset');
			}
			return;
		}
		case 0x03 { # User Information.
			#print "Case 0x03 UI.", substr($Message, 2, 1), "\n";
			#P25Link::Bytes_2_HexString($Message);
			$Quant{'LocalRx'} = 1;
			$Quant{'LocalRx_Time'} = P25Link::GetTickCount();
			switch (ord(substr($Message, 2, 1))) {
				case 0x00 { #Network ID, NID Start/Stop.
					if ($Verbose) {
						print "UI 0x00 NID Start/Stop";
					}
					if (ord(substr($Message, 3, 1)) != 0x02) {warn "Debug this with the XML.\n"; }
					if (ord(substr($Message, 4, 1)) == C_RTRT_Enabled) {
						$RTRTOn = 1;
						if ($Verbose) {
							print ", RT/RT Enabled";
						}
					}
					if (ord(substr($Message, 4, 1)) == C_RTRT_Disabled) {
						$RTRTOn = 0;
						if ($Verbose) {
							print ", RT/RT Disabled";
						}
					}
					$OpCode = ord(substr($Message, 5, 1));
					$OpArg = ord(substr($Message, 6, 1));
					switch ($OpCode) {
						case 0x06 { # ChannelChange
							$IsChannelChange = 1;
							$Channel = $OpArg;
							#if ($Verbose) {
								print "  HDLC Channel change to $Channel\n";
							#}
						}
						case 0x0C { # StartTx
							$IsStart = 1;
							if ($Verbose) {
								print "  HDLC ICW Start";
							}
						}
						case 0x0D {
							if ($Verbose) {
								print "  HDLC DIU Monitor";
							}
						}
						case 0x25 { # StopTx
							$IsEnd = 1;
							if ($Verbose) {
								print "  HDLC ICW Terminate";
							}
							$Quant{'LocalRx'} = 0;
							$Quant{'LocalTx'} = 0;
							if ($Quant{'Tail'} == 1) {
								$Packets::Pending_CourtesyTone = 1;
								$Quant{'Tail'} = 0;
								print "  HDLC Stop 0x25 Tail Rx\n";
								if ($Verbose) { P25Link::Bytes_2_HexString($Message) };
							} else {
								print "  HDLC Stop 0x25 Tail Rx (dupe).\n";
								if ($Verbose) { P25Link::Bytes_2_HexString($Message) };
							}
						}
					}
					if ($Verbose) {
						print ", Linked Talk Group " . Packets::GetLinkedTalkGroup() . "\n";
					}
					switch ($OpArg) {
						case 0x00 { # AVoice
							if ($Verbose) { print ", Analog Voice\n"; }
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 0;
						}
						case 0x06 { # TMS Data Payload
							if ($Verbose) {
								print ", TMS Data Payload\n";
								P25Link::Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							Packets::Tx_to_Network($Message);
						}
						case 0x0B { # DVoice
							if ($Verbose) { print ", Digital Voice\n"; }
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
							Packets::Tx_to_Network($Message);
						}
						case 0x0C { # TMS
							if ($Verbose) {
								print ", TMS\n";
								P25Link::Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							Packets::Tx_to_Network($Message);
						}
						case 0x0D { # From Comparator Start
							if ($Verbose) {
								print ", From Comparator Start\n";
								P25Link::Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							#AddToSuperFrame(0x0D, $Message);
							#Packets::Tx_to_Network($Message);
						}
						case 0x0E { # From Comprator Stop
							if ($Verbose) {
								print ", From Comparator Stop\n";
								P25Link::Bytes_2_HexString($Message);
							}
							print "----------------------------------------------------------------------\n";
							#AddToSuperFrame(0x0E, $Message);
							#Packets::Tx_to_Network($Message);
						}
						case 0x0F { # Page
							if ($Verbose) { print ", Page\n"; }
							$Quant{'IsPage'} = 1;
							Packets::Tx_to_Network($Message);
						}
					}
					if ($Verbose) {
						print "\n";
					}
					RDAC::Tx(Packets::GetLinkedTalkGroup(), $Quant{'LocalRx'}, $Quant{'LocalTx'},
						$Quant{'IsDigitalVoice'}, $Quant{'IsPage'}, $StationType);
				}
				case 0x01 {
					warn color('yellow'), "UI 0x01 Undefined.\n", color('reset');
				}
				case 0x59 {
					warn color('yellow'), "UI 0x59 Undefined.\n", color('reset');
					return;
				}
				case 0x60 {
					if ($Verbose) { print "UI 0x60 Voice Header part 1.\n"; }
					if ($Verbose >= 2) {P25Link::Bytes_2_HexString($Message); }
					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RTRT_Enabled
							$RTRTOn = 1;
							if ($Verbose) { print "RT/RT Enabled"; }
						}
						case 0x04 { # RTRT_Disabled
							$RTRTOn = 0;
							if ($Verbose) { print "RT/RT Disabled"; }
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x00 { # AVoice
							if ($Verbose) { print ", Analog Voice"; }
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 0;
						}
						case 0x0B { # DVoice
							if ($Verbose) { print ", Digital Voice"; }
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
						}
						case 0x0F { # Page
							if ($Verbose) { print ", Page"; }
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 1;
						}
					}
					$SiteID = ord(substr($Message,7 ,1));
					$StationType = $SiteID; # Informative for RDAC.
					switch ($SiteID) {
						case C_DIU3000 { # DIU3000
							if ($Verbose) { print ", Source: DIU 3000 or ATAC"; }
						}
						case C_Quantar { # Quantar
							if ($Verbose) { print ", Source: Quantar"; }
						}
					}
					if (ord(substr($Message, 9, 1)) == 1) {
						$Quant{'RSSI_Is_Valid'} = 1;
						$Quant{'RSSI'} = ord(substr($Message, 8, 1));
						$Quant{'InvertedSignal'} = ord(substr($Message, 10, 1));
						if ($Verbose) {
							print ", RSSI = $Quant{'RSSI'}\n";
							print ", Inverted signal = $Quant{'InvertedSignal'}\n";
						}
					} else {
						$Quant{'RSSI_Is_Valid'} = 0;
						if ($Verbose) { print ".\n"; }
					}
					if ( ($Quant{'IsDigitalVoice'} == 1) or ($Quant{'IsPage'} == 1) ) {
						$Quant{'Raw0x60'} = $Message;
						Packets::Tx_to_Network($Message);
					}
				}

				case 0x61 {
					if ($Verbose) {
						print "UI 0x61 Voice Header part 2.\n";
						if ($Quant{'Prev_UI'} != 0x60) {
							print color('red'), "HDLC Rx UI 0x60 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));
					
					if ($Verbose >= 2) {P25Link::Bytes_2_HexString($Message); }
					#my $TGID = 256 * ord(substr($Message, 4, 1)) + ord(substr($Message, 3, 1));;
					#warn "Not true TalkGroup ID = $TGID\n";
					if ( ($Quant{'IsDigitalVoice'} == 1) or ($Quant{'IsPage'} == 1) ) {
						$Quant{'Raw0x61'} = $Message;
						Packets::Tx_to_Network($Message);
					}
				}

				case 0x62 { # dBm, RSSI, BER.
					if ($Verbose) {
						print "UI 0x62 IMBE Voice part 1.\n";
						if ($Quant{'Prev_UI'} != 0x61 or $Quant{'Prev_UI'} != 0x73) {
							print color('red'), "HDLC Rx UI 0x61 or 0x73 Voice Header missing.\n",
								color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RT/RT Enable
							$RTRTOn = 1;
							if ($Verbose) { print "RT/RT Enabled"; }
						}
						case 0x04 { # RT/RT Disable
							$RTRTOn = 0;
							if ($Verbose) { print "RT/RT Disabled"; }
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x0B { # DVoice
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
							if ($Verbose) { print ", Digital Voice"; }
						}
						case 0x0F { # Page
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 1;
							if ($Verbose) { print ", Page"; }
						}
					}
					$SiteID = ord(substr($Message, 7, 1));
					$StationType = $SiteID; # Informative for RDAC.
					switch ($SiteID) {
						case C_DIU3000 { # DIU3000
							if ($Verbose) { print ", SiteID: DIU 3000 or ATAC"; }
						}
						case C_Quantar { # Quantar
							if ($Verbose) { print ", SiteID: Quantar"; }
						}
					}
					if (ord(substr($Message, 9, 1))) {
						$Quant{'RSSI_Is_Valid'} = 1;
						$Quant{'RSSI'} = ord(substr($Message, 8, 1));
						$Quant{'InvertedSignal'} = ord(substr($Message, 10, 1));
						$Quant{'CandidateAdjustedMM'} = ord(substr($Message, 11, 1));
						if ($Verbose) {
							print ", RSSI = $Quant{'RSSI'}";
							print ", Inverted signal = $Quant{'InvertedSignal'}";
						}
					} else {
						$Quant{'RSSI_Is_Valid'} = 0;
					}
					if ($Verbose) { print "\n"; }
					$Quant{'Speech'} = ord(substr($Message, 12, 11));
					$Quant{'Raw0x62'} = $Message;
					$Quant{'IMBEFrame'} = $Quant{'Speech'};
					$Quant{'SourceDev'} = ord(substr($Message, 23, 1));
					Packets::Tx_to_Network($Message);
				}
				case 0x63 {
					if ($Verbose) {
						print "UI 0x63 IMBE Voice part 2.\n";
						if ($Quant{'Prev_UI'} != 0x62) {
							print color('red'), "HDLC Rx UI 0x62 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 3, 11));
					$Quant{'Raw0x63'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					$Quant{'SourceDev'} = ord(substr($Message, 14, 1));
					Packets::Tx_to_Network($Message);
				}
				case 0x64 { # Group/Direct Call, Clear/Private.
					if ($Verbose) {
						print "UI 0x64 IMBE Voice part 3 + link control.\n";
						if ($Quant{'Prev_UI'} != 0x63) {
							print color('red'), "HDLC Rx UI 0x63 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					if (ord(substr($Message, 3, 1)) & 0x80) {
						$Quant{'Encrypted'} = 1;
					}
					if (ord(substr($Message, 3, 1))& 0x40) {
						$Quant{'Explicit'} = 1;
					}
					$Quant{'IsTGData'} = 0;
					CallType(ord(substr($Message, 3, 1)));
					$Quant{'ManufacturerID'} = ord(substr($Message, 4, 1));
					ManufacturerName ($Quant{'ManufacturerID'});
					if (ord(substr($Message, 5, 1)) and 0x80) {
						$Quant{'Emergency'} = 1;
					} else {
						$Quant{'Emergency'} = 0;
					}
					if (ord(substr($Message, 5, 1)) and 0x40) {
						$Quant{'Protected'} = 1;
					} else {
						$Quant{'Protected'} = 0;
					}
					if (ord(substr($Message, 5, 1)) and 0x20) {
						$Quant{'FullDuplex'} = 1;
					} else {
						$Quant{'FullDuplex'} = 0;
					}
					if (ord(substr($Message, 5, 1)) and 0x10) {
						$Quant{'PacketMode'} = 1;
					} else {
						$Quant{'PacketMode'} = 0;
					}
					$Quant{'Priority'} = ord(substr($Message, 5, 1));
					#switch (ord(substr($Message, 6, 1))) {
					#	case Implicit_MFID {
					#
					#	}
					#	case Explicit_MFID {
					#
					#	}
					#}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					$Quant{'Raw0x64'} = $Message;
					Packets::Tx_to_Network($Message);
				}
				case 0x65 { # Talk Group.
					if ($Verbose) {
						print "UI 0x65 IMBE Voice part 4 + link control.\n";
						if ($Quant{'Prev_UI'} != 0x64) {
							print color('red'), "HDLC Rx UI 0x64 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					#P25Link::Bytes_2_HexString($Message);
					if ($Quant{'IsTGData'} == 1) {
						my $MMSB = ord(substr($Message, 3, 1));
						my $MSB = ord(substr($Message, 4, 1));
						my $LSB = ord(substr($Message, 5, 1));
						$Quant{'AstroTalkGroup'} = ($MSB << 8) | $LSB;
						$Quant{'DestinationRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

						# Leave previous line empty.
						if ($Quant{'IndividualCall'}) {
							if ($Verbose) {
								print "Destination ID = $Quant{'DestinationID'}\n";
							}
						} else {
							if ($Verbose) {
								print "AstroTalkGroup = $Quant{'AstroTalkGroup'}\n";
							}
							Packets::AddLinkTG($Quant{'AstroTalkGroup'}, 1);
						}
					}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x65'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x66 { # Source ID.
					if ($Verbose) {
						print "UI 0x66 IMBE Voice part 5. + link control.\n";
						if ($Quant{'Prev_UI'} != 0x65) {
							print color('red'), "HDLC Rx UI 0x65 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					# Get Called ID.
					if ($Quant{'IsTGData'}) {
						my $MMSB = ord(substr($Message, 3, 1));
						my $MSB = ord(substr($Message, 4, 1));
						my $LSB = ord(substr($Message, 5, 1));
						$Quant{'SourceRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

						# Leave previous line empty.
						if ($Verbose) {
							print "HDLC SourceRadioID = $Quant{'SourceRadioID'}\n";
						}
						#QSO_Log($RemoteHostIP);
					} else {
						if ($Verbose) {warn "Misterious packet 0x66\n"; }
					}
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x66'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x67 { # TBD
					if ($Verbose) {
						print "UI 0x67 IMBE Voice part 6 + link control.\n";
						if ($Quant{'Prev_UI'} != 0x66) {
							print color('red'), "HDLC Rx UI 0x66 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x67'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x68 {
					if ($Verbose) {
						print "UI 0x68 IMBE Voice part 7 + link control.\n";
						if ($Quant{'Prev_UI'} != 0x67) {
							print color('red'), "HDLC Rx UI 0x67 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x68'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x69 {
					if ($Verbose) {
						print "UI 0x69 IMBE Voice part 8 + link control.\n";
						if ($Quant{'Prev_UI'} != 0x68) {
							print color('red'), "HDLC Rx UI 0x68 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x69'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x6A { # Low speed data Byte 1.
					if ($Verbose) {
						print "UI 0x6A IMBE Voice part 9 + low speed data 1.\n";
						if ($Quant{'Prev_UI'} != 0x69) {
							print color('red'), "HDLC Rx UI 0x69 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'LSD0'} = ord(substr($Message, 4, 1));
					$Quant{'LSD1'} = ord(substr($Message, 5, 1));
					$Quant{'Speech'} = ord(substr($Message, 6, 11));
					$Quant{'Raw0x6A'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					$Quant{'Tail'} = 1;
					Packets::Tx_to_Network($Message);
				}
				case 0x6B { # dBm, RSSI, BER.
					if ($Verbose) {
						print "UI 0x6B IMBE Voice part 10.\n";
						if ($Quant{'Prev_UI'} != 0x6A) {
							print color('red'), "HDLC Rx UI 0x6A Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					switch (ord(substr($Message, 4, 1))) {
						case 0x02 { # RT/RT Enable
							$RTRTOn = 1;
							if ($Verbose) { print "RT/RT Enabled"; }
						}
						case 0x04 { # RT/RT Disable
							$RTRTOn = 0;
							if ($Verbose) { print "RT/RT Disabled"; }
						}
					}
					switch (ord(substr($Message, 6, 1))) {
						case 0x0B { # DVoice
							$Quant{'IsDigitalVoice'} = 1;
							$Quant{'IsPage'} = 0;
							if ($Verbose) { print ", Digital Voice"; }
						}
						case 0x0F { # Page
							$Quant{'IsDigitalVoice'} = 0;
							$Quant{'IsPage'} = 1;
							if ($Verbose) { print ", Page"; }
						}
					}
					$SiteID = ord(substr($Message, 7, 1));
					$StationType = $SiteID; # Informative for RDAC.
					switch ($SiteID) {
						case C_DIU3000 { # DIU3000
							if ($Verbose) { print ", SiteID: DIU 3000 or ATAC"; }
						}
						case C_Quantar { # Quantar
							if ($Verbose) { print ", SiteID: Quantar"; }
						}
					}
					$Quant{'RSSI'} = ord(substr($Message, 8, 1));
					if (ord(substr($Message, 9, 1))) {
						$Quant{'RSSI_Is_Valid'} = 1;
						if ($Verbose) {
							print ", RSSI = $Quant{'RSSI'}";
							print ", Inverted signal = $Quant{'InvertedSignal'}";
						}
					} else {
						$Quant{'RSSI_Is_Valid'} = 0;
					}
					if ($Verbose) { print "\n"; }
					$Quant{'InvertedSignal'} = ord(substr($Message, 10, 1));
					$Quant{'CandidateAdjustedMM'} = ord(substr($Message, 11, 1));
					$Quant{'Speech'} = ord(substr($Message, 12, 11));
					$Quant{'Raw0x6B'} = $Message;
					$Quant{'SourceDev'} = ord(substr($Message, 23, 1));
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x6C {
					if ($Verbose) {
						print "UI 0x6C IMBE Voice part 11.\n";
						if ($Quant{'Prev_UI'} != 0x6B) {
							print color('red'), "HDLC Rx UI 0x6B Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 3, 11));
					$Quant{'Raw0x6C'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x6D {
					if ($Verbose) {
						print "UI 0x6D IMBE Voice part 12 + encryption sync.\n";
						if ($Quant{'Prev_UI'} != 0x6C) {
							print color('red'), "HDLC Rx UI 0x6C Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'EncryptionI'} = ord(substr($Message, 3, 4));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x6D'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x6E {
					if ($Verbose) {
						print "UI 0x6E IMBE Voice part 13 + encryption sync.\n";
						if ($Quant{'Prev_UI'} != 0x6D) {
							print color('red'), "HDLC Rx UI 0x6D Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'EncryptionII'} = ord(substr($Message, 3,4));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x6E'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x6F {
					if ($Verbose) {
						print "UI 0x6F IMBE Voice part 14 + encryption sync.\n";
						if ($Quant{'Prev_UI'} != 0x6E) {
							print color('red'), "HDLC Rx UI 0x6E Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'EncryptionIII'} = ord(substr($Message, 3,4));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x6F'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x70 { # Algorithm.
					if ($Verbose) {
						print "UI 0x70 IMBE Voice part 15 + encryption sync.\n";
						if ($Quant{'Prev_UI'} != 0x6F) {
							print color('red'), "HDLC Rx UI 0x6F Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Algorythm'} = ord(substr($Message, 3,1));
					AlgoName ($Quant{'Algorythm'});
					$Quant{'KeyID'} = ord(substr($Message, 4,2));
					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x70'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x71 {
					if ($Verbose) {
						print "UI 0x71 IMBE Voice part 16 + encryption sync.\n";
						if ($Quant{'Prev_UI'} != 0x70) {
							print color('red'), "HDLC Rx UI 0x70 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x71'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x72 {
					if ($Verbose) {
						print "UI 0x72 IMBE Voice part 17 + encryption sync.\n";
						if ($Quant{'Prev_UI'} != 0x71) {
							print color('red'), "HDLC Rx UI 0x71 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'Speech'} = ord(substr($Message, 7, 11));
					$Quant{'Raw0x72'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					Packets::Tx_to_Network($Message);
				}
				case 0x73 { # Low speed data Byte 2.
					if ($Verbose) {
						print "UI 0x73 IMBE Voice part 18 + low speed data 2.\n";
						if ($Quant{'Prev_UI'} != 0x72) {
							print color('red'), "HDLC Rx UI 0x72 Voice Header missing.\n", color('reset');
						}
					}
					$Quant{'Prev_UI'} = ord(substr($Message, 2, 1));

					$Quant{'LSD2'} = ord(substr($Message, 4, 1));
					$Quant{'LSD3'} = ord(substr($Message, 5, 1));
					$Quant{'Speech'} = ord(substr($Message, 6, 11));
					$Quant{'Raw0x73'} = $Message;
					$Quant{'IMBEFrame'} .= $Quant{'Speech'};
					$Quant{'Tail'} = 1;
					Packets::Tx_to_Network($Message);
				}
				case 0x80 {
					print color('yellow'), "UI 0x80.\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
					#print "Raw " . substr($Message, 1, length($Message)) . '\n';
					#my $MMSB = ord(substr($Message, 51, 1));
					#my $MSB = ord(substr($Message, 52, 1));
					#my $LSB = ord(substr($Message, 53, 1));
					#my $SourceID = ($MMSB << 16) | ($MSB << 8) | $LSB;
					#print "SourceID $SourceID\n";
				}
				case 0x85 {
					print color('yellow'), "UI 0x85.\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
					#print "Raw " . substr($Message, 1, length($Message)) . '\n';
					#print "Alias " . substr($Message, 11, 4) . substr($Message, 16, 4) . '\n';
				}
				case 0x87 {
					print color('yellow'), "UI 0x87.\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0x88 {
					print color('yellow'), "UI 0x88.\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0x8D {
					print color('yellow'), "UI 0x8D.\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0x8F {
					print color('yellow'), "UI 0x8F.\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
				case 0xA1 { # Page affliate request.
					print color('yellow'), "UI 0xA1 Page call.\n", color('reset');
					my $MMSB = ord(substr($Message, 15, 1));
					my $MSB = ord(substr($Message, 16, 1));
					my $LSB = ord(substr($Message, 17, 1));
					$Quant{'DestinationRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

					# Leave previous line empty.
					$MMSB = ord(substr($Message, 18, 1));
					$MSB = ord(substr($Message, 19, 1));
					$LSB = ord(substr($Message, 20, 1));
					$Quant{'SourceRadioID'} = ($MMSB << 16) | ($MSB << 8) | $LSB;

					# Leave previous line empty.
					print color('yellow'), "  Source $Quant{'SourceRadioID'}" .
						", Dest $Quant{'DestinationRadioID'}", color('reset');
					my $Flag = ord(substr($Message, 11, 1));
					switch ($Flag) {
						case 0x98 { # STS
							print " Flag = STS\n";
							#$StatusIndex = ord(substr(Message, 13, 1));
						}
						case 0x9F { # Page
							print " Flag = Page\n";
						}
						case 0xA0 { # Page Ack.
							print " Flag = Page Ack\n";
							#if ($Quant{'DestinationRadioID'} == $MasterRadioID) {Then
								#PageAck_Tx $Quant{'SourceRadioID'},
								#$Quant{'DestinationRadioID'}, 1;
							#}
						}
						case 0xA7 {
							print color('red'), " Flag = EMERGENCY\n", color('reset');
						}
					}
					switch (ord(substr($Message, 12, 1))) {
						case 0x00 { # Individual Page
							print color('yellow'), "  Individual Page 12\n", color('reset');
							P25Link::Bytes_2_HexString($Message);

						}
						case 0x90 { #Group Page
							print color('yellow'), "  Group Page 12\n", color('reset');
							P25Link::Bytes_2_HexString($Message);
						}
					}
					switch (ord(substr($Message, 13, 1))) {
						case 0x00 { # Individual Page
							print color('yellow'), "  Individual Page 13.\n", color('reset');
						}
						case 0x80 { # Group Page
							print color('yellow'), "  Group Page 13.\n", color('reset');
						}
						case 0x9F { # Individual Page Ack
							print color('yellow'), "  Individual Page Ack 13.\n", color('reset');
						}
					}
#					AddToSuperFrame(0xA1, $Message);
					Packets::Tx_to_Network($Message);

				} else {
					print color('yellow'), "UI else 0x" . ord(substr($Message, 2, 1)) . "\n", color('reset');
					P25Link::Bytes_2_HexString($Message);
					print "----------------------------------------------------------------------\n";
				}
			}
		}
		case 0x3F { # SABM Rx
			if ($Verbose) { print "  Rx SABM\n"; }
			if ($Verbose >= 3) {P25Link::Bytes_2_HexString($Message); }
			$HDLC_Handshake = 0;
			$HDLC{'RR_Timer'}{'Enabled'} = 0;
			#if ($Verbose > 1) { print "    Calling HDLC_Tx_UA\n"; }
			HDLC_Tx_UA(0xFD); # 253
			$SABM_Counter = $SABM_Counter + 1;
			if ($SABM_Counter > 3) {
				if ($Packets::Mode == 0) {
					Serial::Reset();
				}
				$HDLC_TxTraffic = 0;
				$SABM_Counter = 0;
			}
		}
		case 0x73 { #
			if ($Verbose) { print color('green'), "  Rx UA (case 0x73 Unumbered Ack).\n", color('reset'); }
			if ($Verbose >= 3) {P25Link::Bytes_2_HexString($Message); }
		}
		case 0xBF { # XID Quantar to DIU identification packet.
			if ($Verbose) { print color('green'), "  Rx XID.\n", color('reset'); }
			if ($Verbose >= 3) {P25Link::Bytes_2_HexString($Message); }
			$SABM_Counter = 0;
			my $MessageType = ord(substr($Message, 2, 1));
			my $StationSiteNumber = (int(ord(substr($Message, 3, 1))) - 1) / 2;
			$StationType = ord(substr($Message, 4, 1));
			if ($StationType == C_Quantar) {
				if ($Verbose > 1) { print "  Station type = Quantar.\n"; }
			}
			if ($StationType == C_DIU3000) {
				if ($Verbose > 1) { print "  Station type = DIU3000 or ATAC.\n"; }
			}
			if ($Verbose) { print color('yellow'), "  0x0B calling HDLC_Tx_XID\n", color('reset'); }
			HDLC_Tx_XID(0x0B);
			$HDLC_Handshake = 1;
			$HDLC{'RR_Timer'}{'Enabled'} = 1;
			
			#if ($Verbose) { print color('yellow'), "  0x0B calling HDLC_Tx_RR\n", color('reset'); }
			#HDLC_Tx_RR();
		}
	}
	if ($Verbose) {
		print "----------------------------------------------------------------------\n";
	}
	return($Packets::Pending_CourtesyTone, Packets::GetLinkedTalkGroup());

}



sub HDLC_RR_Timer { # HDLC Receive Ready keep alive.
#my $Verbose = 1;
#if ($Verbose) { print color('yellow'), "HDLC_RR_Timer event $HDLC{'RR_Timer'}{'Enabled'}\n", color('reset'); }

	if ($HDLC{'RR_Timer'}{'Enabled'}) {

#my $Verbose = 1;
#if ($Verbose) { print color('green'), "HDLC_RR_Timer event $HDLC{'RR_Timer'}{'Enabled'}\n", color('reset'); }

		if (P25Link::GetTickCount() >= $HDLC{'RR_Timer'}{'NextTime'}) {
			if ($Verbose) { print color('green'), "HDLC_RR_Timer event\n", color('reset'); }
			if ($HDLC_Handshake) {
				#print "  RR Timed out @{[int time - $^T]}\n";
				if (($Packets::Mode == 0) or (($Packets::Mode == 1) and CiscoSTUN::GetSTUN_Connected())) {
					if ($Verbose) {
						#print "$hour:$min:$sec Send RR by timer.\n";
						#print "  Mode = $Mode, STUN_Connected = " . CiscoSTUN::GetSTUN_Connected() .
						#	", and HDLC_TxTraffic = $HDLC_TxTraffic\n";
					}
					HDLC_Tx_RR();
					if ($Verbose) {
						print "----------------------------------------------------------------------\n";
					}
				}
			}
			$HDLC{'RR_Timer'}{'NextTime'} = P25Link::GetTickCount() + $HDLC{'RR_Timer'}{'Interval'};
		}
	}
}

sub Start_RR_Timer {
	$HDLC{'RR_Timer'}{'NextTime'} = P25Link::GetTickCount() + $HDLC{'RR_Timer'}{'Interval'};
}

sub HDLC_Connection_WD_Timer { # HDLC connection watchdog.
	if ($HDLC{'Connection_WD_Timer'}{'Enabled'}) {
		if (P25Link::GetTickCount() >= $HDLC{'Connection_WD_Timer'}{'NextTime'}) {
			if ($Verbose) { print color('Yellow'), "HDLC_Connection_WD_Timer event\n", color('reset'); }
				$HDLC_Handshake = 0;
				$HDLC{'RR_Timer'}{'Enabled'} = 0;
				if ($Verbose) {
					print "----------------------------------------------------------------------\n";
				}
		}
		$HDLC{'Connection_WD_Timer'}{'NextTime'} = P25Link::GetTickCount() + $HDLC{'Connection_WD_Timer'}{'Interval'};
	}
}

sub Start_Connection_WD_Timer {
	$HDLC{'Connection_WD_Timer'}{'NextTime'} = P25Link::GetTickCount() + $HDLC{'Connection_WD_Timer'}{'Interval'};
}

sub HDLC_SABM_Timer { # HDLC SABM Tx to init connection.
	if ($HDLC{'SABM_Timer'}{'Enabled'}) {
		if (P25Link::GetTickCount() >= $HDLC{'SABM_Timer'}{'NextTime'}) {
			if ($Verbose) { print color('green'), "HDLC_SABM_Timer event\n", color('reset'); }
			if (!$HDLC_Handshake) {
				#print "  SABM Timed out @{[int time - $^T]}\n";
				if (($Packets::Mode == 0) or (($Packets::Mode == 1) and !CiscoSTUN::GetSTUN_Connected())) {
					HDLC_Tx_SABM();
					if ($Verbose) {
						print "----------------------------------------------------------------------\n";
					}
				}
			}
			$HDLC{'SABM_Timer'}{'NextTime'} = P25Link::GetTickCount() + $HDLC{'SABM_Timer'}{'Interval'};
		}
	}
}

sub HDLC_Tx {
	my ($Data, $Restart_RR_Timer) = @_;
	my $CRC;
	my $MSB;
	my $LSB;
	if ($Restart_RR_Timer) { Start_RR_Timer(); }
	#$Data = chr(0xFD) . chr(0x3F);
#	if ($Verbose) { print color('green'), "HDLC_Tx\n"; }
	if ($Packets::Mode == 0) { # Mode = 0 Serial
		Serial::Tx($Data);
	} elsif ($Packets::Mode == 1) { # Mode = 1 STUN
		CiscoSTUN::Tx($Data);
	} elsif ($Packets::Mode == 2) { # Mode = 2 Quantar Bridge
		Bridge::Tx($Data);
	}
#	if ($Verbose) { print "  Tx Done.\n"; }
}

sub HDLC_Tx_SABM {
	my ($Address) = @_;
	if ($Verbose) { print color('green'), "HDLC_Tx_SABM\n", color('reset'); }
	my $Data = chr($Address) . chr(0xBF) . chr(0x01) . chr(0x1B) . chr(0x00) .
		chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0xFF);
	HDLC_Tx ($Data, 0);
}
sub HDLC_Tx_UA {
	my ($Address) = @_;
	if ($Verbose) { print color('green'), "HDLC_Tx_UA\n", color('reset'); }
	my $Data = chr($Address) . chr(0x73);
	HDLC_Tx ($Data, 0);
}

sub HDLC_Tx_XID {
	my ($Address) = @_;
	if ($Verbose) { print color('green'), "HDLC_Tx_XID.\n", color('reset'); }
	my $ID = 13;
	my $Data = chr($Address) . chr(0xBF) . chr(0x01) . chr($ID * 2 + 1) . chr(0x00) . 
		chr(0x00) . chr(0x00) . chr(0x00) . chr(0x00) . chr(0xFF);
	HDLC_Tx ($Data, 0);
}

sub HDLC_Tx_RR {
	if ($Verbose) { print color('green'), "HDLC_Tx_RR.\n", color('reset'); }
	my $Data = chr(0xFD) . chr(0x01); # 253
	HDLC_Tx ($Data, 0);
}

sub Page_Tx {
	my ($DestinationRadioID, $SourceRadioID, $Individual, $Emergency) = @_;
	my $Address = 0x07;
	my $Ind_Group_Page = C_Group_Page;
	if ($Individual) {
		$Ind_Group_Page = C_Individual_Page;
	}
	my $RTRT;
	if ($HDLC_RTRT_Enabled == 1) {
		$RTRT = C_RTRT_Enabled;
	} else {
		$RTRT = C_RTRT_Disabled;
	}
	my $DestMMSB = (($DestinationRadioID & 0xFF0000) >> 16);
	my $DestMSB = (($DestinationRadioID & 0xFF00) >> 8);
	my $DestLSB = ($DestinationRadioID & 0xFF);
	my $SrcMMSB = (($SourceRadioID & 0xFF0000) >> 16);
	my $SrcMSB = (($SourceRadioID & 0xFF00) >> 8);
	my $SrcLSB = ($SourceRadioID & 0xFF);

	if ($Emergency) {
		if ($Verbose) { print color('red'), "Emergency_Tx.\n", color('reset'); }
		# Emergency packet from radio 1 to TG 65535:
		# 07 03 a1 02 02 0c 0f 00 00 00 00 a7 00 00 00 00 ff ff 00 00 01 3f 11 00 01 48 02
		my $Data = chr($Address) . chr(C_UI) . chr(C_RN_Page) . chr(0x02) . chr($RTRT) .
			chr(0x0C) . chr(0x0F) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(C_Emergency_Page) . chr($Ind_Group_Page) . chr(0x00) . chr(0x00) .
			chr($DestMMSB) . chr($DestMSB) . chr($DestLSB) . chr($SrcMMSB) . chr($SrcMSB) .
			chr($SrcLSB) . chr(0x3F) . chr(0x11) . chr(0x00) . chr(0x01) .
			chr(0x48) . chr(0x02);
		if ($Verbose >= 2) {P25Link::Bytes_2_HexString($Data); }
		HDLC_Tx ($Data, 0);
		HDLC_Tx(chr($Address) . chr(C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr(C_EndTx) . chr(C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00), 0);
		HDLC_Tx(chr($Address) . chr(C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr(C_EndTx) . chr(C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00), 0);
		# TG Disabled
		$DestMMSB = 0x00;
		$DestMSB = 0x00;
		$DestLSB = 0x01;
		# Emergency packet No TG from radio 1 to TG 8650753 (yes, weird TG):	
		# 07 03 a1 02 02 0c 0f 00 00 00 00 a7 00 00 00 00 00 01 00 00 01 58 A9 00 01 47 02
		$Data = chr($Address) . chr(C_UI) . chr(C_RN_Page) . chr(0x02) . chr($RTRT) .
			chr(0x0C) . chr(0x0F) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(C_Emergency_Page) . chr($Ind_Group_Page) . chr(0x00) . chr(0x00) .
			chr($DestMMSB) . chr($DestMSB) . chr($DestLSB) . chr($SrcMMSB) . chr($SrcMSB) .
			chr($SrcLSB) . chr(0x58) . chr(0xA9) . chr(0x00) . chr(0x01) .
			chr(0x47) . chr(0x02);
		HDLC_Tx ($Data, 0);
		HDLC_Tx(chr($Address) . chr(C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr(C_EndTx) . chr(C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00), 0);
		HDLC_Tx(chr($Address) . chr(C_UI) . chr(0x00) . chr(0x02). chr($RTRT) .
			chr(C_EndTx) . chr(C_Page) . chr(0x00) . chr(0x00) . chr(0x00) .
			chr(0x00) . chr(0x00), 0);
	}
}


sub Page_Ack_Tx {
	my ($DestinationRadioID, $SourceRadioID, $Individual) = @_;


}

sub TMS_Tx {
	my ($DestinationRadioID, $Message) = @_;


}



sub CallType {
	my ($CallType) =@_;
	switch ($CallType) {
		case 0x00 { # Group voice channel user.
			$Quant{'IsTGData'} = 1;
			$Quant{'IndividualCall'} = 0;
		}
		case 0x02 { # Group voice channel update.
			$Quant{'IndividualCall'} = 0;
		}
		case 0x03 { # Unit to unit voice channel user.
			$Quant{'IndividualCall'} = 1;
		}
		case 0x04 { # Group voice channel update - explicit.
			$Quant{'IndividualCall'} = 1;
		}
		case 0x05 { # Unit to unit answer request.
			$Quant{'IndividualCall'} = 1;
		}
		case 0x06 { # Telephone interconnect voice channel user.
			print "Misterious packet.";
		}
		case 0x07 { # Telephone interconnect answer request.
			print "Telephone interconnect answer request.\n";
		}
		case 0x0F { # Call termination/cancellation.
			print "Call termination/cancellation.\n";
		}
		case 0x10 {
			print "Group Affiliation Query\n";
		}
		case 0x11 {
			print "Unit Registration Command\n";
		}
		case 0x12 {
			print "Unit Authentication Command\n";
		}
		case 0x13 {
			print "Status Query\n";
		}
		case 0x14{ 
			print "Status Update\n";
		}
		case 0x15 {
			print "Message Update\n";
		}
		case 0x16 {
			print "Call Alert\n";
		}
		case 0x17 {
			print "Extended Function Command\n";
		}
		case 0x18 {
			print "Channel Identifier Update\n";
		}
		case 0x19 {
			print "Channel Identifier Update ñ Explicit (LCCIUX)\n";
		}
		case 0x20 {
			print "System Service Broadcast\n";
		}
		case 0x21 {
			print "Secondary Control Channel Broadcast\n";
		}
		case 0x22 {
			print "Adjacent Site Status Broadcast\n";
		}
		case 0x23 {
			print "RFSS Status Broadcast\n";
		}
		case 0x24 {
			print "Network Status Broadcast\n";
		}
		case 0x25 {
			print "Protection Parameter Broadcast\n";
		}
		case 0x26 {
			print "Secondary Control Channel Broadcast - Explicit (LCSCBX)\n";
		}
		case 0x27 {
			print "Adjacent Site Status Broadcast ñ Explicit (LCASBX)\n";
		}
		case 0x28 {
			print "RFSS Status Broadcast ñ Explicit (LCRSBX)\n";
		}
		case 0x29 {
			print "Network Status Broadcast ñ Explicit (LCNSBX)\n";
		}
	}
}

sub ManufacturerName {
	my ($ManID) = @_;
	my $ManufacturerName = "Not Registered";
	switch ($ManID) {
		case 0x00 {
			$ManufacturerName = "Default Value";
		}
		case 0x01 {
			$ManufacturerName = "Another Default Value";
		}
		case 0x09 {
			$ManufacturerName = "Aselan Inc";
		}
		case 0x10 {
			$ManufacturerName = "Relm/BK Radio";
		}
		case 0x18 {
			$ManufacturerName = "Airbus";
		}
		case 0x20 {
			$ManufacturerName = "Cyccomm";
		}
		case 0x28 {
			$ManufacturerName = "Efratom";
		}
		case 0x30 {
			$ManufacturerName = "Com-Net Ericsson";
		}
		case 0x34 {
			$ManufacturerName = "Etherstack";
		}
		case 0x38 {
			$ManufacturerName = "Datron";
		}
		case 0x40 {
			$ManufacturerName = "Icom";
		}
		case 0x48 {
			$ManufacturerName = "Garmin";
		}
		case 0x50 {
			$ManufacturerName = "GTE";
		}
		case 0x55 {
			$ManufacturerName = "IFR Systems";
		}
		case 0x5A {
			$ManufacturerName = "INIT Innovations";
		}
		case 0x60 {
			$ManufacturerName = "GEC-Marconi";
		}
		case 0x64 {
			$ManufacturerName = "Harris Corp (inactive)";
		}
		case 0x68 {
			$ManufacturerName = "Kenwood";
		}
		case 0x70 {
			$ManufacturerName = "Glenayre Electronics";
		}
		case 0x74 {
			$ManufacturerName = "Japan Radio Co.";
		}
		case 0x78 {
			$ManufacturerName = "Kokusai";
		}
		case 0x7C {
			$ManufacturerName = "Maxon";
		}
		case 0x80 {
			$ManufacturerName = "Midland";
		}
		case 0x86 {
			$ManufacturerName = "Daniels Electronics";
		}
		case 0x90 {
			$ManufacturerName = "Motorola";
		}
		case 0xA0 {
			$ManufacturerName = "Thales";
		}
		case 0xA4 {
			$ManufacturerName = "Harris Corporation";
		}
		case 0xAA {
			$ManufacturerName = "NRPC";
		}
		case 0xB0 {
			$ManufacturerName = "Raytheon";
		}
		case 0xC0 {
			$ManufacturerName = "SEA";
		}
		case 0xC8 {
			$ManufacturerName = "Securicor";
		}
		case 0xD0 {
			$ManufacturerName = "ADI";
		}
		case 0xD8 {
			$ManufacturerName = "Tait Electronics";
		}
		case 0xE0 {
			$ManufacturerName = "Teletec";
		}
		case 0xF0 {
			$ManufacturerName = "Transcrypt International";
		}
		case 0xF8 {
			$ManufacturerName = "Vertex Standard";
		}
		case 0xFC {
			$ManufacturerName = "Zetron Inc";
		}
	}
		if ($Verbose) { print color('grey12'), "  Manufacturer Name = $ManufacturerName\n", color('reset'); }
}

sub AlgoName {
	my ($AlgoID) = @_;
	my $AlgoName = "Unknown Algo";
	switch ($AlgoID) {
		case 0x0 {
			$AlgoName = "Accordian 1.3";
		}
		case 0x1 {
			$AlgoName = "Baton (Auto/Even)";
		}
		case 0x2 {
			$AlgoName = "FireFly Type 1";
		}
		case 0x3 {
			$AlgoName = "MayFly Type 1";
		}
		case 0x4 {
			$AlgoName = "FASCINATOR/Saville";
		}
		case 0x41 {
			$AlgoName = "Baton (Auto/Odd)";
		}
		case 0x80 {
			$AlgoName = "Unencrypted";
		}
		case 0x81 {
			$AlgoName = "DES";
		}
		case 0x83 {
			$AlgoName = "Triple DES";
		}
		case 0x84 {
			$AlgoName = "AES 256";
		}
		case 0x85 {
			$AlgoName = "AES 128 GCM";
		}
		case 0x88 {
			$AlgoName = "AES CBC";
		}
		case 0x9F {
			$AlgoName = "DES-XL";
		}
		case 0xA0 {
			$AlgoName = "DVI-XL";
		}
		case 0xA1 {
			$AlgoName = "DVP-XL";
		}
		case 0xAA {
			$AlgoName = "ADP";
		}
	}
	if ($Verbose) { print color('grey12'), "  Algo Name = $AlgoName\n", color('reset'); }
}



sub GetStationType {
	return($StationType);
}

sub GetLocalRx {
	return($Quant{'LocalRx'});
}

sub SetLocalRx {
	my ($Value) = @_;
	$Quant{'LocalRx'} = $Value;
}

sub GetLocalTx {
	return($Quant{'LocalTx'});
}

sub GetIsDigitalVoice {
	return($Quant{'IsDigitalVoice'});
}

sub GetIsPage {
	return($Quant{'IsPage'});
}

sub GetLocalRx_Time {
	return($Quant{'LocalRx_Time'});
}

sub GetHDLC_Handshake() {
	return($HDLC_Handshake);
}

sub SetHDLC_TxTraffic {
	my ($Value) = @_;
	$HDLC_TxTraffic = $Value;
}



sub Verbose {
	my ($Value) = @_;
	$Verbose = $Value;
}



1;