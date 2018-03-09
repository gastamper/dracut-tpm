#!/bin/bash
# vim: set tabstop=8 shiftwidth=4 softtabstop=4 expandtab smarttab colorcolumn=80:
# clevis-dracut-tpm
# Author: Greg Stamper (gastamper@gmail.com)
#
# Original source: http://github.com/latchset/clevis
# Original header:
# Copyright (c) 2016 Red Hat, Inc.
# Author: Harald Hoyer <harald@redhat.com>
# Author: Nathaniel McCallum <npmccallum@redhat.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# METHOD should be one of:
# 0 = tpm_nvread via trousers
# 1 = nv_readvalue
METHOD=0

shopt -s nullglob
for question in /run/systemd/ask-password/ask.*; do
    # Check all questions in systemd-ask-password for a socket corresponding
    # to an encrypted device
    d=
    s=

    while read line; do
        case "$line" in
            Id=cryptsetup:*) d="${line##Id=cryptsetup:}";;
            Socket=*) s="${line##Socket=}";;
        esac
    done < "$question"

    # If the device isn't cryptsetup or a socket wasn't found, pass
    [ -z "$d" -o -z "$s" ] && continue

    # If using trousers
    if [[ $METHOD -eq 1 ]]; then
      # At this point, begin setup for tcsd
      # tcsd requires a user 'tss' and the /var/lib/tpm folder exist
      echo tss:x:100:100:TSS:/:/sbin/nologin >> /etc/passwd
      mkdir -p /var/lib/tpm
      # Create the RAMFS to hold the key in transit
      mkdir -p /mnt/ramfs
      mount -t tmpfs -o size=1m tmpfs /mnt/ramfs
      if [[ $? -ne 0 ]]; then
        echo "Mounting RAMFS failed."
        exit 2
      fi
      # Start trousers
      tcsd
      # Read data from specified index into ramfs
      tpm_nvread -i 1 -f /mnt/ramfs/key
      # tcsd may sometimes crash on the first read; if so, tpm_nvread returns 255
      # restart tcsd and try again, after which the command should succeed.
      if [[ $? -ne 0 ]]; then
        tcsd
        tpm_nvread -i 1 -f /mnt/ramfs/key
      fi
      # Store key
      pt="`cat /mnt/ramfs/key`"
      # Unmount the RAMFS
      umount /mnt/ramfs
    # Else we are using nv_readvalue
    else
      pt="`nv_readvalue -ix 1 -sz 64 -a`"
    fi
    # Send key to systemd-ask-password socket
    echo -n "+$pt" | nc -U -u --send-only "$s"
done
