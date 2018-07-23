package SGN::Controller::GenotypeProtocol;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Trial::Folder;
use CXGN::Genotype::Protocol;

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub protocols_list :Path("/breeders/genotyping_protocols") Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/breeders_toolbox/maps/genotype_protocol_list.mas';
}


sub protocol_page :Path("/breeders/genotyping_protocols") Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $self->schema,
        nd_protocol_id => $protocol_id
    });
    $c->stash->{protocol_id} = $protocol_id;
    $c->stash->{name} = $protocol->protocol_name;
    #$c->stash->{marker_details} = \@markerdetails_window;
    $c->stash->{template} = '/breeders_toolbox/maps/genotype_protocol.mas';
}

1;
