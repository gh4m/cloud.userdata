#  VPS cloud.userdata.scripts

# Multi-node WireGuard VPN network exiting on an VPS provider VM. No commercial VPN provider is used.

The scripts in this repo are to setup a the wireguard VPN server in the VPS Provider Network section of the diagram below.

The script in userdata/ folder is used in the VPS launch (currently only an AWS userdata script exists). This git repo is cloned during launch and the scripts in the bash folder are executed. The config/ folder provides client server network settings for each instance of a multinode VPN network that is configured. The setup here is intended to allow the VPS provider hosting the wire-general VPN server to be swapped out easily, with runtime scripts to rebuild the wg.conf on the local VPN server with the new cloud VPN servers public and preshared keys.

Clients on the local home network connect to the local VPN server, wire-general in the diagram. Wire-general on local home network creates wireguard VPN tunnel to the wire-general host on the VPS provider. The VPN server on the VPS provider is running DNSCrypt-Proxy. The scripts insure all DNS queries use this proxy.

The setup is intended to support multiple independed wireguard VPN tunnels (multiple instances of the wiregaurd network in the diagram below) on the same home ISP network (same hostname local and cloud servers, but different domain name). With this you can have one set of clients using wireguard VPN network one exiting AWS US and another set of clients using a different wireguard VPN network exiting AWS in Europe.

The phone uses wireguard VPN to access the internet and to access local reasources on the local home network such as nextcloud.

![Alt text](docs/wireguard-network-diagram.drawio.png?raw=true "Multi-node VPN Newtrk Diagram")

