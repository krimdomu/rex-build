#!/usr/bin/env perl

use YAML;
use Data::Dumper;
use Rex -base;
use Rex::Commands::Virtualization;
use Rex::Commands::SimpleCheck;
use Cwd 'getcwd';

set virtualization => "LibVirt";


$::QUIET = 1;

my $yaml = eval { local(@ARGV, $/) = ($ENV{HOME} . "/.build_config"); <>; };
$yaml .= "\n";
my $config = Load($yaml);

my $base_vm = $ARGV[0];

Rex::connect(%{ $config });

my $new_vm = "${base_vm}-test";
if(exists $ENV{use_sudo}) {
   $new_vm .= "-sudo";
}

vm clone => $base_vm  => $new_vm;

vm start => $new_vm;

my $vminfo = vm guestinfo => $new_vm;
my $ip = $vminfo->{network}->[0]->{ip};

while(! is_port_open($ip, 22)) {
   sleep 1;
}

my ($user, $pass);

$user = $config->{box}->{default}->{user};
$pass = $config->{box}->{default}->{password};

system "REXUSER=$user REXPASS=$pass HTEST=$ip rex -c build";

vm destroy => $new_vm;

vm delete => $new_vm;

#rm "/var/lib/libvirt/images/$new_vm.img";
# fix for #6
run "virsh vol-delete --pool default $new_vm.img";


