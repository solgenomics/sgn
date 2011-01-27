
=head1 NAME

SGN::Controller::AJAX::People - a REST controller class to provide the
backend for the sgn_people schema

=head1 DESCRIPTION

REST interface for searching people, getting user data, etc. 

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::People;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
#use CXGN::Phenome::Schema;



BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



=head2 autocomplete

Public Path: /ajax/people/autocomplete

Autocomplete a person name.  Takes a single GET param,
    C<person>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $person = $c->req->param('term');
    # trim and regularize whitespace
    $person =~ s/(^\s+|\s+)$//g;
    $person =~ s/\s+/ /g;

    my $q = "SELECT sp_person_id, first_name, last_name FROM sgn_people.sp_person
             WHERE first_name ilike '%$person%' OR last_name ilike '%$person%'
             LIMIT 20";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute;
    my @results;
    while (my ($sp_person_id, $first_name, $last_name) = $sth->fetchrow_array ) {
        push @results , "$first_name, $last_name";
    }
    $c->{stash}->{rest} = \@results;
}


###
1;

