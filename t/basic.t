use strict;
use warnings;

use Test::More tests => 1;

use CPAN::Faker;
use File::Temp ();

my $tmpdir = File::Temp::tempdir;
diag "output to $tmpdir";

my $cpan = CPAN::Faker->new({
  source => './eg',
  dest   => $tmpdir,
});

$cpan->make_cpan;

ok(1, 'this test left passing');
