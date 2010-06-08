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

# the HTML::FormFu search form
sub _build_form {
    my ($self) = @_;

    my $form = HTML::FormFu->new(Load(<<EOY));
      method: POST
      attributes:
        name: organism_search_form
      elements:
          - type: Text
            name: species
            label: Species
            size: 60

          - type: Text
            name: common_name
            label: Common Name
            size: 60

          - type: Submit
            name: submit
EOY

    $form->stash->{schema} = $self->schema;

    return $form;
}

sub search {
    my ($self, $c) = @_;

    my $req = $c->req;
    my $form = $self->_build_form;
    $form->process( $req );

    my $results;
    if( $form->submitted_and_valid ) {
        $results = $self->_do_organism_search( $c, $form );
    }

    $c->forward_to_mason_view(
        '/organism/search.mas',
        form    => $form,
        results => $results,
       );
}

sub _do_organism_search {
    my ( $self, $c, $form ) = @_;

    my $rs = $self->schema->resultset('Organism::Organism');

    if( my $species = $form->param_value('species') ) {
        $rs = $rs->search({ 'lower(species)' => {  like => '%'.lc( $species ).'%' }});
    }

    if( my $common = $form->param_value('common_name') ) {
        $rs = $rs->search({ 'lower(common_name)' => {  like => '%'.lc( $common ).'%' }});
    }

    return $rs;
}


__PACKAGE__->meta->make_immutable;
1;
