use IO::All;

LOCAL {
  my $cwd = getcwd();
  my $rnd = get_random( 8, 'a' .. 'z' );

  $ENV{"WORK_DIR"} = "/tmp/workspace/$rnd";

  mkdir "/tmp/workspace";
  mkdir "/tmp/workspace/$rnd";
  chdir "/tmp/workspace/$rnd";

  start_phase("Cloning git repo: $git_repo with refspec: $branch");
  system
    "git clone $git_repo rex --branch $branch >/var/log/rex/checkout-$$.log 2>&1";
  &end_phase;

  system "cd rex ; dzil build";

  my ($version_line) = grep { m/^version/ } io("dist.ini")->slurp;
  my ($t1, $version) = split(/ = /, $version_line);
  $ENV{REX_VERSION} = $version;

  chdir $cwd;

  $ENV{"PATH"}    = "/tmp/workspace/$rnd/rex/Rex-$version/bin:" . $ENV{PATH};
  $ENV{"PERLLIB"} = "/tmp/workspace/$rnd/rex/Rex-$version/lib:"
    . ( exists $ENV{PERLLIB} ? $ENV{PERLLIB} : "" );
  $ENV{"PERL5LIB"} = "/tmp/workspace/$rnd/rex/Rex-$version/lib:"
    . ( exists $ENV{PERL5LIB} ? $ENV{PERL5LIB} : "" );

  start_phase('Running prepare.rex');
  system
    "HTEST='$ip' perl /tmp/workspace/$rnd/rex/Rex-$version/bin/rex -f contrib/prepare.rex prepare >>/var/log/rex/prepare-$$.log 2>&1";
  &end_phase;

  if ( $ENV{use_sudo} ) {
    start_phase('Running prepare_sudo.rex');
    system
      "HTEST='$ip' perl /tmp/workspace/$rnd/rex/Rex-$version/bin/rex -f contrib/prepare_sudo.rex prepare >>/var/log/rex/prepare_sudo-$$.log 2>&1";
    if ( $? != 0 ) {
      print STDERR "Error preparing for sudo.\n";
      exit 1;
    }
    &end_phase;
  }

  # run tests from tests directory
  $ENV{PATH} = getcwd() . ":" . $ENV{PATH};
  opendir( my $dh, "tests" ) or die($!);
  while ( my $entry = readdir($dh) ) {
    next if ( $entry =~ m/^\./ );
    next if ( !-f "tests/$entry" );
    next if ( $entry !~ m/\.rex$/ );

    start_phase("Running tests/$entry");
    system
      "REX_VERSION=$version WORK_DIR=$ENV{WORK_DIR} REXUSER=$user REXPASS=$pass HTEST='$ip' prove --timer --formatter TAP::Formatter::JUnit --ext rex -e rex-test tests/$entry >junit_output_tests_$entry.xml";
    &end_phase;
  }
  closedir($dh);

  # run tests from tests.d directory
  opendir( my $dh, "tests.d" ) or die($!);
  while ( my $entry = readdir($dh) ) {
    next if ( $entry =~ m/^\./ );
    next if ( !-d "tests.d/$entry" );

    $ENV{PERL5LIB} =
      "tests.d/$entry/lib:" . ( exists $ENV{PERL5LIB} ? $ENV{PERL5LIB} : "" );
    start_phase("Running tests.d/$entry");
    system
      "REX_VERSION=$version WORK_DIR=$ENV{WORK_DIR} REXUSER=$user REXPASS=$pass HTEST='$ip' prove --timer --formatter TAP::Formatter::JUnit --ext rex -e rex-test tests.d/$entry >junit_output_testsd_$entry.xml";
    &end_phase;
  }
  closedir($dh);

  start_phase('tests.post.d');
  system
    "REX_VERSION=$version WORK_DIR=$ENV{WORK_DIR} REXUSER=$user REXPASS=$pass HTEST='$ip' prove --timer --formatter TAP::Formatter::JUnit --ext rex -e rex-test tests.post.d >junit_output_tests_post_d.xml";
  &end_phase;

  system "rm -rf /tmp/workspace/$rnd";
};

1;
