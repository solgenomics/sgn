
=head1 NAME

SGN::Controller::AJAX::DataCollector - a REST controller class to provide the
backend for Data Collector Spreadsheet operations

=head1 DESCRIPTION

Creating and viewing trials

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu> , Alex Ogbonna <aco46@cornell.edu>

=cut

package SGN::Controller::AJAX::DataCollector;

use Moose;
use List::MoreUtils qw /any /;
use Scalar::Util qw(looks_like_number);
use DateTime;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use JSON -support_by_pp;
use Spreadsheet::WriteExcel;
use SGN::View::Trial qw/design_layout_view design_info_view/;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial::TrialLayout;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::UploadFile;
use CXGN::Fieldbook::TraitInfo;
use Data::Dumper;
use Spreadsheet::ParseExcel;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_phenotype_file_for_data_collector : Path('/ajax/datacollector/upload_dc_sheet') : ActionClass('REST') { }

sub upload_phenotype_file_for_data_collector_POST : Args(0) {
  my ($self, $c) = @_;
  my $uploader = CXGN::UploadFile->new();
  my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
  my $parser = CXGN::Phenotypes::ParseUpload->new();
  my $upload = $c->req->upload('DataCollector_upload_file');
  my $upload_original_name = $upload->filename();
  my $upload_tempfile = $upload->tempname;
  my $subdirectory = "data_collector_phenotype_upload";
  my $archived_filename_with_path;
  my $md5;
  my $validate_file;
  my $parsed_file;
  my %parsed_data;
  my @plots;
  my @traits;
  my %phenotype_metadata;
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();

  print STDERR "Move uploaded file to archive: $uploader\n";

  print STDERR "\n\nTimestamp: $timestamp\n";

  ## Store uploaded temporary file in archive
  $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
  $md5 = $uploader->get_md5($archived_filename_with_path);
  if (!$archived_filename_with_path) {
      $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
      return;
  }
  unlink $upload_tempfile;

  ## Set metadata

  $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
  $phenotype_metadata{'archived_file_type'}="data collector phenotype file";
  $phenotype_metadata{'operator'}="tester_operator"; #####Need to get this from uploaded file
  $phenotype_metadata{'date'}="$timestamp";

  print STDERR "Validate uploaded file\n";

  ## Validate and parse uploaded file
  $validate_file = $parser->validate('datacollector spreadsheet', $archived_filename_with_path);
  if (!$validate_file) {
      $c->stash->{rest} = {error => "File not valid: $upload_original_name",};
      return;
  }

  print STDERR "Parse uploaded file\n";

  $parsed_file = $parser->parse('datacollector spreadsheet', $archived_filename_with_path);
  if (!$parsed_file) {
      $c->stash->{rest} = {error => "Error parsing file $upload_original_name",};
      return;
  }
  if ($parsed_file->{'error'}) {
      $c->stash->{rest} = {error => $parsed_file->{'error'},};
      return;
  }
  %parsed_data = %{$parsed_file->{'data'}};
  @plots = @{$parsed_file->{'plots'}};
  @traits = @{$parsed_file->{'traits'}};

  print STDERR "store phenotypes from uploaded file\n";
  $store_phenotypes->store($c,\@plots,\@traits, \%parsed_data, \%phenotype_metadata);

  if (!$store_phenotypes) {
    $c->stash->{rest} = { error => 'Error storing uploaded file', };
    return;
  }

  $c->stash->{rest} = {success => "1",};

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


1;
