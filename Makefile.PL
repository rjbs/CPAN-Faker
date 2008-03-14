
use strict;
use warnings;

use inc::Module::Install;

name          ('CPAN-Faker');
author        ('Ricardo Signes <rjbs@cpan.org>');
license       ('perl');
all_from      ('lib/CPAN/Faker.pm');


requires('CPAN::Checksums'     => '0.000'); # minimum unknown
requires('Compress::Zlib'      => '0.000'); # minimum unknown
requires('Cwd'                 => '0.000'); # minimum unknown
requires('File::Next'          => '0.000'); # minimum unknown
requires('File::Path'          => '0.000'); # minimum unknown
requires('File::Spec'          => '0.000'); # minimum unknown
requires('Module::Faker::Dist' => '0.003'); # author prefix dirs
requires('Sort::Versions'      => '0.000'); # minimum unknown
requires('Text::Template'      => '0.000'); # minimum unknown

author_tests('xt');

WriteAll();
