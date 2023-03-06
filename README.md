# P25Link Software

Warning: v2.40-5 is a work in progress, if you want to run a stable version use .deb file or p25link_v2.34.4.pl

P25Link is a program that let you connect your Quantar repeater or Astro DIU 3000 to multiple HAM networks as P25Link, P25NX, and P25-MMDVM.
It use the v.24 port on Quantar/DIU 3000, a Cisco router 28xx and a Raspberry Pi. It use the same router setup as P25NX.

# Current version features:
- Local voice talk groups 1 to 10.
- P25Link network Voice talk groups 11 to 65534 (each TG is network selectable).
- P25NX network Voice talk groups 10100 to 10599 (each TG is network selectable) Will be deprecated as it is abandoned by its creator.
- P25-MMDVM network Voice talk groups 11 to 65534 (each TG is network selectable).
- TMS (text messages) implemented if repeaters are on P25Link network and radios on linked TG.
- Page functionality implemented if repeaters are on P25Link network and radios on linked TG.
- Repeater scan mode with priority index for talk groups on P25Link and P25NX modes.
- Local and remote courtesy tones.
- RDAC for P25Link and P25NX.

# Setup
- Enable RTRT on your repeater.
- To setup the P25Link software for yor Quantar or Astro DIU 3000, you will need to install a fresh Raspbian image on your Raspberry Pi.
- Next, log to it using SSH.
- Run the following commands:
```
cd /opt
```
- Download the current p25link_2.xx-x.deb file (where xx-x is the desired version) using the following command:

```
sudo wget https://github.com/Wodie/p25link/raw/master/installer/p25link_2.xx-x.deb
```
- Install it with the following command:
```
sudo apt install /opt/p25link_2.xx-x.deb
```

- To configure, run the main menu run:
```
sudo /opt/p25link/p25link-menu
```
- READ what you are asked to input.

- To test app run:
```
sudo /opt/p25link/p25link
```
- Remember to modify the hosts.txt file with the Talk Groups you want lo add to the scan list by setting the last field to a highest take precedence >= 1, 0 = No scan.

Local Dashboard is feature that do not work, (still under development).


# Version History:

## v2.40-6 Jan 06, 2023.
- Added: Support for Atro TAC connection.
- Fixed: A lot of bugs caused due to code split into multiple files for easier code management.
- Bug: Please ignore DMR code and features, they are useless.

## v2.40-5 Jan 20, 2023.
- Added: Code is now spread in multiple files.
- Fixed: Performance improved.
- Added: RDAC shows station type.
- Bug Fixed: Double courtesy tone.
- Added: SuperFrame is a work in progress feature, not working.
- Bug: Please ignore DMR code and features, they are useless.

## v2.40-0 Dec 17, 2022.
- Added: DMR Linking test harness.

## v2.34-5 Dec 17, 2022.
- Added: Minor development debugging lines for MMDVM added, Frames counter/order checker.

## v2.34-4 May 02, 2022.
- Added: Minor development debugging lines added and syntax fixes.

## v2.34-3 April 20, 2022.
- Bug Fixed: Missing library on package installer .deb.

## v2.34-2 April 11, 2022.
- Bug Fixed: HDLC RR flag bug fixed.

## v2.34-1 February 03, 2022.
- Bug Fixed: FAP bug found.

## v2.34-0 January 29, 2022.
- Bug Fixed: FAP bug found.

## v2.33-6 September 16, 2021.
- Bug Fixed: MMDVM Dynamic connection.
- Bug Fixed: MMDVM dis-connect TG when new TG is requested.

## v2.33-5 June 01, 2021.
- Added: Voice Announce "Alarm".
- Added: Emergency Page.
- Added: Talk Group 65535 is now a valid local TG.
- Bug Fixed: P25NX and P25Link network Courtesy tone played multiple times on every Tx end..

## v2.33-4 March 31, 2021.
- Bug Fixed: MMDVM ICW Terminate was never sent.

## v2.33-3 March 29, 2021.
- Fixed: Multiple architecture now supported.

## v2.33-2 March 18, 2021.
- Bug Fixed: Warble sound removed (Read_Timeout decreased).
- Bug Fixed: Audio loss on QSOs larger than 1 min (Read_Timeout).
- Bug Fixed: HDLC RR sent while audio is sent to HDLC causing audio drops.

## v2.33-1 March 10, 2021.
- Fixed: App does not crash when unable to reach MMDVM reflector.

## v2.33-0 March 06, 2021.
- Fixed: Priority to local TGs and reliable scan pause.
- Fixed: first-time menu bugs fixed.
- Added: Code block for local dashboard begin to be implemented.

## v2.32-0 January 03, 2021.
- Fixed: config.ini file now have full file paths.
- Fixed: autostart configuration settings that were not allowing app to autostart.
- Fixed: autostart can be run by diferent user accounts.
- Added: p25link-menu options to setup different user.

## v2.31-0 November 19, 2020.
- Fixed: code simplification and optimisation.
- Added: Alive column added on aprs.txt file, now objects can be killed. Please update your aprs.txt file.

## v2.30-3 November 13, 2020.
- New: RDAC, which used to be the Report to server draft.
- New: Site Name field.
- New: Site Info field.
- Fixed: App was consuming a lot of CPU.

## v2.30-2 November 09, 2020.
- Misc: Minor APRS code fixes.
- Added: Linked Talk Group now updates on APRS-IS.
- Added: APRS objects update time can be changed on the config.ini file.
- Fixed: some .deb bugs.
- Added: Semi automatic creation of .deb file.
- Added: APRS-IS rotate server.

## v2.30 October 23, 2020.
- Lot of code updates and bugs fixed.
- All config files changed and been renamed.
- New Voice Announcements.
- First time menu changed, now it is very friendly.
- Report to server draft code implemented.

## v2.20 October 12, 2020.
- APRS-IS objects code modified.
- config.ini APRS-IS stanza renamed to APRS.

## v2.20 October 02, 2020.
- APRS-IS objects implemented.

## v2.19 September 29, 2020.
- APRS-IS implemented, now the repeater location can be posted thru APRS-IS.

## v2.00.18 September 17, 2020.
- Dynamic Talk Groups disconnect function implemented using Hangtime timer.
- Voice announce bug fixed, should play complete files. hosts.txt file updated.

## v2.00.18 August 18, 2020.
- Courtesy tones implemented.
- Call end timer bug fixed.

## v2.0.17 September 03, 2020.
- Bug fixes.

## v2.0.16 August 25, 2020.
- P25Link Talk Groups now implemented for future compatibility with P25-MMDVM talk groups 11-65534.

## v2.0.15 July 01, 2020.
- Bug fixes.

## v2.0.14 June 11, 2020.
- P25Link beta implementation (TG 4095).
- Page and TMS implementation on P25NX and P25Link beta implementation.

## v2.0.13 June 2, 2020.
- First official public release.

## v2.0.13 May 27, 2020.

## v2.0.12 May 12, 2020.

## v2.0.11 May 12, 2020.

## v2.0.10 January 26, 2020.

## v2.0.9 Deceber 20, 2019.

## v2.0.8 December 01, 2019.

## v2.0.7 November 16, 2019.

## v2.0.6 October 29, 2019.

## v2.0.5 October 29, 2019.

## v2.0.4 October 29, 2019.

## v2.0.3 October 29, 2019.

## v2.0.2 October 29, 2019.

## v2.0.0 October 17, 2019.
- First code created.

# License
This software is licenced under the GPL v3. If you are using it, please let me know, I will be glad to know it.
