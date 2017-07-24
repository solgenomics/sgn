
=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for uploading phenotype spreadsheets

=head1 DESCRIPTION

Uploading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Naama Menda <nm249@cornell.edu>
Alex Ogbonna <aco46@cornell.edu>
Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesUpload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_phenotype_verify :  Path('/ajax/phenotype/upload_verify') : ActionClass('REST') { }
sub upload_phenotype_verify_POST : Args(1) {
    my ($self, $c, $file_type) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $overwrite_values, $image_zip, $user_id) = _prep_upload($c, $file_type, $schema);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }

    my $timestamp = 0;
    if ($timestamp_included) {
        $timestamp = 1;
    }
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>$plots,
        trait_list=>$traits,
        values_hash=>$parsed_data,
        has_timestamps=>$timestamp,
        metadata_hash=>$phenotype_metadata,
        image_zipfile_path=>$image_zip,
    );

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @$error_status, $verified_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }
    if ($verified_warning) {
        push @$warning_status, $verified_warning;
    }
    push @$success_status, "File data verified. Plot names and trait names are valid.";

    $c->stash->{rest} = {success => $success_status, warning => $warning_status, error => $error_status};
}

sub upload_phenotype_store :  Path('/ajax/phenotype/upload_store') : ActionClass('REST') { }
sub upload_phenotype_store_POST : Args(1) {
    my ($self, $c, $file_type) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $overwrite_values, $image_zip, $user_id) = _prep_upload($c, $file_type, $schema);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }
    my $overwrite = 0;
    if ($overwrite_values) {
        $overwrite = 1;
    }
    my $timestamp = 0;
    if ($timestamp_included) {
        $timestamp = 1;
    }

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>$plots,
        trait_list=>$traits,
        values_hash=>$parsed_data,
        has_timestamps=>$timestamp,
        overwrite_values=>$overwrite,
        metadata_hash=>$phenotype_metadata,
        image_zipfile_path=>$image_zip,
    );

    #upload_phenotype_store function redoes the same verification that upload_phenotype_verify does before actually uploading. maybe this should be commented out.
    #my ($verified_warning, $verified_error) = $store_phenotypes->verify($c,$plots,$traits, $parsed_data, $phenotype_metadata);
    #if ($verified_error) {
	#push @$error_status, $verified_error;
	#$c->stash->{rest} = {success => $success_status, error => $error_status };
	#return;
    #}
    #push @$success_status, "File data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    if ($stored_phenotype_error) {
        push @$error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status};
        return;
    }
    if ($stored_phenotype_success) {
        push @$success_status, $stored_phenotype_success;
    }

    if ($image_zip) {
        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $image_error = $image->upload_fieldbook_zipfile($image_zip, $user_id);
        if ($image_error) {
            push @$error_status, $image_error;
        }
    }

    push @$success_status, "Metadata saved for archived file.";

    $c->stash->{rest} = {success => $success_status, error => $error_status};
}

