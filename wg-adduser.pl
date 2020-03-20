#!/usr/bin/perl

use strict;
use warnings;
use FindBin;

our $dev;
our $endpoint;
our $dns;
our $localSubNets;
my $cfgFile = "./add-client.conf";

unless (my $ret = do $cfgFile) {
  die "couldn't parse $cfgFile: $@" if $@;
  die "couldn't do $cfgFile: $!"    unless defined $ret;
  die "couldn't run $cfgFile"       unless $ret;
}

my $email = $ARGV[0] or do {
  print "$0 email\@address 'commen'\n";
  exit 1;
};

my $comment = $ARGV[1] // 'no comment';

sendMail($email,$comment);


sub getCfg {
  my %cfg;
  my $sec;
  my %addrMap;
  open my $fh, "</etc/wireguard/${dev}.conf";
  while (<$fh>){
    chomp;
    /^\s*\[(.+)\]\s*$/ && do {
        $sec = {};
        push @{$cfg{$1}},$sec;
        next;
    };
    /^\s*(\S+)\s*=\s*(.+?)\s*$/ && do {
        $sec->{$1} = $2;
        if ($1 eq 'AllowedIPs') {
            $addrMap{$2} = 1;
        }
        next;
    };
  }
  $cfg{addrMap} = \%addrMap;
  return \%cfg;
}

sub makeIp {
  my $cfg = shift;
  my ($addr) = ($cfg->{Interface}[0]{Address} =~ /(\S+)\.\d+\//);
  
  for (10..512) {
    my $ip = $addr.'.'.$_;
    next if $cfg->{addrMap}{$ip.'/32'};
    return $ip;
  }
}

sub makePrivKey {
  my $key = `wg genkey`;
  chomp($key);
  return $key;
}

sub makePubKey {
  my $privKey = shift;
  my $key = `echo $privKey|wg pubkey`;
  chomp($key);
  return $key;
}


sub addClient {
  my $email = shift;
  my $comment = shift;
  my $cfg = getCfg();
  my $key = makePrivKey();
  my $pub = makePubKey($key);
  my $pubSrv = makePubKey($cfg->{Interface}[0]{PrivateKey});
  my $ip = makeIp($cfg);
  open my $fh, ">>/etc/wireguard/${dev}.conf";
  print $fh <<CONF_END;
# $email / $comment
[Peer]
PublicKey = $pub
AllowedIPs = $ip/32
CONF_END
  close $fh;
  my $tmp = "/tmp/wg.conf.$$";
  system "wg-quick strip $dev > $tmp && wg addconf $dev $tmp && rm $tmp";
  return <<CONF_END
# $email / $comment
[Interface]
Address = $ip
PrivateKey = $key
DNS = $dns

[Peer]
PublicKey = $pubSrv
Endpoint = $endpoint
AllowedIPs = $localSubNets
PersistentKeepalive = 21 
CONF_END
}

sub sendMail {
  my $email = shift;
  my $comment = shift;
  
  my $conf =addClient($email,$comment);
  my $tmp = "wireguard.conf";
  open my $fh, ">$tmp";
  print $fh $conf;  
  close $fh;
  my $qr = `cat <<END|qrencode -o - -t svg|base64\n$conf\nEND\n`;
  
  open my $mh, '|-','mutt','-eset content_type=text/html','-eset send_charset=utf-8','-sWireguard VPN Configuration','-a'.$tmp,'--',$email;
  print $mh <<MAIL_END;
<html>
<head></head>
<body>
<p>Dear $email</p>

<p>This is your vpn configuration for accessing ${endpoint}.</p>

<ol>
<li>Install a Wireguard <a href="https://www.wireguard.com/install">client</a>.</li>
<li>Add the config file attached to this message</li>
</ol>

<p>Your Wireguard Configuration as a QR Code, readable by mobile Wireguard clients</p>

<div>
   <img style="image-rendering: crisp-edges;width: 300px;max-width: 100%"src="data:image/svg+xml;base64,$qr"/>
</div>

<p>enjoy!</p>
</body>
</html>
MAIL_END
  close $mh;
  unlink $tmp;
}