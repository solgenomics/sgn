
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
use Date::Parse;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::BreedersToolbox::Projects;
use CXGN::Job;
use CXGN::File;
use File::Basename qw | basename dirname|;
use CXGN::Phenotype;
use CXGN::Trial;
use CXGN::Project;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );


sub upload_phenotype_verify :  Path('/ajax/phenotype/upload_verify') : ActionClass('REST') { }
sub upload_phenotype_verify_POST : Args(1) {
    my ($self, $c, $file_type, $is_treatment) = @_;

    $self->_upload_phenotypes($c, $file_type, $is_treatment, 'verify');
}

sub upload_phenotype_store :  Path('/ajax/phenotype/upload_store') : ActionClass('REST') { }
sub upload_phenotype_store_POST : Args(1) {
    my ($self, $c, $file_type, $is_treatment) = @_;

    $self->_upload_phenotypes($c, $file_type, $is_treatment, 'store');
}

=head2 _upload_phenotypes($c, $file_type, $is_treatment, $mode)

Archives an uploaded phenotype file and hands it to the background script that reads it. Shared by
the verify and store endpoints, which differ only in what the script is asked to do with the file:
"verify" reports on the file without saving anything, "store" saves the values in it.

The upload manager archives the file before calling here and follows the job itself, so it gets an
answer as soon as the job has been submitted. The upload dialogs post the file directly and show
the outcome when the request comes back, so those wait for the job to finish before they are
answered.

=cut

