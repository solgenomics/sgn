package SGN::Controller::GenotypeProtocol;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Trial::Folder;
use CXGN::GenotypeProtocol;

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

    #print STDERR Dumper $protocol_id;

    my $protocol_name = $self->schema()->resultset('NaturalDiversity::NdProtocol')->find({ nd_protocol_id=>$protocol_id })->name();

    #my $protocol = CXGN::GenotypeProtocol->new({ schema => $self->schema, nd_protocol_id => $protocol_id });
    #print STDERR Dumper $protocol->marker_details();
    
    #my $marker_details = $protocol->marker_details();
    #my $markers = $protocol->markers();
    #@$markers = splice @$markers, $page_size;
    #my @markerdetails_window;
    #foreach (@$markers) {
    #    my @marker_info = ($_, $marker_details->{$_} );
    #    push @markerdetails_window, \@marker_info;
    #}
    #print STDERR Dumper \@markerdetails_window;
    
    $c->stash->{protocol_id} = $protocol_id;
    $c->stash->{name} = $protocol_name;
    #$c->stash->{marker_details} = \@markerdetails_window;
    $c->stash->{template} = '/breeders_toolbox/maps/genotype_protocol.mas';
}

1;
