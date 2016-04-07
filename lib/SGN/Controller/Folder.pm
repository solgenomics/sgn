package SGN::Controller::Folder;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub folder_page :Path("/folder") Args(1) {
    my ($self , $c) = @_;

    $c->stash->{template} = '/breeders_toolbox/folder.mas';
}

1;
