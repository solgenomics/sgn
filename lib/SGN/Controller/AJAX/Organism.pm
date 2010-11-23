
use strict;

package SGN::Controller::AJAX::Organism;
use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config( 
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );



=head2 add_sol100_organism

Public Path: /organism/sol100/add_organism

POST target to add an organism to the set of sol100 organisms.  Takes
one param, C<species>, which is the exact string species name in the
DB.

After adding, redirects to C<view_sol100>.

=cut

sub add_sol100_organism :Path('/organism/sol100/add_organism') :ActionClass('REST');

sub autocomplete :Path('/organism/autocomplete') :ActionClass('REST');

sub add_sol100_organism_POST { 
    my ( $self, $c ) = @_;

    my $species = $c->req->body_parameters->{species};
    my $property = $c->req->body_parameters->{property};
    my $value    = $c->req->body_parameters->{value};

    my $organism = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                     ->resultset('Organism::Organism')
                     ->search({ species => { ilike => $c->req->body_parameters->{species} }})
                     ->single;



    # if this fails, it will throw an acception and will (probably
    # rightly) be counted as a server error
    $organism->create_organismprops(
        { 'sol100' => 1 },
        { autocreate => 1 },
       );

    if ($property && $value) { 
	$organism->create_organismprops(
	    { $property => $value },
	    { autocreate => 1 },
	    );
    }

    print STDERR "NOW WE ARE HERE...\n";
    $c->forward('invalidate_organism_tree_cache', ['sol100']);

    $c->res->redirect( $c->uri_for( $self->action_for('view_sol100')));
}


=head2 autocomplete

Public Path: /organism/autocomplete

Autocomplete an organism species name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete_POST :Args(0) {
  my ( $self, $c ) = @_;

  my $term = $c->req->param('term');
  # trim and regularize whitespace
  $term =~ s/(^\s+|\s+)$//g;
  $term =~ s/\s+/ /g;

  my $s = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
                  ->resultset('Organism::Organism');
#  my $s = $c->stash->{organism_set};

  my @results = $s->search({ species => { ilike => '%'.$term.'%' }},
                           { rows => 15 },
                          )
                  ->get_column('species')
                  ->all;

  $self->{stash}->{rest} = \@results;

}

