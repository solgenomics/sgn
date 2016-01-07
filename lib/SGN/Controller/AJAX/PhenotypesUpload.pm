
=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for uploading phenotype spreadsheets

=head1 DESCRIPTION

Uploading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Naama Menda <nm249@cornell.edu>
Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesUpload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use List::MoreUtils qw /any /;
use SGN::View::ArrayElements qw/array_elements_simple_view/;
use CXGN::Login;
use CXGN::People::Login;
use CXGN::Stock::StockTemplate;
use JSON -support_by_pp;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_phenotype_verify :  Path('/ajax/phenotype/upload_verify') : ActionClass('REST') { }
sub upload_phenotype_verify_POST : Args(0) {
    print STDERR "Check1: ".localtime();
    my ($self, $c) = @_;
    my $uploader = CXGN::UploadFile->new();
    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
    my $upload = $c->req->upload('upload_phenotype_file_input');

    my $subdirectory;
    my $validate_type;
    my $file_type = $c->req->param('upload_phenotype_file_type');
    if ($file_type eq "spreadsheet") {
	print STDERR "Spreadsheet \n";
	$subdirectory = "spreadsheet_phenotype_upload";
	$validate_type = "phenotype spreadsheet";
    } 
    elsif ($file_type eq "fieldbook") {
	print STDERR "Fieldbook \n";
	$subdirectory = "tablet_phenotype_upload";
	$validate_type = "field book";
    }

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my @success_status;
    my @warning_status;
    my @error_status;

    my $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
	push @error_status, "Could not save file $upload_original_name in archive.";
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    unlink $upload_tempfile;
    push @success_status, "File $upload_original_name saved in archive.";

    ## Validate and parse uploaded file
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path);
    if (!$validate_file) {
	push @error_status, "Archived file not valid: $upload_original_name.";
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    push @success_status, "File valid: $upload_original_name.";

    print STDERR "Check2: ".localtime();

    ## Set metadata
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
    my $person_id=CXGN::Login->new($c->dbc->dbh)->has_session();
    my $operator=CXGN::People::Login->new($c->dbc->dbh, $person_id)->get_username();
    $phenotype_metadata{'operator'}="$operator"; 
    $phenotype_metadata{'date'}="$timestamp";
    push @success_status, "File metadata set.";

    print STDERR "Check3: ".localtime();

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path);
    if (!$parsed_file) {
	push @error_status, "Error parsing file $upload_original_name.";
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    if ($parsed_file->{'error'}) {
	push @error_status, $parsed_file->{'error'};
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    my %parsed_data = %{$parsed_file->{'data'}};
    my @plots = @{$parsed_file->{'plots'}};
    my @traits = @{$parsed_file->{'traits'}};
    push @success_status, "File data successfully parsed.";

    print STDERR "Check4: ".localtime();

    print STDERR "verify phenotypes from uploaded file\n";
    my ($verified_warning, $verified_error) = $store_phenotypes->verify($c,\@plots,\@traits, \%parsed_data, \%phenotype_metadata);

    if ($verified_error) {
	push @error_status, $verified_error;
	$c->stash->{rest} = {success => \@success_status, error => \@error_status };
	return;
    }
    if ($verified_warning) {
	push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    print STDERR "Check5: ".localtime();

    $c->stash->{rest} = {success => \@success_status, warning => \@warning_status, error => \@error_status};
}

sub upload_phenotype_store :  Path('/ajax/phenotype/upload_store') : ActionClass('REST') { }
sub upload_phenotype_store_POST : Args(0) {
print STDERR "Check1: ".localtime();
    my ($self, $c) = @_;
    my $uploader = CXGN::UploadFile->new();
    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();

    my $subdirectory;
    my $validate_type;
    my $file_type = $c->req->param('upload_phenotype_file_type');
    if ($file_type eq "spreadsheet") {
	$subdirectory = "spreadsheet_phenotype_upload";
	$validate_type = "phenotype spreadsheet";
    } 
    elsif ($file_type eq "fieldbook") {
	$subdirectory = "tablet_phenotype_upload";
	$validate_type = "field book";
    }
    my $upload = $c->req->upload('upload_phenotype_file_input');
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my @success_status;
    my @error_status;

    my $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
	push @error_status, "Could not save file $upload_original_name in archive.";
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    unlink $upload_tempfile;
    push @success_status, "File $upload_original_name saved in archive.";

    ## Validate and parse uploaded file
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path);
    if (!$validate_file) {
	push @error_status, "Archived file not valid: $upload_original_name.";
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    push @success_status, "File valid: $upload_original_name.";

    print STDERR "Check2: ".localtime();

    ## Set metadata
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
    my $person_id=CXGN::Login->new($c->dbc->dbh)->has_session();
    my $operator=CXGN::People::Login->new($c->dbc->dbh, $person_id)->get_username();
    $phenotype_metadata{'operator'}="$operator"; 
    $phenotype_metadata{'date'}="$timestamp";
    push @success_status, "File metadata set.";

    print STDERR "Check3: ".localtime();

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path);
    if (!$parsed_file) {
	push @error_status, "Error parsing file $upload_original_name.";
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    if ($parsed_file->{'error'}) {
	push @error_status, $parsed_file->{'error'};
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
	return;
    }
    my %parsed_data = %{$parsed_file->{'data'}};
    my @plots = @{$parsed_file->{'plots'}};
    my @traits = @{$parsed_file->{'traits'}};
    push @success_status, "File data successfully parsed.";

    print STDERR "Check4: ".localtime();

    print STDERR "verify phenotypes from uploaded file\n";
    my ($verified_warning, $verified_error) = $store_phenotypes->verify($c,\@plots,\@traits, \%parsed_data, \%phenotype_metadata);

    if ($verified_error) {
	push @error_status, $verified_error;
	$c->stash->{rest} = {success => \@success_status, error => \@error_status };
	return;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    print STDERR "Store phenotypes from uploaded file\n";
    my $stored_phenotype_error = $store_phenotypes->store($c,\@plots,\@traits, \%parsed_data, \%phenotype_metadata);

    if ($stored_phenotype_error) {
	push @error_status, $stored_phenotype_error;
	$c->stash->{rest} = {success => \@success_status, error => \@error_status};
        return;
    }
    push @success_status, "File data successfully stored.";

    print STDERR "Check5: ".localtime();

    $c->stash->{rest} = {success => \@success_status, error => \@error_status};
}


#########
1;
#########
