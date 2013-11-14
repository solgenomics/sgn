
=head1 NAME

SGN::Controller::AJAX::Accessions - a REST controller class to provide the
backend for managing accessions

=head1 DESCRIPTION

Managing accessions

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::Accessions;

use Moose;
use JSON -support_by_pp;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub verify_accession_list : Path('/ajax/accession_list/verify') : ActionClass('REST') { }

sub verify_accession_list_POST : Args(0) {
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $accession_list = $c->req->param('accession_list');
  $c->stash->{rest} = {success => "1",};
}

1;
