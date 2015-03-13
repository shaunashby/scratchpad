#!/bin/bash
##############################################################################
# Script de corrections de vulnerabilites XenServer
# PG le 08.10.13
##############################################################################

#arret des services inutiles
echo "arret des services"
chkconfig atd off


/etc/init.d/atd stop

#modification /etc/ssh/sshd_config
echo "modification de sshd"
sed -i -e 's/#IgnoreRhosts yes/IgnoreRhosts yes/' /etc/ssh/sshd_config
sed -i -e 's/#RhostsRSAAuthentication no/RhostsRSAAuthentication no/' /etc/ssh/sshd_config
sed -i -e 's/#HostbasedAuthentication no/HostbasedAuthentication no/' /etc/ssh/sshd_config
sed -i -e 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
#sed -i -e 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
echo "Ciphers aes256-cbc,aes128-cbc" >> /etc/ssh/sshd_config
/etc/init.d/sshd restart

#single user mode:
echo "modification du mode single user"
echo "~~:S:wait:/sbin/sulogin" >>/etc/inittab

#utiliser /etc/shadow
#echo "modification de /etc/shadow"
#sed -i -e 's/password    sufficient    pam_unix.so try_first_pass use_authtok nullok md5/password    sufficient    pam_unix.so try_first_pass use_authtok nullok md5 shadow/' /etc/pam.d/system-auth
#/usr/sbin/pwconv
#sed -i -e 's/root:.*:0:0:/root:x:0:0:/' /etc/passwd


#historique passwords
echo "modification historique des passwords"
touch /etc/security/opasswd
chmod 600 /etc/security/opasswd
chown root: /etc/security/opasswd
echo "password required pam_unix.so remember=10" >> /etc/pam.d/system-auth

#gestion des erreurs d'authentification
echo "gestion des erreurs d'authentification"
echo "auth required pam_tally.so deny=3 unlock_time=300 even_deny_root_account" >> /etc/pam.d/system-auth
echo "account required pam_tally.so" >> /etc/pam.d/system-auth

#gestion du password
echo "modification de la gestion du password"
sed  -i -e 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS   90/' /etc/login.defs
sed  -i -e 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS   7/' /etc/login.defs
sed  -i -e 's/PASS_MIN_LEN\t5/PASS_MIN_LEN   9/' /etc/login.defs
sed  -i -e 's/PASS_WARN_AGE\t7/PASS_WARN_AGE   14/' /etc/login.defs

#suppression communication sur le port 80
echo "modification ouverture port 80"
sed -i -e 's/-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT//' /etc/sysconfig/iptables
service iptables restart

#reseau
echo "modification de sysctl.conf"
cat >> /etc/sysctl.conf <<EOF

#DFi
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
EOF
sysctl -p

#desactivation de la console
echo "modification login root en console"
sed -i -e 's/autologin root/autologin nobody/' /opt/xensource/libexec/run-boot-xsconsole

#suppression de la page html
echo "modification page html"
echo "<html></html>">/opt/xensource/www/Citrix-index.html

#login automatique en console:
echo "modification login auto en console"
sed -i -e 's/-f root/-p/' /usr/lib/xen/bin/dom0term.sh

#login automatique en console:
echo "Securetty"
echo "pts/0">>/etc/securetty

