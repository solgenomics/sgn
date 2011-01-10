
use strict;

package SGN::Controller::AJAX::Organism;

use Moose;
use List::MoreUtils qw | any |;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config( 
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );



=head2 sol100_image_tag

=cut

sub sol100_image_tag :Path('/organism/sol100/image_tag') :ActionClass('REST') {}

sub sol100_image_tag_GET { 
    my ($self, $c) = @_;

    

}

=head2 add_sol100_organism

Public Path: /organism/sol100/add_organism

POST target to add an organism to the set of sol100 organisms.  Takes
one param, C<species>, which is the exact string species name in the
DB.

After adding, redirects to C<view_sol100>.

=cut

sub add_sol100_organism :Path('/organism/sol100/add_organism') :ActionClass('REST') {}

sub add_sol100_organism_POST { 
    my ( $self, $c ) = @_;

    my $species = $c->req->param("species");
 #   my $property = $c->req->param("property");
    my $value    = $c->req->param("value");

    

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

#    if ($property && $value) { 
#	$organism->create_organismprops(
#	    { $property => $value },
#	    { autocreate => 1 },
#	    );

    
    $c->forward("SGN::Controller::Organism", 'invalidate_organism_tree_cache', ['sol100']);
    
    $c->stash->{rest} = [ 'success' ];

    #$c->res->redirect($c->uri_for_action('/organism/view_sol100'));
}


=head2 add_organism_prop

=cut

sub add_organism_prop:Path('/ajax/organism/add_prop') :ActionClass('REST') {}

sub add_organism_prop_GET :Args(0) {
  my ( $self, $c ) = @_;
  
  my $organism_id = $c->req->param("organism_id");
  my $prop = $c->req->param("prop");
  my $value    = $c->req->param("value");

  print STDERR "PROP: $prop\n";

  if (any { $prop eq $_ } $self->organism_prop_keys()) { 
      
      my $organism = $c->dbic_schema('Bio::Chado::Schema','sgn_chado')
	  ->resultset('Organism::Organism')
	  ->search({ organism_id => $organism_id })
	  ->single;

      if (!$organism) { 
	  $c->stash->{rest} = { error => "no organism found for organism_id '$organism_id'" };
	  return;
      }
      
      if ($prop && $value) { 
	  $organism->create_organismprops(
	      { $prop => $value },
	      { autocreate => 1 },
	      );
	  $c->stash->{rest} = ['success'];
	  
	  return;
      
      }
      $c->stash->{rest} = { error => 'need both property and value parameters' };
      
      
  }
  else { 
      $c->stash->{rest} = { error => 'illegal organism prop' };
  }
}

sub organism_prop_keys { 
    my $self = shift;

    return ('Sequencing facility', 'Accessions', 'Project Leader', 'sol100');
}



=head2 autocomplete

Public Path: /organism/autocomplete

Autocomplete an organism species name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete :Path('/organism/autocomplete') :ActionClass('REST') {}

sub autocomplete_GET :Args(0) {
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

  $c->stash->{rest} = \@results;

}



