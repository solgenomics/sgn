
=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for uploading phenotype spreadsheets

=head1 DESCRIPTION

Uploading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Naama Menda <nm249@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesUpload;

use Moose;
use Try::Tiny;
use File::Slurp;
use List::MoreUtils qw /any /;
use SGN::View::ArrayElements qw/array_elements_simple_view/;
use CXGN::Stock::StockTemplate;
use JSON -support_by_pp;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_phenotype_spreadsheet :  Path('/ajax/phenotype/upload_spreadsheet') : ActionClass('REST') { }

sub upload_phenotype_spreadsheet_POST : Args(0) {
  my ($self, $c) = @_;
  my $error;
  my $stock_template = new CXGN::Stock::StockTemplate;
  my $upload = $c->req->upload('upload_phenotype_spreadsheet_file_input');
  my $upload_file_name;
  my $upload_file_temporary_directory;
  my $upload_file_temporary_full_path;

  my $archive_path = $c->config->{archive_path};
  if (!-d $archive_path) {
    mkdir $archive_path;
  }

  if (!$c->user()) {  #user must be logged in
    $c->stash->{rest} = {error => "You need to be logged in to upload a file." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a file." };
    return;
  }
  if (!$upload) { #upload file required
    $c->stash->{rest} = {error => "File upload failed: no file name received"};
    return;
  }
  $upload_file_name = $upload->tempname;
  $upload_file_name =~ s/\/tmp\///;
  $upload_file_temporary_directory = $archive_path.'/tmp/';
  if (!-d $upload_file_temporary_directory) {
    mkdir $upload_file_temporary_directory;
  }
  $upload_file_temporary_full_path = $upload_file_temporary_directory.$upload_file_name;
  print "full path: $upload_file_temporary_full_path\n";
  write_file($upload_file_temporary_full_path, $upload->slurp);

  try {
    $stock_template->parse($upload_file_temporary_full_path);
  } catch {
    $c->stash->{rest} = {error => "Error parsing spreadsheet: $_"};
    $error=1;
  };
  if ($error) {
    return;
  }
  if ($stock_template->parse_errors()) {
    my $parse_errors_html = array_elements_simple_view($stock_template->parse_errors());
    $c->stash->{rest} = {error_list_html => $parse_errors_html };
    return;
  }

  try {
    $stock_template->verify();
  } catch {
    $c->stash->{rest} = {error => "Error verifying spreadsheet: $_"};
    $error=1;
  };
  if ($error) {
    return;
  }
  if ($stock_template->verify_errors()) {
    my $verify_errors_html = array_elements_simple_view($stock_template->verify_errors());
    $c->stash->{rest} = {error_list_html => $verify_errors_html };
    return;
  }

  try {
    $stock_template->store();
  } catch {
    $c->stash->{rest} = {error => "Error storing spreadsheet: $_"};
    $error=1;
  };
  if ($error) {
    return;
  }
  if ($stock_template->store_errors()) {
    my $store_errors_html = array_elements_simple_view($stock_template->store_errors());
    $c->stash->{rest} = {error_list_html => $store_errors_html };
    return;
  }
}


#########
1;
#########
