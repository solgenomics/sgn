package SGN::Controller::Search::Phenome;
use Moose;
use namespace::autoclean;
use SGN::View::Stock qw/stock_link stock_organisms stock_types breeding_programs /;

use YAML::Any qw/LoadFile/;

BEGIN { extends 'Catalyst::Controller' }

sub auto : Private {
    $_[1]->stash->{template} = '/search/phenotypes/stub.mas';
}

#DEPRECATED by SGN::Controller::Stock stock_search
#sub stock_search : Path('/search/stocks') Args(0) {
#    my ( $self, $c ) = @_;
#    my $db_name = $c->config->{trait_ontology_db_name} || 'SP'; 
#    my $schema  = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#    $c->stash(
#	template          => '/search/stocks.mas',
#        stock_types       => stock_types($schema), 
#	organisms         => stock_organisms($schema) ,
#	trait_db_name     => $db_name,
#	breeding_programs => breeding_programs($schema),
#	);
#}

sub qtl_search : Path('/search/phenotypes/qtl') Path('/search/phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/phenotypes/qtl.mas';
}

sub trait_search : Path('/search/phenotypes/traits') Args(0) {
    my $self = shift;
    my $c = shift;
    my $db_name = $c->config->{trait_ontology_db_name} || 'SP';
    $c->stash->{db_name} = $db_name;
    $c->stash(
	template => '/search/phenotypes/traits.mas',
	trait_db_name => $db_name,
	);
}


1;
