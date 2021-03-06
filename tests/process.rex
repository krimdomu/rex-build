# vim: set syn=perl:
use Rex -feature => '0.42';
use Data::Dumper;
use Test::More;
use Rex::Commands::Gather;

do "auth.conf";

task test => group => test => sub {

  my $command = "/usr/sbin/sshd";
  my $search_for = "sshd";

  if(is_openwrt) {
   $command = "/usr/sbin/dropbear";
   $search_for = "dropbear";
  }

  run "$command -p 9999 ; sleep 1";

#ps
# not working inside a container
#  my @list = grep { $_->{"pid"} eq "1" } ps();
#  ok($list[0]->{"command"} =~ m/init|systemd/, "ps, found init command");

#kill($pid, $sig)
  my ($sshd1) = grep { $_->{"command"} && $_->{"command"} =~ m/$search_for \-p 9999/ } ps();
  kill $sshd1->{"pid"}, -9;
  ($sshd1) = grep { $_->{"command"} && $_->{"command"} =~ m/$search_for \-p 9999/ } ps();
  ok( ! $sshd1, "process was killed." );

##killall($name, $sig)
#  my ($crond) = grep { $_->{"command"} && $_->{"command"} =~ m/crond/ } ps();
#  killall $crond->{"pid"}, 9;
#  ($crond) = grep { $_->{"command"} && $_->{"command"} =~ m/crond/ } ps();
#  ok( ! $crond, "process was killed via killall" );

#nice($pid, $level)

  unless(is_openwrt) {
    # run this test not on openwrt. there is no good ps command

    run "$command -p 9998 ; sleep 1";
    my $nice = 19;
    my ($sshd2) = grep { $_->{"command"} && $_->{"command"} =~ m/$search_for \-p 9998/ } ps();
    my ($sshpid) = $sshd2->{"pid"};
    nice $sshpid, $nice;
    run "ps -p  $sshpid -o priority=", sub {
       my ($stdout, $stderr) = @_;
       ok( $stdout = $nice, "niceness set successfully" );
     };

    # issue: 175
    my @ps = ps("command","ni");
    ok(exists $ps[0]->{command}, "ps out: command exists");
    ok(exists $ps[0]->{ni}, "ps out: ni exists");


   }

  done_testing();
};

