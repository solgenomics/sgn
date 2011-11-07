package SGN::Controller::Search::Feature;
use Moose;
use namespace::autoclean;

use URI::FromHash 'uri';
use YAML::Any;
use JSON;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'default_page_size' => (
    is      => 'ro',
    default => 20,
);

=head1 PUBLIC ACTIONS

=head2 search

Interactive search interface for features.

Public path: /search/features

=cut

sub oldsearch : Path('/feature/search') Args(0) {
    $_[1]->res->redirect( '/search/features', 301 );
}

sub search :Path('/search/features') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        template => '/feature/search.mas',
    );
    $c->forward('View::Mason');
}

sub search_json :Path('/search/features/search_service') Args(0) {
    my ( $self, $c ) = @_;

    my $params = $c->req->params;
    $c->stash->{search_args} = {
        map {
            $_ => $params->{$_},
        } qw( organism type name )
    };

    my $rs = $c->forward('make_feature_search_rs');

    my $total = $rs->count;

    # do sorting and paging
    $rs = $rs->search(
        undef,
        {
          prefetch => [ 'type', 'organism' ],
          page => $params->{'page'} || 1,
          rows => $params->{'page_size'} || $self->default_page_size,
          order_by => {
              '-'.(lc $params->{dir} || 'asc' )
              =>
              ( {
                  'type'     => 'type.name',
                  'organism' => 'organism.species',
                  'name'     => 'me.name',
                }->{lc $params->{'sort'}}
                || 'feature_id'
              )
          },
        },
      );

    $c->res->body( to_json( {
        success    => JSON::true,
        totalCount => $total,
        data => [
            map { {
                organism   => $_->organism->species,
                type       => $_->type->name,
                name       => $_->name,
                feature_id => $_->feature_id,
            } }
            $rs->all
        ],
    }));

}

# assembles a DBIC resultset for the search based on the submitted
# form values
sub make_feature_search_rs : Private {
    my ( $self, $c ) = @_;

    my $args = $c->stash->{search_args};

    my $schema = $c->dbic_schema('Bio::Chado::Schema','sgn_chado');
    my $rs = $schema->resultset('Sequence::Feature');

    if( my $name = $args->{'name'} ) {
        $rs = $rs->search({ 'me.name' => { ilike => '%'.$name.'%' }});
    }

    if( my $type = $args->{'type'} ) {
        my $type_rs = $schema->resultset('Cv::Cvterm')
                             ->search({ 'lower(name)' => lc $type });
        $rs = $rs->search({ 'me.type_id' => { -in => $type_rs->get_column('cvterm_id')->as_query }});
    }

    if( my $organism = $args->{'organism'} ) {
        my $organism_rs = $schema->resultset('Organism::Organism')
                                 ->search({ species => { -ilike => '%'.$organism.'%' }});
        $rs = $rs->search({ 'me.organism_id' => { -in => $organism_rs->get_column('organism_id')->as_query } });
    }

    $c->stash->{search_resultset} = $rs;
}

1;

