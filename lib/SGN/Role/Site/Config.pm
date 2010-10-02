package SGN::Role::Site::Config;

use Moose::Role;
use namespace::autoclean;

use Carp;
use Cwd;
use List::Util qw/ reduce /;

use Data::Visitor::Callback;
use Hash::Merge ();

use SGN::Config;

=head2 config

  Usage   : my $proj = $c->config->{bac_project_chr_11}
  Returns : config hashref
  Args    : none
  Side Eff: none

  Use this to fetch the full hashref of configuration variables.
  Compatible with Catalyst's $c->config function to help smooth
  our transition to Catalyst.

=cut

{ my %config;
  sub config {
      my $class = shift;
      $class = ref $class if ref $class;
      return $config{$class} ||= $class->_new_config;
  }
}

sub _new_config {
    my $self = shift;
    my $appname = $self->_appname;

    my $basepath = $self->_find_basepath;

    my @conf_files = (
           $ENV{ uc($appname).'_CONFIG' }
        || $ENV{ "CATALYST_CONFIG" }
        || map File::Spec->catfile( $basepath, "$appname.$_" ),
            Config::Any->extensions
       );

    my @default_files = (
            map File::Spec->catfile( $basepath, 'conf', "${appname}_defaults.$_" ),
            Config::Any->extensions
       );

    my @file_cfg = $self->_load_conf_files( \@conf_files );
    my @default_cfg = $self->_load_conf_files( \@default_files );

    my %add = (
        basepath => $basepath, #< basepath is the old-SGN-compatible name
        home     => $basepath, #< home is the catalyst-compatible name
        project_name => 'SGN',
       );

    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
    my $cfg = reduce { $merge->merge( $a, $b ) }  @default_cfg, @file_cfg, \%add;

    # interpolate config values
    Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            s|__HOME__|$basepath|eg;
            s|__UID__|$>|eg;
            s|__USERNAME__|(getpwuid($>))[0]|eg;
            s|__GID__|$)|eg;
            s|__GROUPNAME__|(getgrgid($)))[0]|eg;
            s|__path_to\(([^\)]+)\)__|File::Spec->catdir($basepath, split /,/, $1) |eg;
            return $_;
        },
    )->visit( $cfg );

    return $cfg;
}

sub _appname {
    my $self = shift;
    my $n = ref $self || $self;
    $n =~ s/::.+//;
    return $n;
}

sub _load_conf_files {
    my ($self, $files) = @_;
    my $cfg = Config::Any->load_files({
        files       => $files,
        use_ext     => 1,
    });
    return map values %$_, @$cfg;
}

sub _find_basepath {
    my $self = shift;
    my $appname = $self->_appname;

    # find the path on disk of this file, then find the basename from that
    my @basepath_strategies = (
        # 0. maybe somebody has set an SGN_SITE_ROOT environment variable
        sub {
            return $ENV{uc($appname).'_SITE_ROOT'} || '';
        },
        # 1. search down the directory tree until we find a dir that contains ./sgn/cgi-bin
        sub {
            my $this_file = _path_to_this_pm_file();
            my $dir = File::Basename::dirname($this_file);
            until ( -d File::Spec->catdir( $dir, 'sgn', 'cgi-bin' ) ) {
                $dir = File::Spec->catdir( $dir, File::Spec->updir );
            }
            $dir = File::Spec->catdir( $dir, 'sgn' );
            return $dir;
        },
       );

    my $basepath;
    foreach my $basepath_strategy ( @basepath_strategies ) {
        $basepath = $basepath_strategy->();
        last if -d File::Spec->catfile($basepath,'cgi-bin');
    }

    -d File::Spec->catfile( $basepath, 'cgi-bin' )
        or die "could not find basepath starting from this file ("._path_to_this_pm_file().")";

    return Cwd::abs_path( $basepath )
}

sub _path_to_this_pm_file {
    (my $this_file = __PACKAGE__.".pm") =~ s{::}{/}g;
    $this_file = $INC{$this_file};
    -f $this_file or die "cannot find path to this file (tried '$this_file')";
    return $this_file;
}


=head2 get_conf

  Status  : public
  Usage   : $c->get_conf('my_conf_variable')
  Returns : the value of the variable, as loaded by the configuration
            objects
  Args    : a single configuration variable name
  Side Eff: B<DIES> if the variable is not defined, either in defaults or
            in the configuration file.
  Example:

     my $val = $c->get_conf('my_conf_variable');


It's probably best to use $c->get_conf('var') rather than
$c->config->{var} for most purposes, because get_conf() checks that
the variable is actually set, and dies if not.

=cut

sub get_conf {
  my ( $self, $n ) = @_;

  croak "conf variable '$n' not set, and no default provided"
      unless exists $self->config->{$n};

  return $self->config->{$n};
}



1;
