package SGN::Controller::Organism;
use Moose;
use namespace::autoclean;

use HTML::FormFu;
use YAML::Any;

has 'schema' => (
    is       => 'ro',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);


sub search {
    my ($self, $c) = @_;

    my $req = $c->req;
    my $form = $self->_build_form;
    $form->process( $req );

    my $results;
    if( $form->submitted_and_valid ) {
        $results = $self->_make_organism_search_rs( $c, $form );
    }

    $c->forward_to_mason_view(
        '/organism/search.mas',
        form    => $form,
        results => $results,
       );
}


# the HTML::FormFu search form
sub _build_form {
    my ($self) = @_;

    my $form = HTML::FormFu->new(Load(<<EOY));
      method: POST
      attributes:
        name: organism_search_form
        id: organism_search_form
      elements:
          - type: Text
            name: species
            label: Species
            size: 30

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

    $form->stash->{schema} = $self->schema;

    # set the taxa multi-select choices from the db
    $form->get_element({ name => 'taxa'})
         ->options( $self->_taxa_choices );

    return $form;
}

# assembles a DBIC resultset for the search based on the submitted
# form values
sub _make_organism_search_rs {
    my ( $self, $c, $form ) = @_;

    my $rs = $self->schema->resultset('Organism::Organism');

    if( my $species = $form->param_value('species') ) {
        $rs = $rs->search({ 'lower(species)' => {  like => '%'.lc( $species ).'%' }});
    }

    if( my $common = $form->param_value('common_name') ) {
        $rs = $rs->search({ 'lower(common_name)' => {  like => '%'.lc( $common ).'%' }});
    }

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

    return $rs;
}

# makes [ [cvterm_id, name], ... ] for all the available taxa
# from phylonode.type_id
sub _taxa_choices {
    my ($self) = @_;

    return [
        map [$_->cvterm_id,$_->name],
        $self->schema
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
