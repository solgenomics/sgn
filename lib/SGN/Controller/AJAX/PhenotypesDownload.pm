
=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for downloading phenotype spreadsheets

=head1 DESCRIPTION

Downloading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesDownload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use List::MoreUtils qw /any /;
use SGN::View::ArrayElements qw/array_elements_simple_view/;
use CXGN::Stock::StockTemplate;
use JSON -support_by_pp;
use CXGN::Phenotypes::CreateSpreadsheet;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub download_phenotype_spreadsheet :  Path('/ajax/phenotype/download_spreadsheet') : ActionClass('REST') { }

sub download_phenotype_spreadsheet_POST : Args(0) {
  print STDERR "phenotype download controller\n";
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_id = $c->req->param('trial_id');
  my $list_id = $c->req->param('list_id');
  my $create_spreadsheet = CXGN::Phenotypes::CreateSpreadsheet->new({schema => $schema, trial_id => $trial_id, list_id => $list_id});
  my $created = $create_spreadsheet->create();
  my $filename;
  if (!$created) {
    $c->stash->{rest} = {error => "Could not create phenotype spreadsheet"};
    return;
  }

  if (!$create_spreadsheet->has_filename()) {
    $c->stash->{rest} = {error => "Could not create phenotype spreadsheet file"};
    return;
  }
  $filename = $create_spreadsheet->get_filename();

  $c->stash->{rest} = {success => 1 };

}


#########
1;
#########