sub _upload_phenotypes {
    my $self = shift;
    my $c = shift;
    my $file_type = shift;
    my $is_treatment = shift;
    my $mode = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my ($success_status, $error_status, $upload) = _prep_upload($c, $file_type, $is_treatment);
    if (scalar(@$error_status) > 0) {
        $c->stash->{rest} = { success => $success_status, error => $error_status };
        return;
    }

    my $user_first_name = $c->user()->get_object()->get_first_name();
    my $user_last_name = $c->user()->get_object()->get_last_name();
    my $filename = basename($upload->{archived_file_path});

    # The upload manager reads these back off a validation job to build the request that stores the
    # file once someone has looked at the validation, so a validation job has to carry everything
    # the store it leads to will need.
    my $additional_args = {
        file_type => $upload->{job_file_type},
        ignore_warnings => $upload->{ignore_warnings},
        overwrite_values => $upload->{overwrite_values},
        remove_values => $upload->{remove_values},
        user_name => "$user_first_name $user_last_name",
        file_id => $upload->{archived_file_id}
    };

    if ($mode eq 'verify') {
        $additional_args->{is_validation} = 1;
    } else {
        $additional_args->{final_upload} = 1;
    }

    if ($upload->{is_treatment}) {
        $additional_args->{upload_spreadsheet_treatment_timestamp_checkbox} = $c->req->param('upload_spreadsheet_treatment_timestamp_checkbox');
        $additional_args->{upload_spreadsheet_treatment_data_level} = $upload->{data_level};
        $additional_args->{upload_spreadsheet_treatment_file_format} = $c->req->param('upload_spreadsheet_treatment_file_format');
    } elsif ($upload->{job_file_type} eq "phenotyping_spreadsheet" || $upload->{job_file_type} eq "images_phenotypes") {
        $additional_args->{upload_spreadsheet_phenotype_timestamp_checkbox} = $c->req->param('upload_spreadsheet_phenotype_timestamp_checkbox');
        $additional_args->{upload_spreadsheet_phenotype_data_level} = $upload->{data_level};
        $additional_args->{upload_spreadsheet_phenotype_file_format} = $c->req->param('upload_spreadsheet_phenotype_file_format');
    } elsif ($upload->{job_file_type} eq "datacollector_spreadsheet") {
        $additional_args->{upload_datacollector_phenotype_timestamp_checkbox} = $c->req->param('upload_datacollector_phenotype_timestamp_checkbox');
    } elsif ($upload->{job_file_type} eq "fieldbook_phenotypes") {
        $additional_args->{upload_fieldbook_phenotype_data_level} = $upload->{data_level};
    }

    if ($upload->{archived_image_zipfile_id}) {
        $additional_args->{image_zipfile_id} = $upload->{archived_image_zipfile_id};
    }

    # Archiving is the only part of the upload that happens here, so what it had to say is recorded
    # on the job before the script starts adding its own messages.
    if (scalar(@$success_status) > 0) {
        $additional_args->{success_messages} = join("<br>", @$success_status);
    }

    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $basepath = $c->config->{basepath};
    my $archive_path = $c->config->{archive_path};
    my $tempfiles_subdir = $c->config->{tempfiles_subdir};

    # __SP_JOB_ID__ is filled in by CXGN::Job when the job is submitted, so that the script can
    # report its messages back to this job.
    my $cmd = "perl \"$basepath/bin/upload_phenotypes.pl\" -H \"$dbhost\" -D \"$dbname\" -U \"$dbuser\" -P \"$dbpass\" -w \"$basepath\" -ap \"$archive_path\" -tf \"$tempfiles_subdir\" -m \"$mode\" -i \"".$upload->{archived_file_id}."\" -un \"".$upload->{username}."\" -t \"".$upload->{validate_type}."\" -mt \"".$upload->{metadata_file_type}."\" -dl \"".$upload->{data_level}."\" -ti \"".$upload->{timestamp_included}."\" -ow \"".$upload->{overwrite_values}."\" -rv \"".$upload->{remove_values}."\" -iw \"".$upload->{ignore_warnings}."\" -tt \"".$upload->{is_treatment}."\" -j __SP_JOB_ID__";
    if ($upload->{archived_image_zipfile_id}) {
        $cmd .= " -iz \"".$upload->{archived_image_zipfile_id}."\"";
    }

    my $upload_job = CXGN::Job->new({
        schema => $schema,
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_person_id => $upload->{user_id},
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        basepath => $basepath,
        cmd => $cmd,
        name => $mode eq 'verify' ? "$filename file validation" : "$filename phenotype upload",
        job_type => 'upload',
        submit_page => ($c->req->referer ? $c->req->referer->as_string : undef),
        additional_args => $additional_args
    });

    my $submit_error;
    try {
        $upload_job->submit();
    } catch {
        $submit_error = $_;
    };
    if ($submit_error) {
        push @$error_status, "Could not submit the phenotype upload: $submit_error";
        $c->stash->{rest} = { success => $success_status, error => $error_status };
        return;
    }

    if ($upload->{from_upload_manager}) {
        $c->stash->{rest} = { success => $success_status, error => $error_status, job_id => $upload_job->sp_job_id() };
        return;
    }

    $upload_job->wait();

    # The script reports its results by writing them to the job, so they have to be read back from
    # the database rather than from the object that submitted it.
    my $finished_job = CXGN::Job->new({
        sp_job_id => $upload_job->sp_job_id(),
        schema => $schema,
        people_schema => $c->dbic_schema("CXGN::People::Schema")
    });
    my $job_args = $finished_job->additional_args() || {};

    my @success_messages = _split_job_messages($job_args->{success_messages});
    my @warning_messages = _split_job_messages($job_args->{warning_messages});
    my @error_messages = _split_job_messages($job_args->{error_messages});

    if (!scalar(@success_messages) && !scalar(@warning_messages) && !scalar(@error_messages)) {
        # The job left the queue without recording an outcome, which happens if the script died
        # before it could report anything.
        push @error_messages, "The upload did not report a result. Check the status of upload job ".$upload_job->sp_job_id().".";
    }

    $c->stash->{rest} = { success => \@success_messages, warning => \@warning_messages, error => \@error_messages };
}

=head2 _split_job_messages($messages)

Splits the messages a job recorded back into the list the upload dialogs display them as. A job
holds each kind of message as a single string, since that is how the upload manager shows them.

=cut

sub _split_job_messages {
    my $messages = shift;

    return () if !defined($messages) || $messages eq '';

    return grep { $_ ne '' } split(/<br>/, $messages);
}

=head2 _prep_upload($c, $file_type, $is_treatment)

Checks that the user is allowed to upload this file, works out what kind of file it is, and archives
it along with any image zipfile that came with it. Reading the file is left to the background
script, so what comes back describes the upload rather than anything out of the file itself.

=cut

