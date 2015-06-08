
=head1 NAME

SGN::Controller::AJAX::PhenotypesDownload - a REST controller class to provide the
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
use CXGN::Trial::Download;
use Tie::UrlEncoder; our(%urlencode);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub create_phenotype_spreadsheet :  Path('/ajax/phenotype/create_spreadsheet') : ActionClass('REST') { }

sub create_phenotype_spreadsheet_GET : Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->forward('create_phenotype_spreadsheet_POST');
}

sub create_phenotype_spreadsheet_POST : Args(0) {
  print STDERR "phenotype download controller\n";
  my ($self, $c) = @_;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $trial_id = $c->req->param('trial_id');
  my $trait_list_ref = $c->req->param('trait_list');
  my $format = $c->req->param('format') || "ExcelBasic";

  my @trait_list = @{_parse_list_from_json($c->req->param('trait_list'))};
  my $dir = $c->tempfiles_subdir('/download');
  my $rel_file = $c->tempfile( TEMPLATE => 'download/downloadXXXXX');
  my $tempfile = $c->config->{basepath}."/".$rel_file;

  my $create_spreadsheet = CXGN::Trial::Download->new( 
      { 
	  bcs_schema => $schema,
	  trial_id => $trial_id,
	  trait_list => \@trait_list,
	  filename => $tempfile,
	  format => $format,
      });

      my $error = $create_spreadsheet->download();

    print STDERR "DOWNLOAD FILENAME = ".$create_spreadsheet->filename()."\n";
    print STDERR "RELATIVE  = $rel_file\n";

if ($error) { 
$c->stash->{rest} = { error => $error };
return;
}
    $c->stash->{rest} = { filename => $urlencode{$rel_file} };

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
