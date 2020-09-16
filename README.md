# P25Link Software

P25Link is a program that let you connect your Quantar repeater or DIU 3000 to multiple HAM networks as P25Link, P25NX, and P25-MMDVM. It use the v.24 port on Quantar/DIU 3000, a Cisco router 28xx and a Raspberry Pi. It use the same router setup as P25NX v2.


# Current release features:

## Local
Voice talk groups 1 to 10.

TMS (text messages) implemented if repeaters are on P25Link network.

Page functionality implemented if repeaters are on P25Link network.

Repeater scan mode with priority index for talk groups.

## For P25Link network:
Voice talk groups 11 to 65534.

TMS (text messages) implemented if repeaters are on P25Link network.

Page functionality implemented if repeaters are on P25Link network.

Repeater scan mode with priority index for talk groups.

Local and remote courtesy tones.

## For P25NX network:
Voice talk groups 10100 to 10599.

Voice talk group announce as with pnxmono.

TMS (text messages) implemented if repeaters are on the same TG.

Page functionality implemented if repeaters are on same TG.

Repeater scan mode with priority index for talk groups.

Local and remote courtesy tones.

## For P25-MMDVM network:
Voice talk groups 11 to 65534.

Local and remote courtesy tones.


# Setup

To configure your Cisco router, please follow the P25NX router setup. If you only want to connect to P25-MMDVM, you only need to setup STUN.

To use the p25nx2 program copy files to your Raspberry path /opt/p25nx2.

To run the configuration menu:

cd /opt/p25link
sudo chmod 755 p25link-menu
sudo ./p25link-menu

there you can make the initial setup, download libraries to get it working, etc.

Mode = 0 means use of Serial (using Quantar_P25Link board still on development/test).

Mode = 1 means use of Cisco router and its STUN protocol.

Modify the hosts.txt file with the Talk Groups you want lo add to the Scan list by setting the last field to a highest take precedence >= 1, 0 = No Scan.

# History:

## September 16, 2020.
Voice announce bug fixed, should play complete files. Hosts.txt file updated.

## August 26, 2020.
P25Link Talk Groups now implemented for future compatibility with P25-MMDVM talk groups 11-65534.

## August 18, 2020.
Courtesy tones implemented.

Call end timer bug fixed.

## July, 2020.
Bug fixes.

## June, 2020.
P25Link beta implementation (TG 4095).

Page and TMS implementation on P25NX and P25Link beta implementation.

## June 2, 2020.
First official public release.

# License
This software and hardware is licenced under the GPL v3. If you are using it, please let me know, I will be glad to know it.
