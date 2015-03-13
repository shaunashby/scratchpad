#!/bin/sh
#____________________________________________________________________
# File: hypervisor-fixup.sh
#____________________________________________________________________
#
# Author:  <sashby@dfi.ch>
# Created: 2015-03-10 23:21:31+0100
# Revision: $Id$
# Description: Script to run on a new hypervisor to apply PCI hardening.
#
# Copyright (C) 2015 
#
#
#--------------------------------------------------------------------
echo "Patching on ${HOSTNAME}:"
echo "- disabling access to port 80:"
sed -i -e 's/-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT//' /etc/sysconfig/iptables
echo "- restarting iptables:"
service iptables restart

# Fix up the XAPI cipher list for stunnel:
sed -i -e 's/ciphers = !SSLv2:RSA+AES256-SHA:RSA+AES128-SHA:RSA+RC4-SHA:RSA+RC4-MD5:RSA+DES-CBC3-SHA/ciphers = AES128+EECDH:AES128+EDH:AES256+EECDH:AES256+EDH:HIGH:3DES:!PSK:!MD5:!aNULL:!eNULL/' /etc/init.d/xapissl

# Restart XAPI to regenerate /etc/xensource/xapi-ssl.conf for stunnel:
service xapi restart

# Fix the time setup. Use ntp.algo.internal for NTP:
echo "- fixing NTP on ${HOSTNAME}:"
if [[ -f /etc/ntp.conf ]]; then
    # Replace the ntp server with ntp.algo.internal:
    sed -i -e 's/server 195.70.9.36/server 195.70.13.171/' /etc/ntp.conf
    sed -i -e 's/server 195.70.9.20//' /etc/ntp.conf

    # Disable monitor (vulnerability fixup):
    echo "disable monitor" >> /etc/ntp.conf

    # Enable ntpd by default:
    echo "-- enabling ntpd"
    chkconfig ntpd on

    echo "-- cleaning unneeded cron.d NTP entries"
    [[ -f /etc/cron.d/ntpd ]] && rm -f /etc/cron.d/ntpd
    [[ -f /etc/cron.d/ntpdate ]] && rm -f /etc/cron.d/ntpdate

    echo "-- starting the ntpd service"
    service ntpd start
else
    echo "**** PROBLEM: no ntp.conf on this system..bye."
    exit 1
fi

# Fix SNMP community name:
sed -i -e 's/rocommunity public/rocommunity dfi-algo/' /etc/snmp/snmpd.conf

# Add the internal Algo proxy for accessing the outside world>
sed -i -e 's/installonly_limit = 5/installonly_limit = 5\n# Use webproxy.algo.internal to exit to the internet:\nproxy=http:\/\/10.20.164.22:3128/' /etc/yum.conf

# 
export WORKDIR=/root/pci2015

# Start in workingdir, creating it first if necessary:
[[ ! -d ${WORKDIR} ]] && mkdir -p ${WORKDIR}
cd ${WORKDIR}

# Set access via proxy for wget:
export http_proxy=http://10.20.164.22:3128
export https_proxy=http://10.20.164.22:3128

# Get the EPEL repository and install it:
echo "- installing EPEL repository RPM:"
wget http://dl.fedoraproject.org/pub/epel/5/$(uname -i)/epel-release-5-4.noarch.rpm
rpm -ivh ./epel-release-5-4.noarch.rpm

# Get the Puppetlabs repositories and install them:
echo "- installing Puppetlabs repository RPM:"
wget https://yum.puppetlabs.com/el/5/products/i386/puppetlabs-release-5-7.noarch.rpm
rpm -ivh ./puppetlabs-release-5-7.noarch.rpm

