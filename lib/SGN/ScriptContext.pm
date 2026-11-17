package SGN::ScriptContext;

=head1 NAME

SGN::ScriptContext - a shim for the Catalyst object for upload_phenotypes.pl

=head1 SYNOPSIS

 my $c = SGN::ScriptContext->new({
     basepath => $basepath,
     username => $username,
     schemas  => {
         'Bio::Chado::Schema'     => $chado_schema,
         'CXGN::Metadata::Schema' => $metadata_schema
     }
 });

 my $image = SGN::Image->new($dbh, undef, $c);

=head1 DESCRIPTION

Writing a background script that can upload phenotypes and phenotyping spreadsheets is a problem
because images were made to be uploaded using a catalyst context. But, we don't actually need the 
full catalyst object, just database schemas and a few config keys. This module creates a simple
shim for the catalyst info we need to upload images from a background script.

Right now, this is only implemented for use with upload_phenotypes.pl, but it could also be used
in other background scripts that need to simulate a catalyst object. 

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use Moose;
use namespace::autoclean;

use Carp;
use Config::JFDI;

=head1 ATTRIBUTES

=head2 basepath

The site checkout the script is running out of. The configuration is read from here, and it replaces
whatever basepath the configuration files themselves name, since the script was told where it is
actually running.

=cut

has 'basepath' => (
    isa => 'Str',
    is => 'ro',
    required => 1
);

=head2 username

The name of the user whose upload the script is processing. Reused code that would otherwise read
this off the logged in user takes it from here instead.

=cut

has 'username' => (
    isa => 'Str',
    is => 'ro',
    required => 1
);

=head2 schemas

Hashref of already connected schemas, keyed by class name. These are what dbic_schema() hands back.

=cut

has 'schemas' => (
    isa => 'HashRef',
    is => 'ro',
    default => sub { {} }
);

=head2 config

The site configuration, in the same shape Catalyst holds it.

=cut

has 'config' => (
    isa => 'HashRef',
    is => 'ro',
    lazy_build => 1
);

sub _build_config {
    my $self = shift;

    my $config = Config::JFDI->open(
        name => 'sgn',
        path => $self->basepath(),
        substitute => {
            UID       => sub { $> },
            USERNAME  => sub { (getpwuid($>))[0] },
            GID       => sub { $) },
            GROUPNAME => sub { (getgrgid($)))[0] },
        },
        default => {
            name     => 'SGN',
            home     => $self->basepath(),
            basepath => $self->basepath()
        }
    ) || croak "Failed to load the sgn configuration files in ".$self->basepath();

    $config->{basepath} = $self->basepath();

    return $config;
}

=head1 METHODS

=head2 get_conf($name)

Returns a configuration value. Dies if the variable is not set, the same way the site does, so that
a missing setting is reported instead of being treated as empty.

=cut

sub get_conf {
    my $self = shift;
    my $name = shift;

    croak "conf variable '$name' not set, and no default provided"
        unless exists $self->config->{$name};

    return $self->config->{$name};
}

=head2 dbic_schema($class)

Returns the connected schema for a class. The schema name and person id that the Catalyst version
takes are accepted and ignored, since the script connects its schemas itself.

=cut

sub dbic_schema {
    my $self = shift;
    my $class = shift;

    my $schema = $self->schemas->{$class};
    if (!$schema) {
        croak "No $class schema was given to this script context. Connect it in the script and pass it in.";
    }

    return $schema;
}

=head2 dbc

Returns something that answers dbh(), for code that asks the context for a database handle.

=cut

sub dbc {
    my $self = shift;

    return SGN::ScriptContext::DBC->new({ schema => $self->dbic_schema('Bio::Chado::Schema') });
}

__PACKAGE__->meta->make_immutable();

package SGN::ScriptContext::DBC;

# Stands in for the connection object the context hands out, which is only ever asked for its
# database handle.

use Moose;
use namespace::autoclean;

has 'schema' => (
    is => 'ro',
    required => 1
);

sub dbh {
    my $self = shift;
    return $self->schema->storage->dbh();
}

__PACKAGE__->meta->make_immutable();

1;
