#!/bin/bash

# create a folder for custom script and checkout code
cd ~
mkdir scripts
cd scripts

#install python  Dependencies
apt update
apt -y dist-upgrade
apt update
apt -y install python3-pip
pip3 install psutil bottle configparser

#checkout code
git clone https://github.com/manojsingh/azvmscripts.git

#Start health probe job
cd azvmscripts
chmod +x *.py
nohup ./health_probe_handler.py & echo $! > health-probe-pid.file &

# Schedule cron jobs
crontab crons.sh