# Set up SSL certificate for CA:
[[ ! -d /etc/openldap/cacerts ]] && mkdir -p /etc/openldap/cacerts
echo "- saving existing certificate:"
[[ -f /etc/openldap/cacerts/ca.crt ]] && mv /etc/openldap/cacerts/ca.crt /etc/openldap/cacerts/ca.crt.`date "+%Y%m%d_%H%M%S"`
echo "- installing CA certificate:"
pushd /etc/openldap/cacerts
cat > ca.crt <<EOF
-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIJAPhGIJoOpvmVMA0GCSqGSIb3DQEBBQUAMG0xCzAJBgNV
BAYTAkNIMQ8wDQYDVQQIDAZHZW5ldmExDzANBgNVBAcMBkdlbmV2YTEUMBIGA1UE
CgwLREZpIFNlcnZpY2UxDTALBgNVBAsMBE5vbmUxFzAVBgNVBAMMDmRmaS1hbGdv
LmxvY2FsMCAXDTEzMDMxMTEyMjQyNVoYDzIxMTMwMjE1MTIyNDI1WjBtMQswCQYD
VQQGEwJDSDEPMA0GA1UECAwGR2VuZXZhMQ8wDQYDVQQHDAZHZW5ldmExFDASBgNV
BAoMC0RGaSBTZXJ2aWNlMQ0wCwYDVQQLDAROb25lMRcwFQYDVQQDDA5kZmktYWxn
by5sb2NhbDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOOD2DxldOB1
1am2sOw+Tt3gVprPfln8Wir2K9klDZ12h7U50SECBPF7003CUBndS+7vsC7hpSHr
OYLWeYu2321brKFRRGAeWyxeeyVPMetWeqoQcDXjjeTtGRVxlQVdp7LKSwt+XITw
pJR9vVn5Bl+RnwIHUlIvgKg0oJa7Pxq9ucLAlWqVbdhy4zGK4wmgVSDYw4PLZT6Q
nk3j0YcorMvKYFxF5PArzvdVLaQqn8KpbRD9nYajE7kIZziMYKvcWWikxLGudkXv
scxWrcLbD9PyH4AAM3CL+jfDWfsEstrazLLLlDrVeA6Fm2XT5mhowKfooZUujf+Y
gySBOOZR6z0CAwEAAaNQME4wHQYDVR0OBBYEFArihyLX0LQqpR+ne/SQCkfCAwIf
MB8GA1UdIwQYMBaAFArihyLX0LQqpR+ne/SQCkfCAwIfMAwGA1UdEwQFMAMBAf8w
DQYJKoZIhvcNAQEFBQADggEBAGmexLAxMdFRTVykOuWJlgl2iJpjg7K5UlE9N5Es
nZXa83r7gFk0SrM/HC90S3VGGWhFqxNme8DGVTDeYFpNjnaUb76LqaADivVNZuPQ
3Mv0D8J7V5luuuHD4rUM9KsdxbtUBexgenm24UD5asFSaK/PiUNkB34A3y8iku3F
gEuX5CItXJNsYPNTosGBvwu1ajPMITN2Hi6wVeOrvFa3rJWv8Q7Il1wzNiZATtnx
sG2xTY6ozj5FclXr/wYOXeVB1AxK+fwL40xj+AZAzNGBrPIH3MyiuEIJ025N7tOu
KYSY0ZBv0HGZec62TKjmEIaCGHLEUTpXfTriYoH3ywFSDj8=
-----END CERTIFICATE-----

EOF

# Create a hash link to the certificate (although for simplicity we will just
# use ca.crt as the cacertfile name in ldap.conf etc):
echo "- hashing the SSL CA certificate:"
ln -s ca.crt `openssl x509 -hash -noout < ca.crt`.0

# Install SSSD and authconfig, making sure that the Citrix repository is disabled and
# Centos base is enabled:
echo "- installing RPMs for SSSD and authconfig:"
yum --disablerepo=citrix --enablerepo=base install -y sssd authconfig

# Enable auth using SSSD:
if [[ -e /usr/sbin/authconfig ]]; then 
    echo "- running authconfig to set up PAM and SSSD:"
    authconfig --enablesssd \
	--enablesssdauth \
	--enablemkhomedir \
	--ldapserver="10.23.51.51" \
	--ldapbasedn="ou=administrators,dc=dfi,dc=dfi-algo,dc=local" --updateall --enableldaptls
else
    echo "**** Couldn't run authconfig - no executable found. Bye."
    exit 1
fi

# Install SSSD configuration in /etc/sssd:
if [[ -d /etc/sssd ]]; then
    if [[ -f /etc/sssd/sssd.conf ]]; then
	echo "- backing up /etc/sssd/sssd.conf:"
	mv /etc/sssd/sssd.conf /etc/sssd/sssd.conf.`date "+%Y%m%d_%H%M%S"`
    fi
    echo "- installing new sssd.conf:"
cat > /etc/sssd/sssd.conf <<EOF
[domain/default]
cache_credentials = True
ldap_search_base = ou=administrators,dc=dfi,dc=dfi-algo,dc=local
krb5_realm = EXAMPLE.COM
krb5_server = kerberos.example.com
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_chpass_uri = ldap://10.23.51.51/
ldap_uri = ldap://10.23.51.51/
ldap_tls_cacertdir = /etc/openldap/cacerts
ldap_tls_cacert = /etc/openldap/cacerts/ca.crt
ldap_id_use_start_tls = True
#tls_reqcert = demand
#debug_level = 7

[sssd]
config_file_version = 2
reconnection_retries = 3
sbus_timeout = 30

services = nss, pam

domains = default

[nss]
filter_groups = root,nobody
filter_users = root,nobody
reconnection_retries = 3

[pam]
reconnection_retries = 3
EOF

fi

# Make sure permissions are correct or the daemon won't start:
chmod 0600 /etc/sssd/sssd.conf

# Back up /etc/ldap.conf and /etc/nsswitch.conf:
if [[ -f /etc/ldap.conf ]]; then
    echo "- backing up /etc/ldap.conf:"
    mv /etc/ldap.conf /etc/ldap.conf.`date "+%Y%m%d_%H%M%S"`
fi

if [[ -f /etc/nsswitch.conf ]]; then   
    echo "- backing up /etc/nsswitch.conf:"
    mv /etc/nsswitch.conf /etc/nsswitch.conf.`date "+%Y%m%d_%H%M%S"`
fi

echo "- creating /etc/ldap.conf:"
cat > /etc/ldap.conf <<EOF
uri ldap://10.23.51.51/
ssl start_tls
tls_cacertfile /etc/openldap/cacerts/ca.crt
tls_checkpeer no
pam_password md5
sudoers_base ou=SUDOers,dc=dfi-algo,dc=local
EOF

echo "- creating /etc/nsswitch.conf:"
cat > /etc/nsswitch.conf <<EOF
# PCI
passwd:     files sss
shadow:     files sss
group:      files sss

