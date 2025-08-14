
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
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::BreedersToolbox::Projects;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );


sub upload_phenotype_verify :  Path('/ajax/phenotype/upload_verify') : ActionClass('REST') { }
sub upload_phenotype_verify_POST : Args(1) {
    my ($self, $c, $file_type, $is_treatment) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $overwrite_values, $remove_values, $image_zip, $user_id, $validate_type) = _prep_upload($c, $file_type, $is_treatment, $schema);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }

    my $timestamp = 0;
    if ($timestamp_included) {
        $timestamp = 1;
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
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
        composable_validation_check_name=>$c->config->{composable_validation_check_name}
    );

    my ($warning_status, $verified_warning, $verified_error);
    try {
        ($verified_warning, $verified_error) = $store_phenotypes->verify();
    }
    catch {
        $verified_error = $_;
    };

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
    my ($self, $c, $file_type, $is_treatment) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    my ($success_status, $error_status, $parsed_data, $plots, $traits, $phenotype_metadata, $timestamp_included, $overwrite_values, $remove_values, $image_zip, $user_id, $validate_type) = _prep_upload($c, $file_type, $is_treatment, $schema);
    if (scalar(@$error_status)>0) {
        $c->stash->{rest} = {success => $success_status, error => $error_status };
        return;
    }
    my $overwrite = 0;
    if ($overwrite_values) {
        $overwrite = 1;
    }
    my $remove = 0;
    if ($remove_values) {
        $remove = 1;
    }
    my $timestamp = 0;
    if ($timestamp_included) {
        $timestamp = 1;
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>$plots,
        trait_list=>$traits,
        values_hash=>$parsed_data,
        has_timestamps=>$timestamp,
        overwrite_values=>$overwrite,
        remove_values=>$remove,
        metadata_hash=>$phenotype_metadata,
        image_zipfile_path=>$image_zip,
        composable_validation_check_name=>$c->config->{composable_validation_check_name},
        allow_repeat_measures=>$c->config->{allow_repeat_measures}
    );

    #upload_phenotype_store function redoes the same verification that upload_phenotype_verify does before actually uploading. maybe this should be commented out.
    #my ($verified_warning, $verified_error) = $store_phenotypes->verify($c,$plots,$traits, $parsed_data, $phenotype_metadata);
    #if ($verified_error) {
	#push @$error_status, $verified_error;
	#$c->stash->{rest} = {success => $success_status, error => $error_status };
	#return;
    #}
    #push @$success_status, "File data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success);
    try {
        ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    }
    catch {
        $stored_phenotype_error = $_;
    };

    if ($stored_phenotype_error) {
        push @$error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => $success_status, error => $error_status};
        return;
    }
    if ($stored_phenotype_success) {
        push @$success_status, $stored_phenotype_success;
    }

    if ($validate_type eq 'field book' && $image_zip) {
        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $image_error = $image->upload_fieldbook_zipfile($image_zip, $user_id);
        if ($image_error) {
            push @$error_status, $image_error;
        }
    }

    push @$success_status, "Metadata saved for archived file.";
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'phenotypes', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => $success_status, error => $error_status};
}

sub _prep_upload {
    my ($c, $file_type, $is_treatment, $schema) = @_;
	my @success_status;
	my @error_status;

	my $user = $c->user();

	if (!$user) {# only checks for login, ask whether this needs to be changed...
		push @error_status, 'You do not have permission to upload data to this trial!';
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
        my $spreadsheet_format;
        if ($is_treatment eq "treatment") {
            $spreadsheet_format = $c->req->param("upload_spreadsheet_treatment_file_format");
            $timestamp_included = $c->req->param('upload_spreadsheet_treatment_timestamp_checkbox');
            $data_level = $c->req->param('upload_spreadsheet_treatment_data_level') || 'plots';
            $upload = $c->req->upload('upload_spreadsheet_treatment_file_input');
            $image_zip = $c->req->upload('upload_spreadsheet_treatment_associated_images_file_input');
        } else {
            $spreadsheet_format = $c->req->param("upload_spreadsheet_phenotype_file_format"); #simple or detailed or nirs or scio or associated_images
            $timestamp_included = $c->req->param('upload_spreadsheet_phenotype_timestamp_checkbox');
            $data_level = $c->req->param('upload_spreadsheet_phenotype_data_level') || 'plots';
            $upload = $c->req->upload('upload_spreadsheet_phenotype_file_input');
            $image_zip = $c->req->upload('upload_spreadsheet_phenotype_associated_images_file_input');
        }
        # print STDERR "File type is Spreadsheet and format is $spreadsheet_format\n";
        $metadata_file_type = "spreadsheet phenotype file";

        if ($spreadsheet_format eq 'detailed'){
            $validate_type = "phenotype spreadsheet";
        } elsif ($spreadsheet_format eq 'simple'){
            $validate_type = "phenotype spreadsheet simple generic";
        } elsif ($spreadsheet_format eq 'associated_images'){
            $validate_type = "phenotype spreadsheet associated_images";
        } else {
            die "Spreadsheet format not supported! Only simple, detailed, nirs, scio, or associated_images\n";
        }
        $subdirectory = "spreadsheet_phenotype_upload";
    }
    elsif ($file_type eq "fieldbook") {
        # print STDERR "Fieldbook \n";
        $subdirectory = "tablet_phenotype_upload";
        $validate_type = "field book";
        $metadata_file_type = "tablet phenotype file";
        $timestamp_included = 1;
        $upload = $c->req->upload('upload_fieldbook_phenotype_file_input');
        $image_zip = $c->req->upload('upload_fieldbook_phenotype_images_zipfile');
        $data_level = $c->req->param('upload_fieldbook_phenotype_data_level') || 'plots';
    }
    elsif ($file_type eq "datacollector") {
        # print STDERR "Datacollector \n";
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
    my $remove_values = $overwrite_values && $c->req->param('phenotype_upload_remove_values');
    if ( $remove_values ) {
        if ($user_type ne 'curator') {
            push @error_status, 'Must be a curator to remove values! Please contact us!';
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
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, undef);
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

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, undef);
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

    if (scalar(@error_status) == 0) { #TODO: check for treatment and propagate values to child stocks
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @traits = @{$parsed_file->{'variables'}};
            push @success_status, "File data successfully parsed.";
        }
        if ($is_treatment eq "treatment") {
            foreach my $plot (@plots) {
                my $plot_obj = CXGN::Stock->new({
                    schema => $schema,
                    uniquename => $plot
                });
                my $child_stocks = $plot_obj->get_child_stocks_flat_list();
                foreach my $child (@{$child_stocks}) {
                    next if ($child->{type} eq "accession");
                    push @plots, $child->{name};
                    foreach my $trait (@traits) {
                        $parsed_data{$child->{name}}->{$trait} = $parsed_data{$plot}->{$trait};
                    }
                }
            }
        }
    }

    return (\@success_status, \@error_status, \%parsed_data, \@plots, \@traits, \%phenotype_metadata, $timestamp_included, $overwrite_values, $remove_values, $archived_image_zipfile_with_path, $user_id, $validate_type);
}

