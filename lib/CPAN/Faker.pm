package CPAN::Faker;
use Moose;

our $VERSION = '0.001';

use CPAN::Checksums ();
use Compress::Zlib ();
use Cwd ();
use File::Next ();
use File::Path ();
use File::Spec ();
use Module::Faker::Dist;
use Sort::Versions qw(versioncmp);
use Text::Template;

has source    => (is => 'ro', required => 1);
has dest      => (is => 'ro', required => 1);
has pkg_index => (is => 'ro', isa => 'HashRef', default => sub { {} });

has url => (
  is      => 'ro',
  isa     => 'Str',
  default => sub {
    my ($self) = @_;
    my $url = "file://" . File::Spec->rel2abs($self->dest);
    $url =~ s{(?<!/)$}{/};
    return $url;
  },
);

sub BUILD {
  my ($self) = @_;

  for (qw(source dest)) {
    my $dir = $self->$_;
    Carp::croak "$_ directory does not exist"     unless -e $dir;
    Carp::croak "$_ directory is not a directory" unless -d $dir;
    Carp::croak "$_ directory is not writeable"   unless -w $dir;
  }
}

sub __dor { defined $_[0] ? $_[0] : $_[1] }

sub dist_class { 'Module::Faker::Dist' }

sub make_cpan {
  my ($self, $arg) = @_;

  my $iter = File::Next::files($self->source);
  my $dist_dest = File::Spec->catdir($self->dest, qw(authors id));

  my %author_dir;

  while (my $file = $iter->()) {
    my $dist = $self->dist_class->from_file($file);

    my $archive = $dist->make_archive({
      dir => $dist_dest,
      author_prefix => 1,
    });

    $self->_maybe_index($dist);

    my ($author_dir) = $archive =~ m{\A(.+)/};
    $author_dir{ $author_dir } = 1;
  }

  $self->_write_index;

  for my $dir (keys %author_dir) {
    print "updating $dir\n";
    CPAN::Checksums::updatedir($dir);
  }

  $self->_write_modlist_index;
}

sub _maybe_index {
  my ($self, $dist) = @_;

  my $index = $self->pkg_index;

  PACKAGE: for my $package ($dist->provides) {
    my $entry = { dist => $dist, pkg => $package };

    if (my $existing = $index->{ $package->name }) {
      my $e_dist = $existing->{dist};
      my $e_pkg  = $existing->{pkg};

      if (defined $package->version and not defined $e_pkg->version) {
        $index->{ $package->name } = $entry;
        next PACKAGE;
      } elsif (not defined $package->version and defined $e_pkg->version) {
        next PACKAGE;
      } else {
        my $pkg_cmp = versioncmp($package->version, $e_pkg->version);

        if ($pkg_cmp == 1) {
          $index->{ $package->name } = $entry;
          next PACKAGE;
        } elsif ($pkg_cmp == 0) {
          if (versioncmp($dist->version, $e_dist->version) == 1) {
            $index->{ $package->name } = $entry;
            next PACKAGE;
          }
        }

        next PACKAGE;
      }
    } else {
      $index->{ $package->name } = $entry;
    }
  }
}

sub _write_index {
  my ($self) = @_;

  my $index = $self->pkg_index;

  my @lines;
  for my $pkg_name (sort keys %$index) {
    my $pkg = $index->{ $pkg_name }->{pkg};
    push @lines, sprintf "%-34s %5s  %s\n",
      $pkg->name,
      __dor($pkg->version, 'undef'),
      $index->{ $pkg_name }->{dist}->archive_filename({ author_prefix => 1 });
  }

  my $front = $self->_front_matter({ lines => scalar @lines });

  my $index_dir = File::Spec->catdir($self->dest, 'modules');
  File::Path::mkpath($index_dir);

  my $index_filename = File::Spec->catfile(
    $index_dir,
    '02packages.details.txt.gz',
  );

  my $gz = Compress::Zlib::gzopen($index_filename, 'wb');
  $gz->gzwrite("$front\n");
  $gz->gzwrite($_) || die "error writing to $index_filename" for @lines;
  $gz->gzclose and die "error closing $index_filename";
}

sub _write_modlist_index {
  my ($self) = @_;

  my $index_dir = File::Spec->catdir($self->dest, 'modules');

  my $index_filename = File::Spec->catfile(
    $index_dir,
    '03modlist.data.gz',
  );

  my $gz = Compress::Zlib::gzopen($index_filename, 'wb');
  $gz->gzwrite($self->_template->{modlist});
  $gz->gzclose and die "error closing $index_filename";
}

my $template;
sub _template {
  return $template if $template;

  my $current;
  while (my $line = <DATA>) {
    chomp $line;
    if ($line =~ /\A__([^_]+)__\z/) {
      my $filename = $1;
      if ($filename !~ /\A(?:DATA|END)\z/) {
        $current = $filename;
        next;
      }
    }

    Carp::confess "bogus data section: text outside of file" unless $current;

    ($template->{$current} ||= '') .= "$line\n";
  }

  return $template;
}

sub _front_matter {
  my ($self, $arg) = @_;

  my $template = $self->_template->{packages};

  my $text = Text::Template->fill_this_in(
    $template,
    DELIMITERS => [ '{{', '}}' ],
    HASH       => {
      self => \$self,
      (map {; $_ => \($arg->{$_}) } keys %$arg),
    },
  );

  return $text;
}

=head1 COPYRIGHT AND AUTHOR

This distribution was written by Ricardo Signes, E<lt>rjbs@cpan.orgE<gt>.

Copyright 2008.  This is free software, released under the same terms as perl
itself.

=cut

no Moose;
1;

__DATA__
__packages__
File:         02packages.details.txt
URL:          {{ $self->url }}modules/02packages.details.txt.gz
Description:  Package names found in directory $CPAN/authors/id/
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:   CPAN::Faker version {{ $CPAN::Faker::VERSION }}
Line-Count:   {{ $lines }}
Last-Updated: {{ scalar localtime }}
__modlist__
File:        03modlist.data
Description: CPAN::Faker does not provide modlist data.
Modcount:    0
Written-By:  CPAN::Faker version {{ $CPAN::Faker::VERSION }}
Date:        {{ scalar localtime }}

package CPAN::Modulelist;
# Usage: print Data::Dumper->new([CPAN::Modulelist->data])->Dump or similar
# cannot 'use strict', because we normally run under Safe
# use strict;
sub data {
my $result = {};
my $primary = "modid";
for (@$CPAN::Modulelist::data){
my %hash;
@hash{@$CPAN::Modulelist::cols} = @$_;
$result->{$hash{$primary}} = \%hash;
}
$result;
}
$CPAN::Modulelist::cols = [
'modid',
'statd',
'stats',
'statl',
'stati',
'statp',
'description',
'userid',
'chapterid'
];
$CPAN::Modulelist::data = [];