sub _prep_upload {
    my ($c, $file_type, $is_treatment) = @_;
	my @success_status;
	my @error_status;

	my $user = $c->user();

	if (!$user) {# only checks for login, ask whether this needs to be changed...
		push @error_status, 'You do not have permission to upload data to this trial!';
		return (\@success_status, \@error_status);
	}

    my $treatment = ($is_treatment && $is_treatment eq "treatment") ? 1 : 0;

    my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;
    my $timestamp_included;
    my $upload;
    my $subdirectory;
    my $validate_type;
    my $metadata_file_type;
    my $job_file_type;
    my $data_level;
    my $image_zip;
    my $image_zipfile_id = $c->req->param('archived_image_zipfile_id') || undef;
    my $archived_file_id = $c->req->param('archived_file_id') || undef;
    my $upload_file_type;

    # The upload manager archives a file before calling here, so a file that is already in the
    # archive is one it is going to follow the job for itself.
    my $from_upload_manager = $archived_file_id ? 1 : 0;

    if ($file_type eq "spreadsheet") {
        my $spreadsheet_format;
        if ($treatment) {
            $spreadsheet_format = $c->req->param("upload_spreadsheet_treatment_file_format");
            $timestamp_included = $c->req->param('upload_spreadsheet_treatment_timestamp_checkbox');
            $data_level = $c->req->param('upload_spreadsheet_treatment_data_level') || 'plots';
            $upload = $c->req->upload('upload_spreadsheet_treatment_file_input');
            $image_zip = $c->req->upload('upload_spreadsheet_treatment_associated_images_file_input');
            $upload_file_type = "treatments";
            $job_file_type = "treatments";
        } else {
            $spreadsheet_format = $c->req->param("upload_spreadsheet_phenotype_file_format"); #simple or detailed or nirs or scio or associated_images
            $timestamp_included = $c->req->param('upload_spreadsheet_phenotype_timestamp_checkbox');
            $data_level = $c->req->param('upload_spreadsheet_phenotype_data_level') || 'plots';
            $upload = $c->req->upload('upload_spreadsheet_phenotype_file_input');
            $image_zip = $c->req->upload('upload_spreadsheet_phenotype_associated_images_file_input');
            $upload_file_type = "phenotyping_spreadsheet";
            # An associated images spreadsheet is uploaded together with an image zipfile, so it
            # gets its own type to keep it distinguishable from a plain phenotyping spreadsheet.
            $job_file_type = ($spreadsheet_format && $spreadsheet_format eq 'associated_images') ? "images_phenotypes" : "phenotyping_spreadsheet";
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
        $job_file_type = "fieldbook_phenotypes";
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
        $job_file_type = "datacollector_spreadsheet";
        $timestamp_included = $c->req->param('upload_datacollector_phenotype_timestamp_checkbox');
        $upload = $c->req->upload('upload_datacollector_phenotype_file_input');
    }

    my $user_type = $user->get_object->get_user_type();
    if ($user_type ne 'submitter' && $user_type ne 'curator') {
        push @error_status, 'Must have submitter privileges to upload phenotypes! Please contact us!';
        return (\@success_status, \@error_status);
    }

    my $overwrite_values = $c->req->param('phenotype_upload_overwrite_values');
    my $remove_values = $overwrite_values && $c->req->param('phenotype_upload_remove_values');
    my $ignore_warnings = $c->req->param('ignore_warnings');
    if ($ignore_warnings) {
        $overwrite_values = 1;
        $remove_values = 1;
    }
    if ($overwrite_values) {
        #print STDERR $user_type."\n";
        if ($user_type ne 'curator') {
            push @error_status, 'Must be a curator to overwrite values! Please contact us!';
            return (\@success_status, \@error_status);
        }
    }
    if ( $remove_values ) {
        if ($user_type ne 'curator') {
            push @error_status, 'Must be a curator to remove values! Please contact us!';
            return (\@success_status, \@error_status);
        }
    }

    my $archived_filename_with_path;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $upload_original_name;

    if (! $archived_file_id) {
        $upload_original_name = $upload->filename();
        my $upload_tempfile = $upload->tempname;
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_type,
            metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
            file_type => $upload_file_type
        });
        ($archived_file_id, $archived_filename_with_path) = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            push @error_status, "Could not save file $upload_original_name in archive.";
            return (\@success_status, \@error_status);
        } else {
            push @success_status, "File $upload_original_name saved in archive.";
        }
        unlink $upload_tempfile;
    } else {
        my $archived_file = CXGN::File->new({
            file_id => $archived_file_id,
            metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema"),
            archive_path => $c->config->{archive_path}
        });
        $archived_filename_with_path = $archived_file->get_path();
    }

    print STDERR "Archived Phenotype File: $archived_filename_with_path\n";

    # The script is told which archived file the images are in rather than where they are on disk,
    # so a zipfile that is archived here has to hand its id back the same way one that was picked
    # out of the archive already did.
    if ($image_zip && !$image_zipfile_id) {
        $upload_original_name = $image_zip->filename();
        my $upload_tempfile = $image_zip->tempname;
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory."_images",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_type,
            metadata_schema => $c->dbic_schema("CXGN::Metadata::Schema")
        });
        my $archived_image_zipfile_with_path;
        ($image_zipfile_id, $archived_image_zipfile_with_path) = $uploader->archive();
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

    return (\@success_status, \@error_status, {
        user_id => $user_id,
        username => $user->get_object()->get_username(),
        archived_file_id => $archived_file_id,
        archived_file_path => $archived_filename_with_path,
        archived_image_zipfile_id => $image_zipfile_id,
        validate_type => $validate_type,
        metadata_file_type => $metadata_file_type,
        job_file_type => $job_file_type,
        data_level => $data_level || 'plots',
        timestamp_included => $timestamp_included ? 1 : 0,
        overwrite_values => $overwrite_values ? 1 : 0,
        remove_values => $remove_values ? 1 : 0,
        ignore_warnings => $ignore_warnings ? 1 : 0,
        is_treatment => $treatment,
        from_upload_manager => $from_upload_manager
    });
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

