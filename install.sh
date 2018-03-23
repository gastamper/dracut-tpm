#!/bin/bash

error_out() {
  echo "clevis-dracut-tpm requires one of trousers/tpm-tools or nv_readvalue."
  echo "To install trousers/tpm-tools, run 'yum install trousers tpm-tools'"
  echo "To use nv_readvalue, consult http://github.com/gastamper/dracut-tpm"
  exit 2
}

if [ -z $1 ]; then
  echo "Syntax: '$0 <option>' where option is one of:"
  echo "0 - trousers/tpm-tools"
  echo "1 - nv_readvalue"
  exit 2
fi

echo "Checking system setup..."
if [ ! -f /usr/bin/ncat ]; then
  echo "Couldn't find /usr/bin/ncat"
  error_out
fi

case $1 in
  "0"*)
  if [ ! -f /usr/sbin/tcsd ]; then
    echo "tcsd not found."
    error_out
  elif [ ! -f /usr/sbin/tpm_nvread ]; then
    echo "tpm_nvread not found."
    error_out
  elif [ ! -f /usr/sbin/tpm_nvwrite ]; then
    echo "tpm_nvwrite not found."
    error_out
  elif [ ! -f /usr/sbin/tpm_nvdefine ]; then
    echo "tpm_nvdefine not found."
    error_out
  fi
  # nv-hook is distributed set to METHOD=0, so no need to 'sed' it
  sed -i '/METHOD=1/c\METHOD=0' nv-hook.sh
  # Ensure no incidence of nv_readvalue left over
  sed -i 's/inst_multiple.*/inst_multiple nc \/etc\/hosts tcsd tpm_nvread/g' module-setup.sh
  ;;
  "1"*)
  if [ ! -f /usr/bin/nv_readvalue ]; then
    echo "Could not find nv_readvalue in /usr/bin"
    error_out
  fi
  sed -i '/METHOD=0/c\METHOD=1' nv-hook.sh
  # Ensure no incidence of trousers/tpm_nvread left over
  sed -i 's/inst_multiple.*/inst_multiple nc nv_readvalue/g' module-setup.sh
  ;;
  *)
   error_out
  ;;
esac

if [ ! -d /usr/lib/dracut/modules.d/50dracuttpm ]; then
  echo "Creating module directory in /usr/lib/dracut/modules.d/50dracuttpm"
  mkdir -p /usr/lib/dracut/modules.d/50dracuttpm
fi
echo "Installing nv-hook.sh"
cp ./nv-hook.sh /usr/lib/dracut/modules.d/50dracuttpm
echo "Installing module-setup.sh"
cp ./module-setup.sh /usr/lib/dracut/modules.d/50dracuttpm

echo "Regenerating initramfs via 'dracut -f'"
dracut -f
if [ $? -eq 0 ]; then
  echo "Install done"
else
  echo "Error occurred recreating initramfs with dracut"
fi
