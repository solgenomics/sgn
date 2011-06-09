package SGN::Controller::Organism::Search;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use HTML::FormFu;
use URI::FromHash 'uri';
use YAML::Any;

has 'default_page_size' => (
    is => 'ro',
    default => 20,
   );


sub search : Path('/organism/search') {
    my ($self, $c) = @_;

    $c->forward( 'get_taxa_choices' );
    $c->forward( 'build_form' );

    my $form = $c->stash->{form};
    $form->process( $c->req );

    my $results;
    if( $form->submitted_and_valid ) {
        $results = $self->_make_organism_search_rs( $c, $form );
    }

    $c->stash(
        template =>  '/organism/search.mas',
        form     => $form,
        results  => $results,
        pagination_link_maker => sub {
            return uri( query => { %{$form->params}, page => shift } );
        },
       );
}


# the HTML::FormFu search form
sub build_form : Private {
    my ( $self, $c ) = @_;

    my $form = $c->stash->{form} =
         HTML::FormFu->new(Load(<<EOY));
      method: POST
      attributes:
        name: organism_search_form
        id: organism_search_form
      elements:
          - type: Text
            name: species
            label: Species
            size: 30

        # hidden form values for page and page size
          - type: Hidden
            name: page
            value: 1
          - type: Hidden
            name: page_size
            default: 20

          - type: Text
            name: common_name
            label: Common Name
            size: 30

          - type: Checkboxgroup
            name: taxa
            label: Taxa

          - type: Submit
            name: submit
EOY

    # set the taxa multi-select choices from the db
    $form->get_element({ name => 'taxa'})
         ->options( $c->stash->{taxa_choices} );

    return $form;
}

# assembles a DBIC resultset for the search based on the submitted
# form values
#
# notice that this is very similar to the old search framework's
# from_request() method
sub _make_organism_search_rs {
    my ( $self, $c, $form ) = @_;

    my $rs = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')->resultset('Organism::Organism');

    # species
    if( my $species = $form->param_value('species') ) {
        $rs = $rs->search({ 'lower(me.species)' => {  like => '%'.lc( $species ).'%' }});
    }

    # common_name
    if( my $common = $form->param_value('common_name') ) {
        $rs = $rs->search({ 'lower(common_name)' => {  like => '%'.lc( $common ).'%' }});
    }

    # taxa
    if( my @taxa = $form->param_list('taxa') ) {
        $rs = $rs->search({ 'type.cvterm_id' => \@taxa },
                          { join => {
                              'phylonode_organisms' => {
                                  'phylonode' => 'type',
                              },
                            },
                          },
                         );
    }

    # page number and page size, and order by species name
    $rs = $rs->search( undef,
                       { page     => $form->param_value('page')      || 1,
                         rows     => $form->param_value('page_size') || $self->default_page_size,
                         order_by => 'species',
                       },
                     );

    return $rs;
}

# makes [ [cvterm_id, name], ... ] for all the available taxa
# from phylonode.type_id
sub get_taxa_choices : Private {
    my ( $self, $c ) = @_;

    $c->stash->{taxa_choices} = [
        map [$_->cvterm_id,$_->name],
        $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
             ->resultset('Organism::Organism')
             ->search_related('phylonode_organisms')
             ->search_related('phylonode')
             ->search_related(
                 'type',
                 {},
                 { select   => [qw[ cvterm_id name ]],
                   group_by => [qw[ cvterm_id name ]],
                   order_by => 'cvterm_id',
                 },
                )

      ];
}


__PACKAGE__->meta->make_immutable;
1;
