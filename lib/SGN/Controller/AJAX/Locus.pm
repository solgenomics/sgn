=head1 NAME

SGN::Controller::AJAX::Locus - a REST controller class to provide the
backend for objects linked with loci

=head1 DESCRIPTION

Browse the locus database for selecting loci to be linked with other objects

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>
Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::Locus;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



=head2 autocomplete

Public Path: /ajax/locus/autocomplete

Autocomplete a locus name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('term');
    my $common_name_id = $c->req->param('common_name_id');
    # trim and regularize whitespace
    $term =~ s/(^\s+|\s+)$//g;
    $term =~ s/\s+/ /g;

    my @results;
    my $q =  "SELECT  locus_symbol, locus_name, allele_symbol, is_default FROM locus join allele using (locus_id) where (locus_name ilike '%$term%' OR  locus_symbol ilike '%$term%') and locus.obsolete = 'f' and allele.obsolete='f' limit 20"; #and common_name_id = ?
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute;
    while (my ($locus_symbol, $locus_name, $allele_symbol, $is_default) = $sth->fetchrow_array ) {
        my $allele_data = "Allele: $allele_symbol"  if !$is_default  ;
        no warnings 'uninitialized';
        push @results , "$locus_name ($locus_symbol) $allele_data";
    }
    $c->{stash}->{rest} = \@results;
}

1;