#hosts:     db files nisplus nis dns
hosts:      files dns

# Example - obey only what nisplus tells us...
#services:   nisplus [NOTFOUND=return] files
#networks:   nisplus [NOTFOUND=return] files
#protocols:  nisplus [NOTFOUND=return] files
#rpc:        nisplus [NOTFOUND=return] files
#ethers:     nisplus [NOTFOUND=return] files
#netmasks:   nisplus [NOTFOUND=return] files

bootparams: nisplus [NOTFOUND=return] files

ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files

netgroup:   files sss

publickey:  nisplus

automount:  files sss
aliases:    files nisplus

# Enable sudoers:
sudoers: ldap files

EOF

# Modify PAM configuration for system-auth-ac and sshd:
echo "- fixing up PAM for ssh, using SSSD (and LDAP):"
pushd /etc/pam.d
for pam in system-auth-ac sshd; do
    if [[ -f /etc/pam.d/${pam} ]]; then
	mv /etc/pam.d/${pam} /etc/pam.d/${pam}.`date "+%Y%m%d_%H%M%S"`
    fi
    # Install new PAM files for auth and for ssh:
    case ${pam} in
	sshd)
cat > /etc/pam.d/sshd <<EOF	    
#%PAM-1.0
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        sufficient    pam_sss.so use_first_pass
auth        optional      pam_lsass.so use_first_pass
auth        required      pam_deny.so

session     optional      pam_keyinit.so force revoke
session     required      pam_limits.so
session     optional      pam_mkhomedir.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     required      pam_loginuid.so
session     optional      pam_sss.so
session     optional      pam_lsass.so

account    required       pam_nologin.so
account    [default=bad success=ok user_unknown=ignore] pam_sss.so
account    optional       pam_lsass.so unknown_ok
# Start of list of allowed AD groups and users
account    optional pam_succeed_if.so user ingroup DFINET\systeme
# End of list of allowed AD groups and users
account     required      pam_unix.so
EOF
	    ;;
	system-auth-ac)
cat > /etc/pam.d/system-auth-ac <<EOF	    
#%PAM-1.0
auth        required      pam_env.so
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 500 quiet
auth        sufficient    pam_sss.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so broken_shadow
account     sufficient    pam_succeed_if.so uid < 500 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so

password    requisite     pam_cracklib.so try_first_pass retry=3
password    sufficient    pam_unix.so md5 nullok try_first_pass use_authtok
password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     optional      pam_mkhomedir.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_sss.so
EOF
	    ;;
	*)
    esac
done

# Enable SSSD by default and start the daemon:
echo "- enabling SSSD by default and starting the service."
chkconfig sssd on
service sssd start

# Restart SSH to make sure it picks up changes
# related to SSSD:
echo "- restarting SSHD to pick up PAM changes:"
service sshd restart

# Make sure that the accounts are shadow-enabled:
[[ ! -f /etc/shadow ]] && /usr/sbin/pwconv

# Install OSSEC RPMs and dependencies:
echo "- installing OSSEC:"
yum --disablerepo=citrix --enablerepo=base install -y inotify-tools
rpm -ivh http://10.23.50.30/ossec-hids-2.8.1-47.el5.art.i386.rpm
rpm -ivh http://10.23.50.30/ossec-hids-client-2.8.1-47.el5.art.i386.rpm

echo "- configuring OSSEC:"

export OSSEC_HV_PROFILENAME="hv-dfi"

