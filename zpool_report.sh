#!/usr/bin/env bash

# See https://sharats.me/posts/shell-script-best-practices/
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

### Parameters ###

# Specify your email address here:
email=""

# If a scrub runs longer than 24 hours, we have two additional tokens to parse in the
# zpool status scan line output ("'x' days"):
#
# 1     2     3        4  5  6 7    8        9    10 11    12 13  14  15 16      17
# scan: scrub repaired 0B in 1 days 11:56:46 with 0 errors on Wed Dec 9 06:07:04 2020
#
# 1     2     3        4  5  6        7    8 9      10 11  12  13 14       15
# scan: scrub repaired 0B in 00:09:11 with 0 errors on Sun Dec 13 17:31:24 2020


freenashost=$(hostname -s | tr '[:lower:]' '[:upper:]')
boundary="===== MIME boundary; FreeNAS server ${freenashost} ====="
logfile="/tmp/zpool_report.tmp"
subject="ZPool Status Report for ${freenashost}"
pools=$(zpool list -H -o name)
usedWarn=75
usedCrit=90
scrubAgeWarn=30
warnSymbol="?"
critSymbol="!"

### Set email headers ###
printf "%s\n" "To: ${email}
Subject: ${subject}
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary=\"$boundary\"

--${boundary}
Content-Type: text/html; charset=\"US-ASCII\"
Content-Transfer-Encoding: 7bit
Content-Disposition: inline
<html><head></head><body><pre style=\"font-size:14px; white-space:pre\">" >> ${logfile}

###### summary ######
(
  echo "########## ZPool status report summary for all pools on server ${freenashost} ##########"
  echo ""
  echo "+-----------------+--------+------+------+------+----+----+--------+------+-----+"
  echo "|Pool Name        |Status  |Read  |Write |Cksum |Used|Frag|Scrub   |Scrub |Last |"
  echo "|                 |        |Errors|Errors|Errors|    |    |Repaired|Errors|Scrub|"
  echo "|                 |        |      |      |      |    |    |Bytes   |      |Age  |"
  echo "+-----------------+--------+------+------+------+----+----+--------+------+-----+"
) >> ${logfile}

for pool in $pools; do
  if [ "${pool}" = "freenas-boot" ] || [ "${pool}" = "boot-pool" ]; then
    frag=""
  else
    frag="$(zpool list -H -o frag "$pool")"
  fi

  status="$(zpool list -H -o health "$pool")"
  errors="$(zpool status "$pool" | grep -E "(ONLINE|DEGRADED|FAULTED|UNAVAIL|REMOVED)[ \t]+[0-9]+")"
  readErrors=0
  for err in $(echo "$errors" | awk '{print $3}'); do
    if echo "$err" | grep -E -q "[^0-9]+"; then
      readErrors=1000
      break
    fi
    readErrors=$((readErrors + err))
  done
  writeErrors=0
  for err in $(echo "$errors" | awk '{print $4}'); do
    if echo "$err" | grep -E -q "[^0-9]+"; then
      writeErrors=1000
      break
    fi
    writeErrors=$((writeErrors + err))
  done
  cksumErrors=0
  for err in $(echo "$errors" | awk '{print $5}'); do
    if echo "$err" | grep -E -q "[^0-9]+"; then
      cksumErrors=1000
      break
    fi
    cksumErrors=$((cksumErrors + err))
  done
  if [ "$readErrors" -gt 999 ]; then readErrors=">1K"; fi
  if [ "$writeErrors" -gt 999 ]; then writeErrors=">1K"; fi
  if [ "$cksumErrors" -gt 999 ]; then cksumErrors=">1K"; fi
  used="$(zpool list -H -p -o capacity "$pool")"
  scrubRepBytes="N/A"
  scrubErrors="N/A"
  scrubAge="N/A"
  if [ "$(zpool status "$pool" | grep "scan" | awk '{print $2}')" = "scrub" ]; then
    parseLong=0
    if [ "$(zpool status "$pool" | grep "scan" | awk '{print $7}')" = "days" ]; then
      parseLong=$((parseLong+1))
    fi
    scrubRepBytes="$(zpool status "$pool" | grep "scan" | awk '{print $4}')"
    if [ $parseLong -gt 0 ]; then
      scrubErrors="$(zpool status "$pool" | grep "scan" | awk '{print $10}')"
      scrubDate="$(zpool status "$pool" | grep "scan" | awk '{print $15"-"$14"-"$17" "$16}')"
    else
      scrubErrors="$(zpool status "$pool" | grep "scan" | awk '{print $8}')"
      scrubDate="$(zpool status "$pool" | grep "scan" | awk '{print $13"-"$12"-"$15" "$14}')"
    fi
    scrubTS="$(date -d "$scrubDate" "+%s")"
    currentTS="$(date "+%s")"
    scrubAge=$((((currentTS - scrubTS) + 43200) / 86400))
  fi
  if [ "$status" = "FAULTED" ] || [ "$used" -gt "$usedCrit" ]; then
    symbol="$critSymbol"
  elif [ "$scrubErrors" != "N/A" ] && [ "$scrubErrors" != "0" ]; then
    symbol="$critSymbol"
  elif [ "$status" != "ONLINE" ] \
  || [ "$readErrors" != "0" ] \
  || [ "$writeErrors" != "0" ] \
  || [ "$cksumErrors" != "0" ] \
  || [ "$used" -gt "$usedWarn" ] \
  || [ "$(echo "$scrubAge" | awk '{print int($1)}')" -gt "$scrubAgeWarn" ]; then
    symbol="$warnSymbol"
  elif [ "$scrubRepBytes" != "0" ] &&  [ "$scrubRepBytes" != "0B" ] && [ "$scrubRepBytes" != "N/A" ]; then
    symbol="$warnSymbol"
  else
    symbol=" "
  fi
  (
  printf "|%-15s %1s|%-8s|%6s|%6s|%6s|%3s%%|%4s|%8s|%6s|%5s|\n" \
  "$pool" "$symbol" "$status" "$readErrors" "$writeErrors" "$cksumErrors" \
  "$used" "$frag" "$scrubRepBytes" "$scrubErrors" "$scrubAge"
  ) >> ${logfile}
  done

(
  echo "+-----------------+--------+------+------+------+----+----+--------+------+-----+"
) >> ${logfile}

###### for each pool ######
for pool in $pools; do
  (
  echo ""
  echo "########## ZPool status report for ${pool} ##########"
  echo ""
  zpool status -v "$pool"
  ) >> ${logfile}
done

printf "%s\n" "</pre></body></html>
--${boundary}--" >> ${logfile}

### Send report ###
if [ -z "${email}" ]; then
  echo "No email address specified, information available in ${logfile}"
else
  sendmail -t -oi < ${logfile}
  rm ${logfile}
fi
