#!/bin/bash
# download mfit 
echo "--- Download Mfit section --"
curl -O "https://mfit-release.storage.googleapis.com/$(curl -s https://mfit-release.storage.googleapis.com/latest)/mfit"
chmod +x mfit


echo "--- VCenter info section ---"
# Vsphere users
echo "write Vsphere URL"
read VSPHERE_URL
echo "write Vsphere user with rights Guest operation modifications, Guest operation program execution, and Guest operation queries"
read VSPHERE_USER
echo "write password"
read -s VSPHERE_PWD


echo "--- OS users section -------"
# OS level users
declare -a creds_array
until [[ "$OS_USER" == "quit"  ]]
do
echo "write OS user with admin/sudoer rights on the target OS, enter quit if done writing the users"
read OS_USER
if [[ "$OS_USER" == "quit"  ]]
        then
             echo "quit detected"
                 break
        fi
echo "write password for user $OS_USER"
read -s OS_PWD
creds_array+=("$OS_USER;$OS_PWD")
done


echo "--- Install powershell section ---"
# Add MS repos for powershell (govc can’t get the VM IDs apparently)

if grep packages.microsoft.com /etc/apt/sources.list /etc/apt/sources.list.d/*
then
echo "MS repository already declared" 
else
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
sudo apt-get update 
sudo apt-get install -y powershell
fi

echo "--- Assessment starting ---"
cat <<EOF >get_vm_ids.ps1
Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force
Connect-VIServer -Server 172.16.10.2 -User 'administrator@psolab.local' -Password 'ps0Lab!admin' -Force
Get-VM | Select Id
EOF


./mfit discover vsphere --url https://$VSPHERE_URL -u $VSPHERE_USER -p $VSPHERE_PWD -i

for current_vm_id in $(pwsh -File get_vm_ids.ps1 | grep 'vm-' | sed 's/^.*VirtualMachine-//g'); do

  echo "---- collecting data for the VM Id $current_vm_id -------"
  for current_credential in "${creds_array[@]}";
  do
    CURRENT_OS_USER=$(echo $current_credential | awk -F ';' '{print $1}')
    CURRENT_OS_PWD=$(echo $current_credential | awk -F ';' '{print $2}')
    echo "--------- Using user $CURRENT_OS_USER ---------------"
    ./mfit discover vsphere guest $current_vm_id --url https://$VSPHERE_URL -u $VSPHERE_USER -p $VSPHERE_PWD -i --vm-user $CURRENT_OS_USER --vm-password $CURRENT_OS_PWD
  done

done

unset creds_array
