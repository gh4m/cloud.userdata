# Multi-node WireGuard VPN network exiting from a VPS provider VM. No commercial VPN provider is used.

[note this repo is "in-development", expect mistakes, feedback welcome. I am still exporing wireguard and how it works]

The scripts in this repo are to setup the wireguard VPN server shown in the VPS Provider Network section of the diagram below. This is currently VPN network I have setup as a personal project to expplore alternatives to using a commercial VPN provider.

The script in userdata/ folder is used in the VPS launch (currently only an AWS userdata launch script exists). This git repo is cloned during launch and the scripts in the bash/ folder are executed. The config/ folder provides client and server host network settings for each instance of the multi-node VPN network that is to be setup. The scripts in this repo are intended to allow the VPS provider hosting the wire-general VPN server to be swapped out easily, with runtime scripts available to rebuild the wg.conf on the local VPN server for the new cloud VPN server's public and preshared keys.

Clients on the local home network connect to the local VPN server, called wire-general in the diagram. Wire-general on local home network creates wireguard VPN tunnel to a same named host wire-general on the VPS provider. The VPN server on the VPS provider is running DNSCrypt-Proxy. The scripts insure all DNS queries use this proxy.

The setup is intended to support multiple independent wireguard VPN tunnels (multiple instances of the wiregaurd network in the diagram below) in the same home ISP network (each instance with local and cloud server with same hostname, but different domain name). With multiple instances, there can be one set of clients using a wireguard VPN network exiting AWS in a US city and another set of clients using a different wireguard VPN network exiting AWS in a city in Europe for example.

The phone uses wireguard VPN to both access the internet and to access local resources on the local home network, such as nextcloud.

![Alt text](docs/wireguard-network-diagram.drawio.png?raw=true "Multi-node VPN Newtrk Diagram")

