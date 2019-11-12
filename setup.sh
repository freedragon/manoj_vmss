#!/bin/bash

# create a folder for custom script and checkout code
cd ~
mkdir scripts
cd scripts

#install python  Dependencies
sudo apt update
sudo apt -y install python3-pip
pip3 install psutil
pip3 install bottle
pip3 install configparser

#Install and configure Telegraf
# download the package to the VM
# wget https://dl.influxdata.com/telegraf/releases/telegraf_1.8.0~rc1-1_amd64.deb
# install the package
# sudo dpkg -i telegraf_1.8.0~rc1-1_amd64.deb

# generate the new Telegraf config file in the current directory
# telegraf --input-filter cpu:mem --output-filter azure_monitor config > azm-telegraf.conf

# replace the example config with the new generated config
# sudo cp azm-telegraf.conf /etc/telegraf/telegraf.conf

#checkout code
git clone https://github.com/manojsingh/azvmscripts.git

#Start health probe job
cd azvmscripts
nohup ./health_probe_handler.py & echo $! > health-probe-pid.file &

# Schedule cron jobs
crontab crons.sh