
=head1 NAME

SGN::Controller::AJAX::PhenotypesDownload - a REST controller class to provide the
backend for downloading phenotype spreadsheets

=head1 DESCRIPTION

Downloading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::DataCollectorDownload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use File::Basename;
use List::MoreUtils qw /any /;
use SGN::View::ArrayElements qw/array_elements_simple_view/;
use CXGN::Stock::StockTemplate;
use JSON -support_by_pp;
use CXGN::Phenotypes::DataCollectorSpreadsheet;
use CXGN::Trial::Download;
use Tie::UrlEncoder; our(%urlencode);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub create_DataCollector_spreadsheet :  Path('/ajax/phenotype/create_DataCollector') : ActionClass('REST') { }

sub create_DataCollector_spreadsheet_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->forward('create_DataCollector_spreadsheet_POST');
}

sub create_DataCollector_spreadsheet_POST : Args(0) {
  print STDERR "phenotype download controller\n";
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_id = $c->req->param('trial_id');
  my $trait_list_ref = $c->req->param('trait_list');
  my $format = $c->req->param('format') || "DataCollectorExcel";
  my $data_level = $c->req->param('data_level') || "plots";

  if ($data_level eq 'plants') {
      my $trial = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });
      if (!$trial->has_plant_entries()) {
          $c->stash->{rest} = { error => "The requested trial (".$trial->get_name().") does not have plant entries. Please create the plant entries first." };
          return;
      }
  }

  my @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
  my $dir = $c->tempfiles_subdir('download');
  my ($fh, $tempfile) = $c->tempfile( TEMPLATE => 'download/'.$format.'_'.$trial_id.'_'.'XXXXX');
  my $file_path = $c->config->{basepath}."/".$tempfile.".xls";
  close($fh);
  move($tempfile, $file_path);
  my $trial_stock_type = $c->req->param('trial_stock_type');
  my $create_spreadsheet = CXGN::Trial::Download->new(
      {
	  bcs_schema => $schema,
	  trial_id => $trial_id,
	  trait_list => \@trait_list,
	  filename => $file_path,
	  format => $format,
      data_level => $data_level,
      trial_stock_type => $trial_stock_type,
      });

  my $spreadsheet_response = $create_spreadsheet->download();

  if ($spreadsheet_response->{error}) {
    print STDERR "Returning with error . . .\n";
    $c->stash->{rest} = { error => $spreadsheet_response->{error} };
    return;
  }

  print STDERR "DOWNLOAD FILENAME = ".$create_spreadsheet->filename()."\n";
  print STDERR "RELATIVE  = $tempfile\n";

  my $file_name = basename($file_path);
  print STDERR "file name= $file_name\n";

  $c->stash->{rest} = { filename => $urlencode{$tempfile.".xls"} };

}

sub _parse_list_from_json {
  my $list_json = shift;
  my $json = new JSON;
  if ($list_json) {
    my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
    #my $decoded_list = decode_json($list_json);
    my @array_of_list_items = @{$decoded_list};
    return \@array_of_list_items;
  }
  else {
    return;
  }
}

#########
1;
#########