sub _prep_upload {
    my ($c, $file_type, $schema) = @_;
	my @success_status;
	my @error_status;

	my $user = $c->user();
	if (!$user) {
		push @error_status, 'Must be logged in to upload phenotypes!';
		return (\@success_status, \@error_status);
	}

    my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;
    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $timestamp_included;
    my $upload;
    my $subdirectory;
    my $validate_type;
    my $metadata_file_type;
    my $data_level;
    my $image_zip;
    if ($file_type eq "spreadsheet") {
        print STDERR "Spreadsheet \n";
        $subdirectory = "spreadsheet_phenotype_upload";
        $validate_type = "phenotype spreadsheet";
        $metadata_file_type = "spreadsheet phenotype file";
        $timestamp_included = $c->req->param('upload_spreadsheet_phenotype_timestamp_checkbox');
        $data_level = $c->req->param('upload_spreadsheet_phenotype_data_level') || 'plots';
        $upload = $c->req->upload('upload_spreadsheet_phenotype_file_input');
    }
    elsif ($file_type eq "fieldbook") {
        print STDERR "Fieldbook \n";
        $subdirectory = "tablet_phenotype_upload";
        $validate_type = "field book";
        $metadata_file_type = "tablet phenotype file";
        $timestamp_included = 1;
        $upload = $c->req->upload('upload_fieldbook_phenotype_file_input');
        $image_zip = $c->req->upload('upload_fieldbook_phenotype_images_zipfile');
        $data_level = $c->req->param('upload_fieldbook_phenotype_data_level') || 'plots';
    }
    elsif ($file_type eq "datacollector") {
        print STDERR "Datacollector \n";
        $subdirectory = "data_collector_phenotype_upload";
        $validate_type = "datacollector spreadsheet";
        $metadata_file_type = "data collector phenotype file";
        $timestamp_included = $c->req->param('upload_datacollector_phenotype_timestamp_checkbox');
        $upload = $c->req->upload('upload_datacollector_phenotype_file_input');
    }

    my $user_type = $user->get_object->get_user_type();
    if ($user_type ne 'submitter' && $user_type ne 'curator') {
        push @error_status, 'Must have submitter privileges to upload phenotypes! Please contact us!';
        return (\@success_status, \@error_status);
    }

    my $overwrite_values = $c->req->param('phenotype_upload_overwrite_values');
    if ($overwrite_values) {
        #print STDERR $user_type."\n";
        if ($user_type ne 'curator') {
            push @error_status, 'Must be a curator to overwrite values! Please contact us!';
            return (\@success_status, \@error_status);
        }
    }

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        return (\@success_status, \@error_status);
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;
    #print STDERR "Archived Phenotype File: $archived_filename_with_path\n";

    my $archived_image_zipfile_with_path;
    if ($image_zip) {
        my $upload_original_name = $image_zip->filename();
        my $upload_tempfile = $image_zip->tempname;
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory."_images",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_type
        });
        $archived_image_zipfile_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_image_zipfile_with_path);
        if (!$archived_image_zipfile_with_path) {
            push @error_status, "Could not save images zipfile $upload_original_name in archive.";
            return (\@success_status, \@error_status);
        } else {
            push @success_status, "Images Zip File $upload_original_name saved in archive.";
        }
        unlink $upload_tempfile;
        #print STDERR "Archived Zipfile: $archived_image_zipfile_with_path\n";
    }

    ## Validate and parse uploaded file
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        return (\@success_status, \@error_status);
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        return (\@success_status, \@error_status);
    }

    ## Set metadata
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    my $operator = $user->get_object()->get_username();
    $phenotype_metadata{'operator'} = $operator;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        return (\@success_status, \@error_status);
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
    }
    my %parsed_data;
    my @plots;
    my @traits;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'plots'}};
            @traits = @{$parsed_file->{'traits'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    return (\@success_status, \@error_status, \%parsed_data, \@plots, \@traits, \%phenotype_metadata, $timestamp_included, $overwrite_values, $archived_image_zipfile_with_path, $user_id);
}

sub update_plot_phenotype :  Path('/ajax/phenotype/plot_phenotype_upload') : ActionClass('REST') { }
sub update_plot_phenotype_POST : Args(0) {
  my $self = shift;
  my $c = shift;
  my $plot_name = $c->req->param("plot_name");
  my $trait_id = $c->req->param("trait");
  my $trait_value = $c->req->param("trait_value");
  my $trait_list_option = $c->req->param("trait_list_option");
  my $time = DateTime->now();
  my $timestamp = $time->ymd()."_".$time->hms();
  my $dbh = $c->dbc->dbh();
  my $schema = $c->dbic_schema("Bio::Chado::Schema");
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my (@plots, @traits, %data, $trait);
  my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type' )->cvterm_id();
  print "MY LIST OPTION:  $trait_list_option\n";
  my $plot = $schema->resultset("Stock::Stock")->find( { uniquename=>$plot_name });
  my $plot_type_id = $plot->type_id();

  if ($plot_type_id == $accession_cvterm_id) {
    print "You are using accessions\n";
    $c->stash->{rest} = {error => "Used only for Plot Phenotyping."};
    return;
  }

  if (!$trait_list_option){
      my $h = $dbh->prepare("SELECT cvterm.cvterm_id AS trait_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id WHERE db.db_id = (( SELECT dbxref_1.db_id FROM stock JOIN nd_experiment_stock USING (stock_id) JOIN nd_experiment_phenotype USING (nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm cvterm_1 ON phenotype.cvalue_id = cvterm_1.cvterm_id JOIN dbxref dbxref_1 ON cvterm_1.dbxref_id = dbxref_1.dbxref_id LIMIT 1)) AND cvterm_id =? GROUP BY cvterm.cvterm_id, ((((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text);");
      $h->execute($trait_id);
      while (my ($id, $trait_name) = $h->fetchrow_array()) {
        $trait = $trait_name;
      }
  }
  else {
      $trait = $trait_id;
  }
  push @plots, $plot_name;
  push @traits, $trait;

  $data{$plot_name}->{$trait} = [$trait_value,$timestamp];

  my %phenotype_metadata;
  $phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  $phenotype_metadata{'date'}="$timestamp";
  my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;

  my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
      bcs_schema=>$schema,
      metadata_schema=>$metadata_schema,
      phenome_schema=>$phenome_schema,
      user_id=>$user_id,
      stock_list=>\@plots,
      trait_list=>\@traits,
      values_hash=>\%data,
      has_timestamps=> 1,
      overwrite_values=> 1,
      metadata_hash=>\%phenotype_metadata,
  );

  my ($verified_warning, $verified_error) = $store_phenotypes->verify();
  if ($verified_error){
    $c->stash->{rest} = {error => $verified_error};
    $c->detach;
  }

  my ($store_error, $store_success) = $store_phenotypes->store();
  if ($store_error) {
      $c->stash->{rest} = {error => $store_error};
      $c->detach;
  }

  $c->stash->{rest} = {success => 1}
}

