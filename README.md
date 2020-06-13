# P25NX_v2 Software

This project is based on the work and information from:
David Kraus NX4Y
Byan Fields W9CR

To use the p25nx_v2 program copy files to your Raspberry path /opt/p25nx2.

To run the configuration menu:

cd /opt/p25nx2
sudo chmod 755 p25nx2-menu
sudo ./p25nx2-menu

there you can make the initial setup, download libraries to get it working, etc.

Mode = 0 means use of Serial (using Quantar_P25Link board).

Mode = 1 means use of Cisco router and STUN.

Modify the hosts.txt file with the Talk Groups you want lo add to the Scan list by setting the last field to a highest take precedence >= 1, 0 = No Scan.

This software and hardware is licenced under the GPL v3. If you are using it, please let me know, I will be glad to know it.
