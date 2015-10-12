# vim: set syn=perl:
use Test::More;

use Rex::Commands::Run;
use Rex::Helper::Path;
use Rex::Commands::Pkg;
use Rex::Commands::SCM;
use Rex::Commands::Fs;

do 'auth.conf';

set repository => "myrepo",
  url => 'https://github.com/RexOps/Rex.git';

task test => group => test => sub {
  
  my $test_dir = "/tmp/git-test-$$";
  
  pkg "git";
  
  checkout "myrepo", path => $test_dir;
  is(is_dir($test_dir), 1, "checkout path exists");
  is(is_dir("$test_dir/lib"), 1, "checkout successfull");
  
  my $branch = run "git status |  grep -i 'on branch'", cwd => $test_dir;
  chomp $branch;
  ok($branch =~ m/master/, "got master branch");
  
  run "rm -rf $test_dir";
  
  checkout "myrepo", path => $test_dir, branch => "2.0";
  my $branch = run "git status |  grep -i 'on branch'", cwd => $test_dir;
  chomp $branch;
  ok($branch =~ m/2\.0/, "got 2.0 branch");

  run "rm -rf $test_dir";

  eval {
    checkout "myrepo", path => $test_dir, branch => "doesnt-exists";
    ok(1==2, "checkout of unknown branch successfull.");
    1;
  } or do {
    ok(1==1, "checkout of unknown branch failed.");
  };
  
  done_testing();
};

1;