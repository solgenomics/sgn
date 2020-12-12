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

sub protocol_page :Path("/breeders_toolbox/protocol") Args(1) {
    my $self = shift;
    my $c = shift;
    my $protocol_id = shift;

    if (!$c->user()) {
	
	my $url = '/' . $c->req->path;	
	$c->res->redirect("/user/login?goto_url=$url");
	
    } else {
     
	my $protocol = CXGN::Genotype::Protocol->new({
	    bcs_schema => $self->schema,
	    nd_protocol_id => $protocol_id
						     });
	$c->stash->{protocol_id} = $protocol_id;
	$c->stash->{protocol_name} = $protocol->protocol_name;
	$c->stash->{protocol_description} = $protocol->protocol_description;
	$c->stash->{markers} = $protocol->markers || {};
	$c->stash->{marker_names} = $protocol->marker_names || [];
	$c->stash->{header_information_lines} = $protocol->header_information_lines || [];
	$c->stash->{reference_genome_name} = $protocol->reference_genome_name;
	$c->stash->{species_name} = $protocol->species_name;
	$c->stash->{create_date} = $protocol->create_date;
	$c->stash->{sample_observation_unit_type_name} = $protocol->sample_observation_unit_type_name;
	$c->stash->{template} = '/breeders_toolbox/genotyping_protocol/index.mas';
    }
}

1;
