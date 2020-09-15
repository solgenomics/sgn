
=head1 NAME

SGN::Controller::AJAX::Transcript - a REST controller class to provide the
backend for objects linked with transcripts (AKA unigenes)

=head1 DESCRIPTION

Browse the unigene database for selecting unigenes to be linked with other objects

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>

=cut

package SGN::Controller::AJAX::Transcript;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


=head2 autocomplete

Public Path: /ajax/transcript/autocomplete

Autocomplete a unigene name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $unigene_name = $c->request->param("term");
    my $current      = $c->request->param('current') ; #pass this param for printing only current unigenes
    my $organism = $c->request->param('organism');
    my ($organism_c, $status_c);
   my $dbh = $c->dbc->dbh;
    my $query  = "SELECT unigene_id, unigene_build_id, nr_members, build_nr,  database_name, sequence_name, status FROM sgn.unigene LEFT JOIN sgn.unigene_build using(unigene_build_id) WHERE unigene_id = ? ";

    my $sth= $dbh->prepare($query);
    my @response_list;
    $unigene_name =~ s/SGN.?U?//i;
    if (looks_like_number($unigene_name) ) {
        $sth->execute($unigene_name);
        while (my ($unigene_id, $build_id, $nr_members, $build_nr, $db_name, $seq_name, $build_status) = $sth->fetchrow_array() ) {
            my $unigene = CXGN::Transcript::Unigene->new($dbh, $unigene_id);
            my $unigene_build = $unigene->get_unigene_build;
            my $unigene_organism = $unigene_build->get_common_name();
            if ($organism && $unigene_organism ne $organism)  { $organism_c = 1; }
            if ($current   && $build_status ne "C") { $status_c = 1; }
            if (!$organism_c && !$status_c) {
                push @response_list, "SGN-U$unigene_id--build $build_id--$nr_members members";
            }
        }
    }
    $c->stash->{rest} = \@response_list;
}

###
1;#
###
