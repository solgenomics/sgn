package SGN::Controller::Vector;

=head1 NAME

SGN::Controller::Stock - Catalyst controller for pages dealing with
stocks (e.g. accession, population, etc.)

=cut

use Moose;
use namespace::autoclean;
use YAML::Any qw/LoadFile/;

use URI::FromHash 'uri';
use List::Compare;
use File::Temp qw / tempfile /;
use File::Slurp;
use JSON::Any;
use JSON;

use CXGN::Chado::Stock;
use SGN::View::Stock qw/stock_link stock_organisms stock_types breeding_programs /;
use Bio::Chado::NaturalDiversity::Reports;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Chado::Publication;
use CXGN::Genotype::DownloadFactory;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);

=head1 PUBLIC ACTIONS

=head2 create new vector

=cut

sub vector_new :Path('/vector/new') Args(0) {
    my ($self, $c ) = @_;
    my @editable_vector_props = split ',',$c->get_conf('editable_vector_props');
    $c->stash(
        

        stock_types => stock_types($self->schema),
        sp_person_autocomplete_uri => '/ajax/people/autocomplete',
        editable_vector_props => \@editable_vector_props,
        template => '/stock/add_vector.mas'
	);

}

=head2 stock search using jQuery data tables

=cut

sub vector_search :Path('/search/vectors') Args(0) {
    my ($self, $c ) = @_;
    my @editable_vector_props = split ',',$c->get_conf('editable_vector_props');
    $c->stash(
	template => '/search/vectors.mas',

    stock_types => stock_types($self->schema),
	sp_person_autocomplete_uri => '/ajax/people/autocomplete',
    editable_vector_props => \@editable_vector_props
	);

}



# sub _validate_pair {
#     my ($self,$c,$key,$value) = @_;
#     $c->throw( is_client_error => 1, public_message => "$value is not a valid value for $key" )
#         if ($key =~ m/_id$/ and $value !~ m/\d+/);
# }




__PACKAGE__->meta->make_immutable;
