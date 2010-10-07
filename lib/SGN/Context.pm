=head1 NAME

SGN::Context - deprecated, do not use in new code

=cut

# =head1 NAME

# SGN::Context - configuration and context object, meant to export a
# similar interface to the Catalyst context object, to help smooth our
# transition to Catalyst.

# =head1 SYNOPSIS

#   my $c = SGN::Context->new;
#   my $c = SGN::Context->instance; # new() and instance() do the same thing

#   # Catalyst-compatible
#   print "my_conf_variable is ".$c->get_conf('my_conf_variable');

# =head1 DESCRIPTION

# Note that this object is a singleton, based on L<MooseX::Singleton>.
# There is only ever 1 instance of it.

# =head1 ROLES

# Does: L<SGN::SiteFeatures>, L<SGN::Site>

# =head1 OBJECT METHODS

# =cut

package SGN::Context;
use 5.10.0;
use Moose;
use namespace::autoclean;

use warnings FATAL => 'all';

use Carp;
use File::Spec;

use Config::JFDI;

use Catalyst::Utils ();
use CatalystX::GlobalContext '$c';

sub instance { shift->new(@_) }

# only use this object if $c is not available
around qw( new ) => sub {
    return $c if $c;

    my $orig  = shift;
    my $class = shift;
    return $class->$orig(@_);
};

sub setup_finalize {} #< stubbed out to satisfy roles

sub path_to {
    my ( $self, @relpath ) = @_;

    @relpath = map "$_", @relpath; #< stringify whatever was passed

    my $basepath = $self->get_conf('basepath')
      or die "no base path conf variable defined";
    -d $basepath or die "base path '$basepath' does not exist!";

    return File::Spec->catfile( $basepath, @relpath );
}

sub config {
    my $class = shift;
    $class = ref $class if ref $class;
    state %config;
    return $config{$class} ||= $class->_build_config;
}
sub _build_config {
    my ($self) = @_;

    my $home = Catalyst::Utils::home( __PACKAGE__ );

    return
        Config::JFDI->open(
            name => 'sgn',
            path => $home,
            substitute => {
                UID       => sub { $> },
                USERNAME  => sub { (getpwuid($>))[0] },
                GID       => sub { $) },
                GROUPNAME => sub { (getgrgid($)))[0] },
            },
            default => {
                name     => 'SGN',
                home     => $home,
                basepath => $home,
               },
           )
        || die "failed to load sgn config files in dir '$home'";
}

with qw(
    SGN::Role::Site::Config
    SGN::Role::Site::DBConnector
    SGN::Role::Site::DBIC
    SGN::Role::Site::Files
    SGN::Role::Site::Mason
    SGN::Role::Site::SiteFeatures
);

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

###
1;#do not remove
###