sub update_plot_phenotype :  Path('/ajax/phenotype/plot_phenotype_upload') : ActionClass('REST') { }
sub update_plot_phenotype_POST : Args(0) {
  my $self = shift;
  my $c = shift;
  print STDERR Dumper $c->req->params();
  my $plot_name = $c->req->param("plot_name");
  my $trait_id = $c->req->param("trait");
  my $trait_value = $c->req->param("trait_value");
  my $trait_list_option = $c->req->param("trait_list_option");
  my $trial_id = $c->req->param("trial_id");
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

  if (!$c->user()) {
    print STDERR "User not logged in... not recording phenotype.\n";
    $c->stash->{rest} = {error => "You need to be logged in to record phenotype." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to record phenotype." };
    return;
  }

  my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
  my $program_ref = $program_object->get_breeding_programs_by_trial($trial_id);

  my $program_array = @$program_ref[0];
  my $breeding_program_name = @$program_array[1];
  my @user_roles = $c->user->roles();
  my %has_roles = ();
  map { $has_roles{$_} = 1; } @user_roles;

  if (! ( (exists($has_roles{$breeding_program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
    $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $breeding_program_name to record phenotype." };
    return;
  }

  if ($plot_type_id == $accession_cvterm_id) {
    print "You are using accessions\n";
    $c->stash->{rest} = {error => "Used only for Plot Phenotyping."};
    return;
  }

  if (!$trait_list_option){
      $trait = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');
  }
  else {
      $trait = $trait_list_option;
  }
  push @plots, $plot_name;
  push @traits, $trait;

  $data{$plot_name}->{$trait} = [$trait_value,$timestamp];

  my %phenotype_metadata;
  $phenotype_metadata{'archived_file'} = 'none';
  $phenotype_metadata{'archived_file_type'}="direct phenotyping";
  $phenotype_metadata{'operator'}=$c->user()->get_object()->get_sp_person_id();
  $phenotype_metadata{'date'}="$timestamp";
  my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;

  my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
  my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

  my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
      basepath=>$c->config->{basepath},
      dbhost=>$c->config->{dbhost},
      dbname=>$c->config->{dbname},
      dbuser=>$c->config->{dbuser},
      dbpass=>$c->config->{dbpass},
      temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
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
      composable_validation_check_name=>$c->config->{composable_validation_check_name},
      allow_repeat_measures=>$c->config->{allow_repeat_measures}
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

  $c->stash->{rest} = {success => 1};
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

    if ($trait_id) {
        my $q = "SELECT phenotype.value FROM stock
            JOIN nd_experiment_stock USING(stock_id)
            JOIN nd_experiment_phenotype USING(nd_experiment_id)
            JOIN phenotype USING(phenotype_id)
            WHERE cvalue_id =? and stock_id=?";

        my $h = $dbh->prepare ($q);
        $h->execute($trait_id,$stock_id);

        while (my ($plot_value) = $h->fetchrow_array()) {
            $trait_value = $plot_value;
        }
    }

    $c->stash->{rest} = {trait_value => $trait_value};

}

sub view_all_uploads :Path('/ajax/phenotype/view_uploads') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file_list = CXGN::Project->get_all_phenotype_metadata($c->dbic_schema("Bio::Chado::Schema"), 100);
    $c->stash->{rest} = $file_list;
}

#########
1;
#########
