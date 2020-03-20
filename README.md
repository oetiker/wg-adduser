# Wireguard account creation script

Now that everyone is doing home office, a no nonesense VPN system is super
helpful. Wireguard fits the bill perfectly for many of our customers.

To simplify account creation I have created a little perlscript. Here some
instructions to get everything going on an ubuntu system


## Setup Wireguard

1. install the wireguard module

```console
$ sudo add-apt-repository ppa:wireguard/wireguard
$ sudo apt update
$ sudo apt install wireguard qrencode perl curl mutt firehol
```

2. setup a configuration file for your wireguard interface `wg0`

```console
# cd /etc/wireguard
# chmod 700 .
# wget https://github.com/oetiker/wg-adduser/archive/master.zip
# unzip master.zip
# mv wg-adduser/* .
# rmdir wg-adduser
# cat <<CONFIG_END
[Interface]
# the address of your new VPN subnet
Address = 10.x.y.0/24
# this is the 'standard' wireguard port
ListenPort = 51819
# create a private key running `wg genkey`
PrivateKey = xxxx
CONFIG_END
```

3. edit the `wg-adduser.conf` to match your requirements

4. make wireguard start automatically

```console
$ sudo systemctl enable wg-quick@wg0.service 
$ sudo systemctl start wg-quick@wg0.service
```

5. make the firewall work

enable firehol in `/etc/default/firehol`
```
# To enable firehol at startup set START_FIREHOL=YES (init script variable)
START_FIREHOL=YES
# If you want to have firehol wait for an iface to be up add it here
WAIT_FOR_IFACE="wg0"
```

configure firehol in `/etc/firehol/firehol.conf`

```
LOCALIF=eno1
VPNNET=192.168.73.0/24
LOCALNET=192.168.42.0/24
GWIP=192.168.42.2

version 6

### nat all trafic not going to our local network since our
### router would not route the vpn trafic to the outside world
### otherwhise
ipv4 snat to $GWIP outface $LOCALIF src $VPNNET dst not $LOCALNET

### Accept all client traffic on any interface
interface wg0 wg-if
        policy accept

interface $LOCALIF ${LOCALIF}-if
        policy accept

router4 wg2lan inface wg0 outface eno1
        policy accept
```

obviously your firewall requirements may be more complex, so be sure to read
up on www.firehol.org

5. start the firewall

```console
# firehol try
```

## Create VPN Accounts

This command creates an account and sends an
invitation email. Make sure email works on the system.

```console
# cd /etc/wireguard
# ./wg-adduser.pl some@email-adderss "comment"
```


