#!/usr/bin/env bash

# See https://sharats.me/posts/shell-script-best-practices/
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

# https://www.smartmontools.org/wiki/FAQ#WhatiserrorrecoverycontrolERCandwhyitisimportanttoenableitfortheSATAdisksinRAID

# ERC timeout values, in tenths of a second. The defaults below are 7 seconds for both reads and writes:

readsetting=70
writesetting=70

# Full path to 'smartctl' binary:
smartctl=$(which smartctl)

# We need a list of the SMART-enabled drives on the system. Choose one of these
# three methods to provide the list. Comment out the two unused sections of code.

# 1. A string constant; just key in the devices you want to report on here:
#drives="da1 da2 da3 da4 da5 da6 da7 da8 ada0"

# 2. A systcl-based technique suggested on the FreeNAS forum:
#drives=$(for drive in $(sysctl -n kern.disks); do \
#if [ "$($(which smartctl) -i /dev/${drive} | grep "SMART support is: Enabled" | awk '{print $3}')" ]
#then printf ${drive}" "; fi done | awk '{for (i=NF; i!=0 ; i--) print $i }')

# 3. A smartctl-based function:
get_smart_drives()
{
  gs_drives=$(${smartctl} --scan | grep "dev" | awk '{print $1}' | sed -e 's/\/dev\///' | tr '\n' ' ')

  gs_smartdrives=""

  for gs_drive in $gs_drives; do
    gs_smart_flag=$(${smartctl} -i /dev/"$gs_drive" | grep "SMART support is: Enabled" | awk '{print $4}')
    if [ "$gs_smart_flag" = "Enabled" ]; then
      gs_smartdrives=$gs_smartdrives" "${gs_drive}
    fi
  done

  eval "$1=\$gs_smartdrives"
}

drives=""
get_smart_drives drives

# end of method 3.

set_erc()
{
  echo "Drive: /dev/$1"
  ${smartctl} -q silent -l scterc,"${readsetting}","${writesetting}" /dev/"$1"
  ${smartctl} -l scterc /dev/"$1" | grep "SCT\|Write\|Read"
}

for drive in $drives; do
  set_erc "$drive"
done
