use inc::Module::Install;
all_from      ('lib/CPAN/Faker.pm');

requires('CPAN::Checksums'     => '0.000'); # minimum unknown
requires('Class::MOP'          => '0.53' ); # for Moose; init_arg => undef
requires('Compress::Zlib'      => '0.000'); # minimum unknown
requires('Cwd'                 => '0.000'); # minimum unknown
requires('Data::Section'       => '0.000'); # minimum unknown
requires('File::Next'          => '0.000'); # minimum unknown
requires('File::Path'          => '0.000'); # minimum unknown
requires('File::Spec'          => '0.000'); # minimum unknown
requires('Module::Faker::Dist' => '0.003'); # author prefix dirs
requires('Moose',              => '0.000'); # minimum unknown
requires('Sort::Versions'      => '0.000'); # minimum unknown
requires('Text::Template'      => '0.000'); # minimum unknown

extra_tests;

WriteAll();