sub update_single_observation :Path('/ajax/phenotype/edit/') Args(1) {
    my $self = shift;
    my $c = shift;
    my $observationID = shift;

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to record a phenotype." };
        return;
    }

    my $user = $c->user();
    my $sp_person_id = $user->get_object()->get_sp_person_id();

    my $user_type = $user->get_object->get_user_type();
    my $username = $user->get_username();

    my $new_value = $c->req->param('new_observation_value');
    my $new_timestamp = $c->req->param('new_observation_timestamp');
    my $trial_id = $c->req->param('trial_id');

    if (!$trial_id) {
        $c->stash->{rest} = {error => "This observation can only be edited in relation to a trial."};
        return;
    }

    if (!$observationID) {
        $c->stash->{rest} = {error => "You must supply an observation ID!"};
        return;
    }

    if (!defined($new_value) || $new_value eq '') {
        $c->stash->{rest} = {error => "This function can edit existing phenotype entries, but not delete them. Please enter a value."};
        return;
    }

    #check for user permissions on this trial
    my $this_trial = CXGN::Trial->new({
        bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
        trial_id => $trial_id
    });

    my $owners = $this_trial->_get_trial_owners();

    if ( ! $user->check_roles("curator") && !defined($owners->{$sp_person_id}) ) {
        $c->stash->{rest} = {error => "You do not have permission to make edits on this trial - only curators and trial owners can modify raw phenotype values."};
        return;
    }

    if ($new_timestamp) {
        my $epoch = str2time($new_timestamp);
        my $dt = DateTime->from_epoch(epoch => $epoch);
        $new_timestamp = $dt->strftime('%Y-%m-%d %H:%M:%S%z');
    }

    my $phenotype = CXGN::Phenotype->new({
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        overwrite => 1,
        phenotype_id => $observationID,
    });

    my $pheno_uniquename = $phenotype->uniquename();
    $pheno_uniquename =~ s/observation: [\w]*/observation: $new_value/;
    if ($new_timestamp) {
        $pheno_uniquename =~ s/date: [^,]*,/date: $new_timestamp,/;
    }
    if (!$phenotype->operator()) {
        $pheno_uniquename =~ s/operator: [\w]*,/operator: $username,/;
    }

    try {
        $phenotype->value($new_value);
        if ($new_timestamp) {
            $phenotype->collect_date($new_timestamp);
        }
        if (!$phenotype->operator()) {
            $phenotype->operator($username);
        }
        $phenotype->uniquename($pheno_uniquename);
        $phenotype->store();
    } catch {
        $c->stash->{rest} = {error => "An error occurred trying to store phenotype: $_"};
        return;
    };

    $c->stash->{rest} = {success => 1};
    return;

}

######### 
1;
#########