if [[ ! -f ${WORKDIR}/keys.txt ]]; then
cat > ${WORKDIR}/keys.txt <<EOF
AlgoXen01	10.23.80.11	213	MjEzIEFsZ29YZW4wMSAxMC4yMy44MC4xMSA5NjUwOWM4ZDIxNDZkNDc3OGY0NzE3MDczNjRlYTE5MDg3MDUzNzU5NzBhYWRhNzVkYmNkOTVjYWU1ZjQ1MDA2
AlgoXen02	10.23.50.102	214	MjE0IEFsZ29YZW4wMiAxMC4yMy41MC4xMDIgN2NjMDZjMmMwNzczYjIxMjNjNTQwZGMzMTNhZWMyNDgwNDA1ODYxMmFmZjcxMGE1MzE0ODBjZmQ0NjQ5ZDQ3MQ==
AlgoXen03	10.23.50.103	215	MjE1IEFsZ29YZW4wMyAxMC4yMy41MC4xMDMgZTNiMjY1ZjA0MmFhN2VkYTIzMjBmOGYyZjljMjYyYzNkZTBjNDFjMjAyMjIyOTJhYmUxYWNkNjUwMDNjZThjMg==
AlgoXen04	10.23.50.104	216	MjE2IEFsZ29YZW4wNCAxMC4yMy41MC4xMDQgY2QzMWZjMmI3ODUwODdjMThhMzc1ZGZjNDkzM2VmODYyMWYwOWFkZWZjYTRjZWVlMzEzYWM2YTQ1ZjU4M2YwYw==
AlgoXen05	10.23.80.15	217	MjE3IEFsZ29YZW4wNSAxMC4yMy44MC4xNSBjZGY3MzIxY2I2YmVlNTBjMGU1MjA4OTVkMTA3NWMyYzNhZWE3MmE2MWQ3N2ZhNmVjNzA0ZTA3OTkyZmYyN2Q3
AlgoXen06	10.23.50.106	218	MjE4IEFsZ29YZW4wNiAxMC4yMy41MC4xMDYgNGQzM2VlZTkxMTNiOGYyMWE5NWU2ZDVhYWU4Y2NlNTViMmRjM2MwM2MwMjg1MzJjZDAyOTAxMzcxM2M1YTRiOA==
AlgoXen07	10.23.50.107	219	MjE5IEFsZ29YZW4wNyAxMC4yMy41MC4xMDcgZDk3NzJkNjI4OTEyZThiMDExYjFkMDc1YjVkY2VjMWM0YzAwYWNlODAwNTNkYmY1OTI2MTRkODIyNzNmNDBhMw==
AlgoXen08	10.23.50.108	220	MjIwIEFsZ29YZW4wOCAxMC4yMy41MC4xMDggZDJkYTM1NDhkOGZhMzc0YjNlNTc2ODMyYTZhNmNkMzBjMjQ1MDU0ODRjNTExNTM4MDYzNDgzZGVmNTk4OTBhMw==
AlgoXen09	10.23.50.109	221	MjIxIEFsZ29YZW4wOSAxMC4yMy41MC4xMDkgNWM0ZmQ3MTIxMTE5MTRmYjdkZWNlZmVlYzA2YWZiNzUzN2FmYzIwYjNhYjQ0ZjAwN2NmNzY4ZDE0MjNlYzcyYQ==
AlgoXen10	10.23.50.110	222	MjIyIEFsZ29YZW4xMCAxMC4yMy41MC4xMTAgMDQ0M2JlYzI5NmM2NDI3MTljN2QwNTY3NGRlMTIwNTZkYTJkNzZlNDU1M2IwMzU2ZDhjNzQ0YzY5MWQ1NWUzNQ==
AlgoXen11	10.23.50.111	223	MjIzIEFsZ29YZW4xMSAxMC4yMy41MC4xMTEgNjNkNzgxMWE5OTRjYjM1NjAzYzBiNjk5MmUyNGUxZGRlMDhhZGZiNjg2MjRjM2Y5ZDAxMDg5YTIzY2Y4ZmMwZA==
AlgoXen12	10.23.50.112	224	MjI0IEFsZ29YZW4xMiAxMC4yMy41MC4xMTIgMDA4YTA1MThkNDAyNDE2OTAzZWU5MTZjYjRiMDE0MzFjZTYyYTRjMDBmYzU0ZTcwOTFmNzkyODgwMzlmYTczMQ==
AlgoXen13	10.23.50.113	225	MjI1IEFsZ29YZW4xMyAxMC4yMy41MC4xMTMgZjg2ODlmMDMxY2UzYjM2M2Y5NzI5YzYzYjA0OTY1YTA2ZmQ3ZGZhODU2NWI5NTJlYzEwOTRhMGI2N2FiOTI3Zg==
AlgoXen14	10.23.50.114	226	MjI2IEFsZ29YZW4xNCAxMC4yMy41MC4xMTQgMjAxYmIwMmY2MWM2YjgzYzU4YTllNjE1YmEyM2U1ZGFiMGUxZDhmM2RiZTVlMmFkZWQ2NjM0NDg4YWM0YTFlMQ==
AlgoXen15	10.23.50.115	227	MjI3IEFsZ29YZW4xNSAxMC4yMy41MC4xMTUgYmNlZWU3MTY3NzgzMzFmMjdiZmY1ZDlkYmM1ZWJkMDk4NmRiYzNjMWI3MmFlZDBiOWZiMWZmMWVlNzJkYTUzZg==
AlgoXen16	10.23.50.116	228	MjI4IEFsZ29YZW4xNiAxMC4yMy41MC4xMTYgYzMzNjAwOWYwMjVkZWE1MWU5MWJiNjQ3YzMwNzVlOTE2NDFlNjU4OTBlMGIzY2FlZWFhMDU1M2UyZTNhYzRmMg==
AlgoXen17	10.23.50.117	229	MjI5IEFsZ29YZW4xNyAxMC4yMy41MC4xMTcgNzI0NjI1YmQ3YjdjNzNiNmU0NDAxYWNjN2Y3ZTg3MTRjMDVkMzU1ZDBkMWI4NTM0NGZjZTNiNjE3ODE0YTEwNg==
AlgoXen18	10.23.50.118	230	MjMwIEFsZ29YZW4xOCAxMC4yMy41MC4xMTggZmU5NzY5M2E0NmU0ODdmNGEzZDc1ZjU0OTQ5OWYxZDI4Y2Q0MWYxNzczNGJjZGY1YzkyNGM4NTA1ZDFmZDAyZg==
AlgoXen19	10.23.50.119	231	MjMxIEFsZ29YZW4xOSAxMC4yMy41MC4xMTkgNzFmMWFiNmQwOTUyYzVlYWY5OWI2ZmUxMGVhZjY3YmU2Y2JiMjJkNTkyNWJhODdlMDFmOWU4YWE5NGQyOWM3Zg==
AlgoXen20	10.23.50.120	232	MjMyIEFsZ29YZW4yMCAxMC4yMy41MC4xMjAgZjljNzcyMDEzMGMyY2M2ZTdiMDIzOWVlNDk4NDg5OGVmNmJjYWM3OTY5MGQzNzIyM2JiMGRhZjg5YzhjZmNjMg==
AlgoXen21	10.23.50.121	233	MjMzIEFsZ29YZW4yMSAxMC4yMy41MC4xMjEgNDU3M2Q1ZWZkMjRlYWYxYmJiNzA4MTRiNDgzNTgxYmYyMTdiYjVjZTE2M2E1ZTAwOTBlZTcwNGE3ODg3ODZkOQ==
AlgoXen22	10.23.50.122	234	MjM0IEFsZ29YZW4yMiAxMC4yMy41MC4xMjIgZTVmMDQ5NjBhYjE0NDM1ZDdkM2U4MTU3YjM5NzFhMDAxMjYzZGU4YTY3OWE4MGQ0MjQ5NzJiYzEyM2Y3NGRlMg==
AlgoXen23	10.23.50.123	235	MjM1IEFsZ29YZW4yMyAxMC4yMy41MC4xMjMgY2I3MzAzMGQyMmQyNGM4Y2ZjNGQzYTgxMWM0MDkzN2M0MWNlZGExNjQxN2YwMDI5MTI1MDk4NjFmZjQ4ODk2OQ==
AlgoXen24	10.23.50.124	236	MjM2IEFsZ29YZW4yNCAxMC4yMy41MC4xMjQgNTQwYjRkYzQwZGI3ZDdkNDdhNWRlYzNkNzI3NDFlY2U1NDc2ZmZjNTg3ODRmZTUzMzEwOGYzMTZmZTAyNGU2OA==
AlgoXen25	10.23.50.125	237	MjM3IEFsZ29YZW4yNSAxMC4yMy41MC4xMjUgNmYyZTdmNzMwY2VhODE4M2Y5ZWMzOGY0N2NmMDJiZGM2NTRmMWI5MmNkNzQ4MDg5ZjdjMTU3NzUzODc3Mzc2Ng==
AlgoXen26	10.23.50.126	238	MjM4IEFsZ29YZW4yNiAxMC4yMy41MC4xMjYgNTNhOThlOThkZWUxMjQwMjdjZWM1NTM4NWMwNjYxMDNkMWFjM2YwYjA2YTRjOWM0NzYwMzYxMmI2NDBjYzE2Mw==
AlgoXen27	10.23.50.127	239	MjM5IEFsZ29YZW4yNyAxMC4yMy41MC4xMjcgNjA3ZmRkNWNhOTkxMzlkNDk2YjBkODIzOGQ2ZGUwNWNjNjgzZjA0NGRiYjU3ZTZlZjRkNjA0OTc1MzQyNWVmMw==
AlgoXen28	10.23.50.128	240	MjQwIEFsZ29YZW4yOCAxMC4yMy41MC4xMjggMDFjMDAyNTQ1NWY4ODE4MmYwMWEwOTkyMDQxNmVhYmE2OTkyNmZhYTVlMzJjMzNlY2VmZmY5N2Q5NWQ5MDBhMA==
AlgoXen29	10.23.50.129	241	MjQxIEFsZ29YZW4yOSAxMC4yMy41MC4xMjkgNTE1MTkwNDAzZGQ4ZjNiMjJlNjBkMmVjYTkxZWFmZGFiMjAzZTUyNTEyYzM3ODNlYjliOTdhMmRiY2EyZmY1Yg==
AlgoXen30	10.23.50.130	242	MjQyIEFsZ29YZW4zMCAxMC4yMy41MC4xMzAgODdlNWYzNTQ1YTg2ODlkYjQ4MmEzNWQ3ODJhYjkzYWFlNzEwYWZlOGJhNDQzOWRhZDU5ZDBkMzRhMjYyOGYwMQ==
AlgoXen31	10.23.50.131	243	MjQzIEFsZ29YZW4zMSAxMC4yMy41MC4xMzEgMTEzOTU2MmMzMDk5MTA0NDJjNmEzYmYzZmUyMjg2NDhkODNkMDVjMzAzMjBjOTNiZjBmNGZjYzE2MjlkYmYxMg==
AlgoXen32	10.23.50.132	244	MjQ0IEFsZ29YZW4zMiAxMC4yMy41MC4xMzIgMjM5Mjk2ZTA1M2Q3MTk1Y2IyYmRiYzhlYTM5MTM3NGMyNDk3MjFhMDI5N2I1YjcxODNhYWFjZWU5MGNjNWZiYg==
AlgoXen33	10.23.50.133	245	MjQ1IEFsZ29YZW4zMyAxMC4yMy41MC4xMzMgOWU2NzZmMGRlNGZlOWFlM2M5MzE5NTk3OGQ2NDJjM2RlZGRmMTM1ZDAzYjJjMzUyMmNkZmRlYTA1ZDAwNzNiYg==
AlgoXen34	10.23.50.134	246	MjQ2IEFsZ29YZW4zNCAxMC4yMy41MC4xMzQgZDk0YjA0YjZkOTUyNTQyOTBjMWNhMWExNGVlNjQ5MDJlZjM3MjdmNDMyNmFkMDVkNGIzMTIxNmFkMzY3MzRlOQ==
AlgoXen35	10.23.50.135	247	MjQ3IEFsZ29YZW4zNSAxMC4yMy41MC4xMzUgMDRmYjlmNjIwZjFlMzdmNTJiNDUwYjA1MzA1ZTUwN2IwYTA3NDI0ZmQ0MGM4OWZlNDRhZjc5MGEyMjg2MjkwMg==
AlgoXen36	10.23.50.136	248	MjQ4IEFsZ29YZW4zNiAxMC4yMy41MC4xMzYgMjIyNDcyZTZiNmZjNTQ5NWE1ZmMzNGU5Yjg1N2U1YTkyNGU5MTVmNDZiMjMzN2FlNjE2NTk3NWIyZTZjODYwNw==
AlgoXen37	10.23.50.137	249	MjQ5IEFsZ29YZW4zNyAxMC4yMy41MC4xMzcgOTc0ODRjODYzMWZlNGM4ZTcxMTQyZWMzZTM1YmMwYzI0MDE5YmY1ZTNkMGRlMTIzZmVjNDAyZWJiYjZlMTAwNQ==
AlgoXen38	10.23.50.138	250	MjUwIEFsZ29YZW4zOCAxMC4yMy41MC4xMzggMGRmZjg3NWJkMzMyODBhYzAzNGZmY2YyMzRiMjJiZjdkNGZlZmQ1N2FmZGUxNmRhZThkNTA4ZGExZWNkNjc4ZA==
AlgoXen39	10.23.50.139	251	MjUxIEFsZ29YZW4zOSAxMC4yMy41MC4xMzkgNjU4NTdhMTU0YTg3ZTc1NDBiNjkyODUyZjVjMDhkODk5MDAzNWVlOGMxNWFmMDVmMTUyODczYTQ2YzBjY2Y5Yw==
AlgoXen40	10.23.50.140	252	MjUyIEFsZ29YZW40MCAxMC4yMy41MC4xNDAgNTJjN2NiYThkZjY2MGYyMjM2YzliMmEzM2YyYjc0NDQzMTNiNzNlYzg1YjM1ZTEzZjI1Yjk0ZDA3NGRkMzQwNA==
AlgoXen41	10.23.50.141	253	MjUzIEFsZ29YZW40MSAxMC4yMy41MC4xNDEgYTZkZDM2ODE0YTJkYzYzMGY2YWQ2NjMxYzIwZGUwODQzYWY0MTY3ZmNiNTUxMzEzNjg0MGYyMGVkZDcxZjY2Mw==
AlgoXen42	10.23.50.142	254	MjU0IEFsZ29YZW40MiAxMC4yMy41MC4xNDIgOTE4MzE3NDQ5N2U0NTBiOTBiYTYzNzU2MWY4YjViMzFlNzg3YTQ4ZDFkNTJiYjYyNjcxZmQ0NGQyNDA4ZWM1MQ==
AlgoXen43	10.23.50.143	255	MjU1IEFsZ29YZW40MyAxMC4yMy41MC4xNDMgZmM4MDZiZDRhZDYxOWQ2MzlhMTg5ODcwNzM4YmE1Zjk3MDA0NmYzZTViZDczYzViYWQyOWIwNTE3ZWY3ZGZjZA==
AlgoXen44	10.23.50.144	256	MjU2IEFsZ29YZW40NCAxMC4yMy41MC4xNDQgNjJhZmM4MDI3ZWUxZmRhOWM5NTVlZGRhNjQwNGQ1YjQ2NGRmY2VhNzY5NzM3YWIxZDI1NTZmOGUzM2Y3ZWQwNw==
AlgoXen45	10.23.50.145	257	MjU3IEFsZ29YZW40NSAxMC4yMy41MC4xNDUgYmY3Njc1M2FiNTJmNTUyNzU1ZDViZTEyMjQxYzRlZGYyZWEwZDE0OWY1NDlkNzcxZDJhYzQ2MGY5MTk4ZDFjNg==
AlgoXen46	10.23.50.146	258	MjU4IEFsZ29YZW40NiAxMC4yMy41MC4xNDYgZjQxOTEyODFlOGNhYzJjNTRjNjZmOGIzMGVjM2FhODU3ZDAxNGY0NDg1NzAyYzc0ZjlkOTM3ZmM5NGZmZGZmYg==
AlgoXen47	10.23.50.147	259	MjU5IEFsZ29YZW40NyAxMC4yMy41MC4xNDcgOWFlYTg3NTA0YWUzODlkYzI0YzBjZjBlNzFjNmUzOTQ3ZDgwMTdmMWY1ODQ0YzM2OGM3MWRjZmFjZjkxMjcxOA==
AlgoXen48	10.23.50.148	260	MjYwIEFsZ29YZW40OCAxMC4yMy41MC4xNDggYTE5NWI5NjYzNWNmMjBlYjUxNDFhMTVjNDFmZmZhOTU4YmY2YzhlNzYyZTVjZjRmZmM0ZTRmZDYyMTk5MzFiMg==
AlgoXen49	10.23.50.149	261	MjYxIEFsZ29YZW40OSAxMC4yMy41MC4xNDkgMWUxOTBkNGZjMTUwY2NlYzJiYWY3MWEzMjc1ZGRmM2VlZjJmODg4OTVkZDYyMWU3MDU5OTNlOThhZWMxOGZlNQ==
AlgoXen50	10.23.50.150	262	MjYyIEFsZ29YZW41MCAxMC4yMy41MC4xNTAgNmIxOTk3OWZkOGJlNzI3OTdjN2YyMDk4MmJkYWM3ODU5ZWY3MzZkMzdlYTMxM2FhY2RhN2RkZmM4Yzc1ZjA1Zg==
AlgoXen51	10.23.50.151	263	MjYzIEFsZ29YZW41MSAxMC4yMy41MC4xNTEgMzlkZTRlN2VkNzg5MTk5MjQ1ODQwYjk4OWMzZTI5OTcwNTZjY2ZhODMwZWY2YTQxYTIyMWFhYWIzOGMzZWU4NA==
AlgoXen52	10.23.50.152	264	MjY0IEFsZ29YZW41MiAxMC4yMy41MC4xNTIgZTNkMDIzODQ0ZWEyNTgwZGM0N2FkZTg3NjQ0MGNkODliNjJhYTkzMmU3NDljN2E0YTY3OTQxODI1YzhlMWI2NA==
AlgoXen53	10.23.50.153	265	MjY1IEFsZ29YZW41MyAxMC4yMy41MC4xNTMgMjA2ODU2MDdlNjY3OTAzNGRmMDg4MjBjNTVmNTM2ODAwODcxYTMxNjQ0NDIzNDYyYjlmMWY1NDlkMGY2YzI3Mg==
AlgoXen54	10.23.50.154	266	MjY2IEFsZ29YZW41NCAxMC4yMy41MC4xNTQgZjExMDM3MWRkYjBmYmM0ZTY2MTQzZTU4NGUxYjYyYzllZWUzZGE0YmY1ZTNhYmRiNTJjNTJhMGIwOTEyODMxNQ==
AlgoXen55	10.23.50.155	267	MjY3IEFsZ29YZW41NSAxMC4yMy41MC4xNTUgZGNmYzM5MDE4YmFmMGVlM2Y5ZWU2OWI4NzBhNTgyMDA3ODk2MzIxZjIzMDQ1N2U4MDhhZGQ2OTg1NDUyMGUzNw==
AlgoXen56	10.23.50.156	268	MjY4IEFsZ29YZW41NiAxMC4yMy41MC4xNTYgNDU1MDFlZWMwNjFkNzM1NWFjZDI3OWIyM2Q3ZDllMDc0MWM3YmFkNGY5Y2ZjNmM0YjI0YTJhNWQxNzVmNmE1Ng==
AlgoXen57	10.23.50.157	269	MjY5IEFsZ29YZW41NyAxMC4yMy41MC4xNTcgZmZkMjM1MTA3NmNkM2JhYjk3OWFhMjMzNmM2N2YwMDQwMDhjOGM0NmZlMGIzOGUzOTE4MDljMmFmZTY4MDBhMQ==
AlgoXen58	10.23.50.158	270	MjcwIEFsZ29YZW41OCAxMC4yMy41MC4xNTggYWYzZTJiZTk3MmNhMjRhNGY3OWQzMDA5ZjY4NGZjMWE1NWM4MzIyYzQ3NzllMTRiZjc0YjQwMTYzM2VkNDMzZQ==
AlgoXen59	10.23.50.159	271	MjcxIEFsZ29YZW41OSAxMC4yMy41MC4xNTkgOGI3YjNiNzhlMjhhZGI2ZTk2YjliOTA0MGY3MDJkNWY4NzM5ZTgyOWMyZjkxMTgyNmY2OWUyY2JjN2UwMWU2Nw==
AlgoXen60	10.23.80.60	272	MjcyIEFsZ29YZW42MCAxMC4yMy44MC42MCBjMmQwNDM3MmNhYjc5YjM0NGExMDY3ZDAwZTQwNWE4OGM5ZWNkMDJmMTJmNzE3OTRkNGNkMzgwYWZmNGM4MTEy
AlgoXen61	10.23.50.161	273	MjczIEFsZ29YZW42MSAxMC4yMy41MC4xNjEgNjIxMjU4YWY3ODllMjlkYjQ3NDUwOTllMTkxMmUwZGNjNTBkMDM3NTIyMjcwNmEwN2YzMjg2MzA0NGMyYjc0Ng==
AlgoXen62	10.23.50.162	274	Mjc0IEFsZ29YZW42MiAxMC4yMy41MC4xNjIgOWZjY2QyMzFkZTE0YWEwOWNiMmUyYThjNzAxOTFmM2JlNTllYTUyMzJkOGU4NGNlMjg3Njg1M2U5NmY3MTc4YQ==
AlgoXen63	10.23.50.163	275	Mjc1IEFsZ29YZW42MyAxMC4yMy41MC4xNjMgOGY4M2ZjMjc2YTI1YmIyMjMyNWYwODgyOThlNGVlYmQ2MjQxYTBhOTEwNDgyOGRmZDcxYzg2NzE4NjA4MDJhOA==
AlgoXen64	10.23.50.164	276	Mjc2IEFsZ29YZW42NCAxMC4yMy41MC4xNjQgN2MzMGVlNDE5MTVlYTU0MjQ3YzMwZDNhMWIwNzE5MTNkMDkwN2M0ZTFjMDczZWU0MGE2MmY5ZTU2MDA2YmZkOA==
AlgoXen65	10.23.50.165	277	Mjc3IEFsZ29YZW42NSAxMC4yMy41MC4xNjUgMmRmZTgxZDUxOWQ1ZTAyODZhNGUxMWQ0ODBlNDRhOGI0Yjg0ZTIxMWYzNjI0NDgxNDE5NzEyMTZlNmRmY2VjNg==
AlgoXen66	10.23.50.166	278	Mjc4IEFsZ29YZW42NiAxMC4yMy41MC4xNjYgZjdkOWIxY2IwMDIxZWI4NjYzMmQzZDZiYTM4Njc3NTY1Njc5YmRhYjg3MzVlMDQwMzcxOGU0Y2FmNzU1ZjllZQ==
AlgoXen67	10.23.50.167	279	Mjc5IEFsZ29YZW42NyAxMC4yMy41MC4xNjcgYjQ3MTBkYjM2NzM5ZmFmMTM2OGUzOWQ0YzcxYmVmYjFiYzg4MDI5ZWMwM2M0OGRlNDFkMGQ5YzFhYzI3NTI1YQ==
AlgoXen68	10.23.50.168	280	MjgwIEFsZ29YZW42OCAxMC4yMy41MC4xNjggMWY0Y2IzMjMyNmNjZGVhZTEzNGYwYWUyMzhjZTAxYTJlNTczZmQxOTA1N2E3YzAyYzRkZTQ3OTMzYTdiMWE3Zg==
AlgoXen70	10.23.50.170	281	MjgxIEFsZ29YZW43MCAxMC4yMy41MC4xNzAgZTM3YWVkZmJmN2E4NDVlOTNhYTE5YWRjOTRmZjk5NzQzZDliMTQ2OGRjODczZjNlYWQwNjkwZWIzZWIxMWI2NQ==
AlgoXen71	10.23.50.171	282	MjgyIEFsZ29YZW43MSAxMC4yMy41MC4xNzEgMzAzNGJjZTNkYmEyOTUyMjIxMDRjMzRiMmNjMDc5NjE1NGFmMzNiYzcyZDlmOTQxZDBhNjI0N2NhYzRlZjllMw==
AlgoXen72	10.23.50.172	283	MjgzIEFsZ29YZW43MiAxMC4yMy41MC4xNzIgMGEyNDA2ZWFjODRjZWU5MzU5NWFhYjNmNGM1Y2I2MzhiMjc0YTMzYTcxY2E1NzkwYTFjYjRkZjA3Y2Q2ZmVjZA==
AlgoXen73	10.23.50.173	284	Mjg0IEFsZ29YZW43MyAxMC4yMy41MC4xNzMgNzExNzVhZGMwM2UxZjE0M2I5ZDhkOWQ5ZWNlNDRiNDlkNDg4YzQ4MDI1NDk4NzUzZDFjYjNiZjc3MTFjY2QxNQ==
AlgoXen74	10.23.50.174	285	Mjg1IEFsZ29YZW43NCAxMC4yMy41MC4xNzQgNGI4NWNjNDM1Y2M3ZmE3ODg5YzY4MDE2YTgyZTk1NmZlOGFiNGNhOTJmZjUyZTJmZGQ4MGMyOTg3NTYwMzU3ZA==
EOF
fi

