# TrueNAS Scale Scripts

Handy shell and Perl scripts for use on TrueNAS Scale servers.

This repo is a port of [FreeNAS-scripts](https://github.com/Spearfoot/FreeNAS-scripts) by Keith Nash a.k.a. Spearfoot to TrueNas Scale.

Most of the shell scripts here are Keith's versions of the useful scripts available at the ["Scripts to report SMART, ZPool and UPS status, HDD/CPU T°, HDD identification and backup the config"](https://forums.freenas.org/index.php?threads/scripts-to-report-smart-zpool-and-ups-status-hdd-cpu-t%C2%B0-hdd-identification-and-backup-the-config.27365/) thread on the FreeNAS forum. 
The original author is FreeNAS forum member BiduleOhm, with others contributing suggestions and code changes. 
I have modified the syntax and made minor changes in formatting and spacing of the generated reports.

I used the excellent shell script static analysis tool at https://www.shellcheck.net to ensure that all the code is POSIX-compliant and free of issues. 
But this doesn't mean you won't find any errors.  ☺️

All the Perl code is Keit's contribution.

***
#### Operating System Compatibility

Tested under:
* TrueNAS-SCALE-22.02.4 (Linux Kernel 5.10.142)


***
# smart_report.sh

Generates and emails you a status report with detailed SMART information about your system's SATA and SAS drives. A hearty thanks to contributor marrobHD for help in adding SAS support.

You will need to edit the script and enter your email address before using it.

NOTE: Users of some HBA controllers may need to change the SMARTCTL call, adding a device specifier. (Hat tip to commenter Tuplink for pointing this out).

Example: for a 3ware controller, edit the script to invoke SMARTCTL like this:

```
"${smartctl}" [options] -d 3ware,"${drive}" /dev/twa0
```
...instead of...
```
"${smartctl}" [options] -d /dev/"${drive}"
```
Refer to the SMARTCTL man page for addtional details, including support for other controller types.
***
# zpool_report.sh

Generates and emails you a status report about your system's pools.

You will need to edit the script and enter your email address before using it.
***
# ups_report.sh
Generates and emails you a status report about your UPS.

You will need to edit the script and enter your email address before using it. You may also have the report include all of the available UPSC variables by setting the `senddetail` variable to a value greater than zero.
***
# save_config.sh

Saves your TrueNAS/FreeNAS system configuration files to a dataset you specify, by creating a tarball containing the SQLite configuration database (_freenas-v1.db_) and password secret seed encryption file (_pwenc_secret_). The tarball is suitable for use in restoring the configuration on TrueNAS/FreeNAS systems.

**!!! Security Warning !!!**
> The system configuration and password secret seed encryption file are sensitive information and should be stored on a dataset available only to system administrators!

The backup database and tarball filenames are formed from the hostname, complete TrueNAS/FreeNAS version, date, and _tar_ or _db_ extension, in this format: _hostname-version-date.extension_. Here are examples from a recent backup on my server named _brutus_:

```
brutus-FreeNAS-11.2-U8-06e1172340-20210806114838.tar
brutus-FreeNAS-11.2-U8-06e1172340-20210806114838.db
```

Edit the script and set variable `configdir` to specify the configuration directory, a dataset where you want the backup files stored.

Optional features:
* Specify your email address in variable `notifyemail` to receive notification messages whenever the script executes.
* Specify your ESXi short hostname in variable `esxihost` to backup the ESXi server configuration file. These backup filenames are formed from the hostname and date in this format: _hostname-configBundle-date.tgz_. Here is an example from a recent backup on my ESXi server _frisco_, on which _brutus_ is a guest:

  ```
  frisco-configBundle-20210806114840.tgz
  ```
Procedure:
* Create backup of _/data/freenas-v1.db_ using the SQLite `.backup main` command with backup target _hostname-version-date.db_ in the configuration directory
* Copy _/data/pwenc_secret_ to the configuration directory
* Check integrity of the backup database with the SQLite `pragma integrity_check;` command
* Copy the validated backup database to _freenas-v1.db_ in the configuration directory
* Add _freenas-v1.db_ and _pwenc_secret_ to tar file _hostname-version-date.tar_ in the configuration directory
* Optionally create ESXi configuration bundle in the configuration directory
* Optionally send an email notification upon completion

Note that each invocation of the script creates these files in the configuration directory:
* _hostname-version-date.db_ : validated backup of configuration database _/data/freenas-v1.db_
* _hostname-version-date.tar_ : tar file containing the above configuration database along with the password secret seed encryption file _pwenc_secret_.
* _freenas-v1.db_ : copy of the validated backup configuration database above; over-written each time the script is executed
* _pwenc_secret_ : copy of _/data/pwenc_secret_, over-written each time the script is executed
***
# save_config_enc.sh

Saves your FreeNAS system configuration and password secret seed files to a dataset you specify, optionally sending you an email message containing these files in an encrypted tarball.

**!!! Security Warning !!!**
> The system configuration and password secret seed encryption file are sensitive information and should be stored on a dataset available only to system administrators!

Supports the versions of FreeNAS which use an SQLite-based configuration file: these include FreeNAS 9.x-12.x, and probably earlier versions as well. 

The backup configuration filenames are formed from the hostname, complete FreeNAS version, and date, in this format: _hostname-freenas_version-date.db_. Here is an example from a recent backup on my server named _bandit_:

```
bandit-FreeNAS-11.0-RELEASE-a2dc21583-20170710234500.db
```

Edit this script and set variable `configdir` to specify the target dataset where you want the backup files copied.

Optional feature: Specify your email address and create a passphrase file to receive an email message whenever it executes. The script will create an encrypted tarball containing the configuration file and password secret seed files, which it will include with the email message as a MIME-encoded attachment. 

To enable this feature you must:
* Edit the script and specify your email address in variable 'mail'
* Create a passphrase file. By default, the script will look for a passphrase in `/root/config_passphrase`, but you may use any file location you prefer. This is a simple text file with a single line containing the passphrase you wish to use for encrypting/decrypting the configuration tarball. This file should be owned by `root` and you should secure it by setting its permissions to 0600 (owner read/write).

The attachment filename is formed from the hostname, complete FreeNAS version, and date, in this format: _hostname-freenas_version-date.tar.gz.enc_. Here is an example from a recent backup on my server named _bandit_:

```
bandit-FreeNAS-11.0-RELEASE-a2dc21583-20170710234500.tar.gz.enc
```
The script uses `tar` to store the configuration and password secret seed files in a gzipped tarball, which it encrypts by calling `openssl`, using the passphrase you specified above. For FreeNAS versions prior to 12.x, this is the command used to encrypt the tarball:

`openssl enc -e -aes-256-cbc -md sha512 -salt -S "$(openssl rand -hex 4)" -pass file:[passphrase_file] -in [tarball] -out [encrypted_tarball]`

To decrypt the email attachment, use this command on your FreeNAS system:

`openssl enc -d -aes-256-cbc -md sha512 -pass file:[passphrase_file] -in [encrypted_file] -out [unencrypted_file]`

For version 12.x of FreeNAS we add the new OpenSSL v1.1.1 options `-pbkdf2` and `-iter` thus:

`openssl enc -e -aes-256-cbc -md sha512 -pbkdf2 -iter 128000 -salt -S "$(openssl rand -hex 8)" -pass file:[passphrase_file] -in [tarball] -out [encrypted_tarball]`

To decrypt the email attachment, use this command on your FreeNAS system:

`openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 128000 -pass file:[passphrase_file] -in [encrypted_file] -out [unencrypted_file]`

In the above commands:
* `passphrase_file` is a file containing the same passphrase you configured on your FreeNAS server
* `encrypted_file` is your locally-saved copy of the email attachment
* `unencrypted_file` is the unencrypted contents of the email attachment
***
# set_hdd_erc.sh

Sets the Error Recovery Control (aka SCTERC or TLER) read and write values on your system's hard drives. What is this? There is a good discussion in the ["Checking for TLER, ERC, etc. support on a drive"](https://forums.freenas.org/index.php?threads/checking-for-tler-erc-etc-support-on-a-drive.27126/) thread on the FreeNAS forum, and you can find more gory details in [this FAQ](https://www.smartmontools.org/wiki/FAQ#WhatiserrorrecoverycontrolERCandwhyitisimportanttoenableitfortheSATAdisksinRAID) at the [smartmontools.org](https://www.smartmontools.org) website. This key quote from the FAQ sums up why you want to set this up on your FreeNAS servers:

>"It is best for ERC to be "enabled" when in a RAID array to prevent the recovery time from a disk read or write error from exceeding the RAID implementation's timeout threshold. If a drive times out, the hard disk will need to be manually re-added to the array, requiring a re-build and re-synchronization of the hard disk. Limiting the drives recovery timeout helps for improved error handling in the hardware or software RAID environments."

By default, the script sets both the read and write timeout value to 7 seconds. You can change either or both of these values to better suit your environment.

Some hard drives retain these values when powered down, but some do not - including the HGST 7K4000 drives I use in one of my systems. For this reason, I configure my FreeNAS servers to run `set_hdd_src.sh` as a post-init startup script.
***
# get_hdd_temp.sh

Displays the current temperature of your system's CPU and drives. 

By default, the script uses `sysctl` to determine the number of CPU cores and report their temperatures. 
This reports a temperature for each core on systems equipped with modern multi-core CPUs. 
The optional IPMI support, if enabled, reports a single temperature for each socketed CPU. 
The latter result is probably more useful for monitoring CPU status.

To enable IPMI support, edit the script and:
* Set the `use_ipmi` variable to `1`
* Specify the IPMI host's IP address or DNS-resolvable hostname in the `ipmihost` variable.
* Specify the IPMI username in the `ipmiuser` variable.
* Specify the IPMI password file location in the `ipmipwfile` variable. This is a simple text file containing the IPMI user's password on a single line. You should protect this file by setting its permissions to 0600.

Drive output includes: the device ID, temperature (in Centigrade), capacity, serial number, and drive family/model. Here is sample output from one of my systems equipped with dual CPUs, using the IPMI feature and with serial numbers obfuscated:

```
=== CPU (2) ===
CPU  1: [35C]
CPU  2: [38C]

=== DRIVES ===
   da1:   19C [8.58GB] SN9999999999999999   INTEL SSDSC2BA100G3L
   da2:   39C [4.00TB] SN9999999999999999   HGST Deskstar NAS (HGST HDN724040ALE640)
   da3:   36C [4.00TB] SN9999999999999999   HGST Deskstar NAS (HGST HDN724040ALE640)
   da4:   27C [240GB]  SN9999999999999999   Intel 730 and DC S35x0/3610/3700 (INTEL SSDSC2BB240G4)
   da5:   27C [2.00TB] SN9999999999999999   Western Digital Green (WDC WD20EARX-00PASB0)
   da6:   28C [2.00TB] SN9999999999999999   Western Digital Red (WDC WD20EFRX-68EUZN0)
   da7:   19C [8.58GB] SN9999999999999999   INTEL SSDSC2BA100G3L
   da8:   31C [6.00TB] SN9999999999999999   Western Digital Black (WDC WD6001FZWX-00A2VA0)
   da9:   29C [2.00TB] SN9999999999999999   Western Digital Green (WDC WD20EARX-00PASB0)
  da10:   29C [2.00TB] SN9999999999999999   Western Digital Red (WDC WD20EFRX-68EUZN0)
  da11:   34C [4.00TB] SN9999999999999999   HGST HDN726040ALE614
  da12:   37C [4.00TB] SN9999999999999999   HGST HDN726040ALE614
  da13:   37C [4.00TB] SN9999999999999999   Western Digital Re (WDC WD4000FYYZ-01UL1B1)
  da14:   38C [4.00TB] SN9999999999999999   Western Digital Re (WDC WD4000FYYZ-01UL1B1)
```
(Thanks to P. Robar for his helpful suggestions with respect to `sysctl` usage and the `get_smart_drives()` function.)
***
# get-system-temps.pl

Displays the current temperature of your system's CPU and drives.

This is a Perl version of the `get_cpu_temp.sh` script above. 

By default, the script uses `sysctl` to determine the number of CPU cores and report their temperatures. This reports a temperature for each core on systems equipped with modern multi-core CPUs. The optional IPMI support, if enabled, reports a single temperature for each socketed CPU. The latter result is probably more useful for monitoring CPU status.

To enable IPMI support, edit the script and:
* Set the `$useipmi` variable to `1`
* Specify the IPMI host's IP address or DNS-resolvable hostname in the `$ipmihost` variable.
* Specify the IPMI username in the `$ipmiuser` variable.
* Specify the IPMI password file location in the `$ipmipwfile` variable. This is a simple text file containing the IPMI user's password on a single line. You should protect this file by setting its permissions to 0600.

Drive output includes: the device ID, temperature (in Centigrade), capacity, drive type (HDD or SDD), serial number, drive model, and (when available) the model family. Here is sample output from one of my systems equipped with dual CPUs, using the IPMI feature and with serial numbers obfuscated:

```
==========

bandit.spearfoot.net (IPMI host: falcon.ipmi.spearfoot.net)

=== CPU (2) ===
CPU  1:  35C
CPU  2:  39C

=== Drives ===
   da1:  20C [ 8.58 GB SSD] SN999999999999999999 INTEL SSDSC2BA100G3L 
   da2:  37C [ 4.00 TB HDD] SN999999999999999999 HGST HDN724040ALE640 (HGST Deskstar NAS)
   da3:  35C [ 4.00 TB HDD] SN999999999999999999 HGST HDN724040ALE640 (HGST Deskstar NAS)
   da4:  28C [  240 GB SSD] SN999999999999999999 INTEL SSDSC2BB240G4 (Intel 730 and DC S35x0/3610/3700 Series SSDs)
   da5:  26C [ 2.00 TB HDD] SN999999999999999999 WDC WD20EARX-00PASB0 (Western Digital Green)
   da6:  28C [ 2.00 TB HDD] SN999999999999999999 WDC WD20EFRX-68EUZN0 (Western Digital Red)
   da7:  19C [ 8.58 GB SSD] SN999999999999999999 INTEL SSDSC2BA100G3L 
   da8:  31C [ 6.00 TB HDD] SN999999999999999999 WDC WD6001FZWX-00A2VA0 (Western Digital Black)
   da9:  29C [ 2.00 TB HDD] SN999999999999999999 WDC WD20EARX-00PASB0 (Western Digital Green)
  da10:  28C [ 2.00 TB HDD] SN999999999999999999 WDC WD20EFRX-68EUZN0 (Western Digital Red)
  da11:  32C [ 4.00 TB HDD] SN999999999999999999 HGST HDN726040ALE614 
  da12:  35C [ 4.00 TB HDD] SN999999999999999999 HGST HDN726040ALE614 
  da13:  36C [ 4.00 TB HDD] SN999999999999999999 WDC WD4000FYYZ-01UL1B1 (Western Digital Re)
  da14:  37C [ 4.00 TB HDD] SN999999999999999999 WDC WD4000FYYZ-01UL1B1 (Western Digital Re)
```


