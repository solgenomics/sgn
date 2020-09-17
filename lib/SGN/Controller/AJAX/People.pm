
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

use Data::Dumper;
use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::People::Schema;
use CXGN::People::Roles;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );



=head2 autocomplete

Public Path: /ajax/people/autocomplete

Autocomplete a person name.  Takes a single GET param,
    C<person>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(1) {
    my ( $self, $c , $print_id ) = @_;

    my $person = $c->req->param('term');
    # trim and regularize whitespace
    $person =~ s/(^\s+|\s+)$//g;
    $person =~ s/\s+/ /g;
    my $q = "SELECT sp_person_id, first_name, last_name FROM sgn_people.sp_person
             WHERE lower(first_name) like ? OR lower(last_name) like ?
             LIMIT 20";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( lc "$person\%" , lc "$person\%" );
    my @results;
    while (my ($sp_person_id, $first_name, $last_name) = $sth->fetchrow_array ) {
        $sp_person_id = $print_id ? "," . $sp_person_id : undef;
        push @results , "$first_name, $last_name $sp_person_id";
    }
    $c->stash->{rest} = \@results;
}

sub people_and_roles : Path('/ajax/people/people_and_roles') : ActionClass('REST') { }

sub people_and_roles_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
    my $sp_persons = $person_roles->get_sp_persons();
    my $sp_roles = $person_roles->get_sp_roles();
    my %results = ( sp_persons => $sp_persons, sp_roles => $sp_roles );
    $c->stash->{rest} = \%results;
}

sub add_person_role : Path('/ajax/people/add_person_role') : ActionClass('REST') { }

sub add_person_role_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user = $c->user();
    if (!$user){
        $c->stash->{rest} = {error=>'You must be logged in first!'};
        $c->detach;
    }
    if (!$user->check_roles("curator")) {
        $c->stash->{rest} = {error=>'You must be logged in with the correct role!'};
        $c->detach;
    }
    my $sp_person_id = $c->req->param('sp_person_id');
    my $sp_role_id = $c->req->param('sp_role_id');
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
    my $add_role = $person_roles->add_sp_person_role($sp_person_id, $sp_role_id);
    $c->stash->{rest} = {success=>1};
}

###
1;

