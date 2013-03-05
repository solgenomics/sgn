package SGN::Controller::Search::Phenome;
use Moose;
use namespace::autoclean;

use HTML::FormFu;
use YAML::Any qw/LoadFile/;

BEGIN { extends 'Catalyst::Controller' }

sub auto : Private {
    $_[1]->stash->{template} = '/search/phenotypes/stub.mas';
}

sub stock_search : Path('/search/phenotypes/stock') Args(0) {
    my ( $self, $c ) = @_;
    my $form = HTML::FormFu->new(LoadFile($c->path_to(qw{forms stock stock_search.yaml})));
    $c->stash(
        template => '/search/phenotypes/stock.mas',
        form     => $form,
        schema   => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
    );
}

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
    $c->stash->{template} = '/search/phenotypes/traits.mas';
}


1;
