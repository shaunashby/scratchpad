#!/usr/bin/env perl
#____________________________________________________________________
# File: cimanage.pl
#____________________________________________________________________
#
# Author:  <sashby@dfi.ch>
# Created: 2015-04-09 10:48:03+0200 (Time-stamp: <2015-04-09 17:14:40 sashby>)
# Revision: $Id$
# Description: Script to build relationships between CIs.
#
# Copyright (C) 2015 
#
#
#--------------------------------------------------------------------
package CI;

use 5.0010;

use warnings;
use strict;

use Carp qw(croak);
use Data::Dumper;

use overload q{""} => \&_info;

sub new() {
    my $proto =  shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my $data = (@_ == 0) ? # Error if no params given
	croak("No params arg given.\n")
	: (ref($_[0]) eq 'ARRAY') ? shift : [];
    bless($self, $class);

    # Extract required data:
    $self->{pool} = $data->[0];
    $self->{name} = $data->[1];
    ($self->{id}) = ($self->{name} =~ /.*(\d\d)/);

    my ($position, $enclosure);

    if (($position, $enclosure) = ($data->[2] =~ m|(CN\d\d)\.(Flex.*?\.cri)|g)) {
	$self->{position} = $position;
	$self->{enclosure} = $enclosure;
	($self->{positionid}) = ( $self->{position} =~ /.*(\d\d)/);
    } elsif (($enclosure, $position) = ($data->[2] =~ m|(BC\d\d)(B\d\d)|g)) {
	$self->{position} = $position;
	$self->{enclosure} = $enclosure;
	($self->{positionid}) = ( $self->{position} =~ /.*(\d\d)/);
    } else {
	croak(sprintf("Unknown type of enclosure %s.",$data->[2]));
    }
    # Also store full position string:
    $self->{fullposition} = $data->[2];
    $self->{bladedesc}    = $data->[3];
    $self->{cputype}      = $data->[4];
    return $self;
}

sub id() { shift->{id} }
sub name() { shift->{name} }
sub position() { shift->{position} }
sub positionid() { shift->{positionid} }
sub fullposition() { shift->{fullposition} }
sub enclosure() { shift->{enclosure} }
sub _info() { shift->_print }
sub _print() { my $self = shift; sprintf("%-s\t%-s", $self->{name}, $self->{fullposition}) }

#########################################
package Enclosure;

use 5.0010;

use warnings;
use strict;

use Carp qw(croak);

sub new() {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = (@_ == 0) ? # Error if no params given
	croak("No params arg given.\n")
	: (ref($_[0]) eq 'HASH') ? shift : { devices => [] };
    return bless($self, $class);
}

sub devices() { shift->{devices} }
sub ethswitch() { grep { /sw/ } @{shift->{devices}} }
sub device() { push(@{shift->{devices}},$_[0]) }

#########################################
package main;

use 5.0010;

use warnings;
use strict;
use Data::Dumper;

my $cilist = './pools.csv';
my $netinf = './switches.csv';
my $cis = [];

# Read the network infra data (switches and enclosures):
open(NETINF,"< $netinf") or die "Error opening $netinf: $!","\n";
my @infra = <NETINF>;
close(NETINF);

# Get the info for the enclosures:
my $enclosures = {};
foreach my $entry (@infra) {
    chomp($entry);
    $entry =~ s/"//g;
    next if $entry =~ /^#/;
    my ($enclosure, $device) = split(/,/, $entry);
    if (exists($enclosures->{$enclosure})) {
	$enclosures->{$enclosure}->device($device);
    } else {
	$enclosures->{$enclosure} = Enclosure->new({ devices => [ $device ] });
    }
}

# Open the CI list and create an array of objects:
open(CILIST,"< $cilist") or die "Error opening $cilist: $!","\n";
while (<CILIST>) {
    next unless /^[a-zA-Z]/;
    chomp;
    push(@$cis, CI->new([ split(/,/) ]));
}
close(CILIST);

# Loop over enclosures:
foreach my $enclosure (sort keys %$enclosures) {
    print $enclosure,"\n";
    foreach my $switch ($enclosures->{$enclosure}->ethswitch) {
	print "\t$switch","\n";
	foreach my $ci (sort { $a->positionid <=> $b->positionid } @$cis) {
	    if ($ci->enclosure eq $enclosure) {
		printf("\t\t%-s    %-s\n",$ci->position, $ci->name);
	    }
	}
    }
}