chmod 0440 ${WORKDIR}/keys.txt

# Back up existing keys file:
[[ -f /var/ossec/etc/client.keys ]] && mv /var/ossec/etc/client.keys /var/ossec/etc/client.keys.`date "+%Y%m%d_%H%M%S"`
cat ${WORKDIR}/keys.txt | grep -i ${HOSTNAME} | while read host ip id key; do
    echo "Cut and paste the line below into a terminal to create the key (hit 'y' then 'Enter'):"
    echo "/var/ossec/bin/manage_client -i ${key}"
done

# Set appropriate ownership and permissions on client.keys:
chown root.ossec /var/ossec/etc/client.keys
chmod 0440 /var/ossec/etc/client.keys

# Back up existing agent configuration:
if [[ -f /var/ossec/etc/ossec-agent.conf ]]; then
    echo "- backing up ossec-agent.conf:"
    mv /var/ossec/etc/ossec-agent.conf /var/ossec/etc/ossec-agent.conf.`date "+%Y%m%d_%H%M%S"`
fi

# Create the configuration for the agent:
echo "- creating ossec-agent.conf:"
cat > /var/ossec/etc/ossec-agent.conf <<EOF
<ossec_config>
 <client>
  <server-ip>10.23.51.21</server-ip>
  <config-profile>${OSSEC_HV_PROFILENAME}</config-profile>
 </client>
</ossec_config>
EOF

# Check that ossec is enabled:
echo "- enabling OSSEC by default:"
chkconfig ossec-hids on

# Run it:
echo "- starting OSSEC:"
service ossec-hids restart

# Check to see if my account is found:
id sashby

echo "==============================================================================="
echo ""
echo " - do \"id <username>\" to see if your account can be found from LDAP"
echo " - do \"ntpq -p\" to see if time has synchronized correctly"
echo ""
echo ""
echo "Now remove this script if everything worked. Have a nice day.           "
echo "==============================================================================="