sub retrieve_plot_phenotype :  Path('/ajax/phenotype/plot_phenotype_retrieve') : ActionClass('REST') { }
sub retrieve_plot_phenotype_POST : Args(0) {
  my $self = shift;
  my $c = shift;
  my $dbh = $c->dbc->dbh();
  my $schema = $c->dbic_schema("Bio::Chado::Schema");
  my $plot_name = $c->req->param("plot_name");
  my $trait_id = $c->req->param("trait");
  my $trait_list_option = $c->req->param("trait_list_option");
  my $trait_value;
  my $stock = $schema->resultset("Stock::Stock")->find( { uniquename=>$plot_name });
  my $stock_id = $stock->stock_id();

  if ($trait_list_option){
      my $h = $dbh->prepare("SELECT cvterm.cvterm_id AS trait_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name FROM cvterm JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id WHERE db.db_id = (( SELECT dbxref_1.db_id FROM stock JOIN nd_experiment_stock USING (stock_id) JOIN nd_experiment_phenotype USING (nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm cvterm_1 ON phenotype.cvalue_id = cvterm_1.cvterm_id JOIN dbxref dbxref_1 ON cvterm_1.dbxref_id = dbxref_1.dbxref_id LIMIT 1)) AND (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text =? GROUP BY cvterm.cvterm_id, ((((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text);");
      $h->execute($trait_id);
      while (my ($id, $trait_name) = $h->fetchrow_array()) {
        $trait_id = $id;
      }
  }

  my $h = $dbh->prepare("SELECT phenotype.value FROM stock
    JOIN nd_experiment_stock USING(stock_id)
    JOIN nd_experiment_phenotype USING(nd_experiment_id)
    JOIN phenotype USING(phenotype_id)
    WHERE cvalue_id =? and stock_id=?;"
    );
  $h->execute($trait_id,$stock_id);
  while (my ($plot_value) = $h->fetchrow_array()) {
    $trait_value = $plot_value;
  }

  $c->stash->{rest} = {trait_value => $trait_value};

}

#########
1;
#########
