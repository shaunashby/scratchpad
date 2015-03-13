#!/usr/bin/env perl
#____________________________________________________________________
# File: hv-looper.pl
#____________________________________________________________________
#
# Author:  <sashby@dfi.ch>
# Created: 2015-02-27 12:36:01+0100 (Time-stamp: <2015-03-12 02:48:09 sashby>)
# Revision: $Id$
# Description: Script to use expect to automate login via SSH.
#
# Copyright (C) 2015 
#
#
#--------------------------------------------------------------------
use 5.0010;

use warnings;
use strict;

use Net::SSH::Expect;

# Use the list of accounts, ordered by hostname:
my $mappingfile="./mdp-ordered.txt";
my ($hypervisor,$mdp);
my $mappings = {};

open(MAPPING,"< $mappingfile") or die "Unable to open $mappingfile for reading: $!\n";
while (<MAPPING>) {
    chomp;
    next if /^#/;
    next if /^\s.*?/;
    ($hypervisor,$mdp) = split(/\t/);
    $mappings->{$hypervisor} = $mdp;
}
close(MAPPING);

######################

my $ssh;

foreach my $hv (sort keys %$mappings ) {
    print "$hv\n";
    $mdp = $mappings->{$hv};

    $ssh = Net::SSH::Expect->new (
    	host      => "$hv", 
    	password  => "$mdp", 
    	user      => 'root',
    	raw_pty   => 1
    	);

    # Log in and check that we get a XenServer string somewhere:
    my $login_output = $ssh->login();
    if ($login_output !~ /XenServer|localhost/) {
    	die "Login has failed on $hv. Login output was $login_output";
    }

    # Disable terminal translations and echo on the SSH server:
    $ssh->exec("stty raw -echo");

    # Beginning task list here:
    my $ret;
    $ret = $ssh->exec("ls /etc/puppet/modules/dfi-algo/manifests/init.pp");
    # $ret = $ssh->exec("rm -f ./install-puppet.sh*");
    print "-- $ret","\n";

    $ret = $ssh->exec("cat /var/log/puppet/agentcron.log");
    # $ret = $ssh->exec("rm -f ./install-puppet.sh*");
    print "-- $ret","\n";

    # $ret = $ssh->exec("wget http://10.23.50.30/install-puppet.sh");
    # print "-- $ret","\n";

    # $ret = $ssh->exec("chmod +x ./install-puppet.sh");
    # print "-- $ret","\n";
}

# Close the SSH connection:
$ssh->close();

exit(0);
