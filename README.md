#  cloud.userdata.scripts

The scripts in this repo are to setup a the wireguard VPN server as shown in the VPS Provider Network section of the diagram below.

The script in userdata folder is added to the VPS launch (currently only a AWS userdata script exists). This git repo is cloned druing launch and the scripts in the bash folder are executed. The config folder provides client server network settings.

![Alt text](docs/wireguard-network-diagram.drawio.png?raw=true "Multi-node VPN Newtrk Diagram")

