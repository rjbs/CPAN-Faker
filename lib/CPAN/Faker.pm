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

has source => (is => 'ro', required => 1);
has dest   => (is => 'ro', required => 1);

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

  my %package;
  my %author_dir;

  while (my $file = $iter->()) {
    my $dist = $self->dist_class->from_file($file);

    PACKAGE: for my $package ($dist->provides) {
      my $entry = { dist => $dist, pkg => $package };

      if (my $existing = $package{ $package->name }) {
        my $e_dist = $existing->{dist};
        my $e_pkg  = $existing->{pkg};

        if (defined $package->version and not defined $e_pkg->version) {
          $package{ $package->name } = $entry;
          next PACKAGE;
        } elsif (not defined $package->version and defined $e_pkg->version) {
          next PACKAGE;
        } else {
          my $pkg_cmp = versioncmp($package->version, $e_pkg->version);

          if ($pkg_cmp == 1) {
            $package{ $package->name } = $entry;
            next PACKAGE;
          } elsif ($pkg_cmp == 0) {
            if (versioncmp($dist->version, $e_dist->version) == 1) {
              $package{ $package->name } = $entry;
              next PACKAGE;
            }
          }

          next PACKAGE;
        }
      } else {
        $package{ $package->name } = $entry;
      }
    }

    my $archive = $dist->make_archive({
      dir => $dist_dest,
      author_prefix => 1,
    });

    my ($author_dir) = $archive =~ m{\A(.+)/};
    $author_dir{ $author_dir } = 1;
  }

  my @lines;
  for my $pkg_name (sort keys %package) {
    my $pkg = $package{ $pkg_name }->{pkg};
    push @lines, sprintf "%-34s %5s  %s\n",
      $pkg->name,
      __dor($pkg->version, 'undef'),
      $package{ $pkg_name }->{dist}->archive_filename({ author_prefix => 1 });
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

  for my $dir (keys %author_dir) {
    print "updating $dir\n";
    CPAN::Checksums::updatedir($dir);
  }
}

my $template;
sub _front_matter {
  my ($self, $arg) = @_;

  $template ||= do { local $/; <DATA>; };

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
File:         02packages.details.txt
URL:          {{ $self->url }}modules/02packages.details.txt.gz
Description:  Package names found in directory $CPAN/authors/id/
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:   CPAN::Faker version {{ $CPAN::Faker::VERSION }}
Line-Count:   {{ $lines }}
Last-Updated: {{ scalar localtime }}
