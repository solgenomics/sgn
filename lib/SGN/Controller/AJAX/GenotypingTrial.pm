
package SGN::Controller::AJAX::GenotypingTrial;

use Moose;
use JSON;
use Data::Dumper;
use CXGN::Trial::TrialDesign;
use Try::Tiny;
use List::MoreUtils qw /any /;
use CXGN::People::Person;
use CXGN::Login;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::CreatePlateOrder;
use CXGN::Genotype::StoreGenotypingProject;
use CXGN::Stock::TissueSample::Search;
use CXGN::Genotype::Delete;
use CXGN::Job;
use CXGN::File;
use File::Basename qw | basename |;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub generate_genotype_trial : Path('/ajax/breeders/generategenotypetrial') ActionClass('REST') {}
sub generate_genotype_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping plate.' };
        $c->detach();
    }

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $plate_info = decode_json $c->req->param("plate_data");
    #print STDERR Dumper $plate_info;

    if ( !$plate_info->{elements} || !$plate_info->{genotyping_facility_submit} || !$plate_info->{genotyping_project_id} || !$plate_info->{name} || !$plate_info->{sample_type} || !$plate_info->{plate_format} ) {
        $c->stash->{rest} = { error => "Please provide all parameters in the plate information section" };
        $c->detach();
    }

    my $genotyping_project_id = $plate_info->{genotyping_project_id};
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $genotyping_project_id });
    my $genotyping_facility = $trial->get_genotyping_facility();

    if ( $genotyping_facility eq 'igd' && $plate_info->{genotyping_facility_submit} eq 'yes' && $plate_info->{blank_well} eq ''){
        $c->stash->{rest} = { error => "To submit to Cornell IGD you need to provide the blank well!" };
        $c->detach();
    }

    my $td = CXGN::Trial::TrialDesign->new( { schema => $schema });

    $td->set_stock_list($plate_info->{elements});
    $td->set_block_size($plate_info->{plate_format});
    $td->set_blank($plate_info->{blank_well});
    $td->set_trial_name($plate_info->{name});
    $td->set_design_type("genotyping_plate");

    eval {
        $td->calculate_design();
    };

    if ($@) {
        $c->stash->{rest} = { error => "Design failed. Error: $@" };
        print STDERR "Design failed because of $@\n";
        $c->detach();
    }

    my $design = $td->get_design();

    if (exists($design->{error})) {
        $c->stash->{rest} = $design;
        $c->detach();
    }

    #Add common answers from form to all wells
    foreach (values %$design){
        $_->{concentration} = $plate_info->{well_concentration};
        $_->{volume} = $plate_info->{well_volume};
        $_->{tissue_type} = $plate_info->{well_tissue};
        $_->{dna_person} = $plate_info->{well_dna_person};
        $_->{extraction} = $plate_info->{well_extraction};
        $_->{acquisition_date} = $plate_info->{well_date};
        $_->{notes} = $plate_info->{well_notes};
        $_->{ncbi_taxonomy_id} = $plate_info->{ncbi_taxonomy_id};
    }
    #print STDERR Dumper($design);

    $c->stash->{rest} = {success => 1, design=>$design};
}


=head2 parse_genotype_trial_file_POST()

Archives an uploaded genotyping plate layout file and hands it to the background script that reads
it. The design the script builds is recorded on the job, so that storing the plate afterwards does
not have to read the file again.

The upload manager archives the file before calling here and follows the job itself, so it gets an
answer as soon as the job has been submitted. The upload dialog posts the file directly and lays
out the plate it gets back, so it waits for the job to finish before it is answered.

=cut

sub parse_genotype_trial_file : Path('/ajax/breeders/parsegenotypetrial') : ActionClass('REST') { }
sub parse_genotype_trial_file_POST : Args(0) {
    my ($self, $c) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $genotyping_plate_name = $c->req->param('genotyping_trial_name');
    my $upload_xls = $c->req->upload('genotyping_trial_layout_upload');
    my $upload_coordinate = $c->req->upload('genotyping_trial_layout_upload_coordinate');
    my $upload_coordinate_custom = $c->req->upload('genotyping_trial_layout_upload_coordinate_template');
    my $archived_file_id = $c->req->param('archived_file_id') || undef;
    my $file_type = $c->req->param('genotyping_plate_upload_type') || undef;
    my $facility_identifiers= $c->req->param('upload_include_facility_identifiers');
    my $include_facility_identifiers;
    if ($facility_identifiers){
        $include_facility_identifiers = 1;
    }
    #These describe the plate being created, but are not needed to parse the layout file. They are only recorded on the job for tracking purposes.
    my $genotyping_project_id = $c->req->param('genotyping_project_id');
    my $genotyping_plate_format = $c->req->param('genotyping_plate_format');
    my $genotyping_plate_sample_type = $c->req->param('genotyping_plate_sample_type');
    my $genotyping_plate_description = $c->req->param('genotyping_plate_description');

    #The upload manager archives a file before calling here, so a file that is already in the archive is one it is going to follow the job for itself.
    my $from_upload_manager = $archived_file_id ? 1 : 0;

    #Maps the granular upload type (used for job/file tracking) to the CXGN::Trial::ParseUpload plugin that handles it.
    my %genotyping_plate_upload_plugins = (
        genotyping_plate_excel => 'GenotypeTrialXLS',
        genotyping_plate_default_android => 'GenotypeTrialCoordinate',
        genotyping_plate_custom_android => 'GenotypeTrialCoordinateTemplate',
    );

    my $uploaded_file_count = grep { $_ } ($upload_xls, $upload_coordinate, $upload_coordinate_custom, $archived_file_id);
    if ($uploaded_file_count > 1){
        $c->stash->{rest} = {error => "Do not upload more than one genotyping plate file at the same time!" };
        return;
    }
    if ($uploaded_file_count < 1){
        $c->stash->{rest} = {error => "You must upload a genotyping plate file!" };
        return;
    }
    if (!$genotyping_plate_name){
        $c->stash->{rest} = {error => 'Genotyping plate id must be given!'};
        return;
    }

    my $upload;
    if ($upload_xls){
        $upload = $upload_xls;
        $file_type = 'genotyping_plate_excel';
    }
    if ($upload_coordinate){
        $upload = $upload_coordinate;
        $file_type = 'genotyping_plate_default_android';
    }
    if ($upload_coordinate_custom){
        $upload = $upload_coordinate_custom;
        $file_type = 'genotyping_plate_custom_android';
    }
    if ($archived_file_id && (!$file_type || !$genotyping_plate_upload_plugins{$file_type})){
        $c->stash->{rest} = {error => "A valid genotyping plate upload type must be given for an already-archived file." };
        return;
    }
    my $upload_type = $genotyping_plate_upload_plugins{$file_type};

    my $subdirectory = "genotyping_trial_upload";
    my $archived_filename_with_path;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    if (!$archived_file_id) {
        my $upload_original_name = $upload->filename();
        if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
            print STDERR "File name must not have spaces or slashes.\n";
            $c->stash->{rest} = {error => "Uploaded file name must not contain spaces or slashes." };
            return;
        }
    }

    my $user_id;
    my $user_name;
    my $user_role;
    my $user_first_name;
    my $user_last_name;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload genotyping plate!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
        $user_first_name = $p->get_first_name();
        $user_last_name = $p->get_last_name();
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload a genotyping plate!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
        $user_first_name = $c->user()->get_object()->get_first_name();
        $user_last_name = $c->user()->get_object()->get_last_name();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a genotyping plate." };
        $c->detach();
    }

    if (!$archived_file_id) {
        my $upload_original_name = $upload->filename();
        my $upload_tempfile = $upload->tempname;

        ## Store uploaded temporary file in archive
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role,
            file_type => 'genotyping_plate',
            metadata_schema => $metadata_schema
        });
        ($archived_file_id, $archived_filename_with_path) = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
            return;
        }
        unlink $upload_tempfile;
    } else {
        my $archived_file = CXGN::File->new({
            file_id => $archived_file_id,
            metadata_schema => $metadata_schema,
            archive_path => $c->config->{archive_path}
        });
        $archived_filename_with_path = $archived_file->get_path();
    }

    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $basepath = $c->config->{basepath};
    my $archive_path = $c->config->{archive_path};

    # __SP_JOB_ID__ is filled in by CXGN::Job when the job is submitted, so that the script can
    # report its messages back to this job, and can read the name of the plate off it. The plate
    # name is whatever the uploader typed, so it is passed on the job rather than on the command
    # line.
    my $cmd = "perl \"$basepath/bin/parse_genotype_trial_file.pl\" -H \"$dbhost\" -D \"$dbname\" -U \"$dbuser\" -P \"$dbpass\" -w \"$basepath\" -ap \"$archive_path\" -i \"$archived_file_id\" -t \"$upload_type\" -fi \"".($include_facility_identifiers ? 1 : 0)."\" -j __SP_JOB_ID__";

    my $upload_job = CXGN::Job->new({
        schema => $chado_schema,
        people_schema => $people_schema,
        sp_person_id => $user_id,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        basepath => $basepath,
        cmd => $cmd,
        name => basename($archived_filename_with_path)." $genotyping_plate_name genotyping plate upload",
        job_type => 'upload',
        results_page => '/breeders/genotyping_projects',
        submit_page => ($c->req->referer ? $c->req->referer->as_string : undef),
        additional_args => {
            is_validation => 1,
            file_type => $file_type,
            user_name => "$user_first_name $user_last_name",
            file_id => $archived_file_id,
            genotyping_plate_name => $genotyping_plate_name,
            genotyping_project_id => $genotyping_project_id,
            genotyping_plate_format => $genotyping_plate_format,
            genotyping_plate_sample_type => $genotyping_plate_sample_type,
            genotyping_plate_description => $genotyping_plate_description
        }
    });

    my $submit_error;
    try {
        $upload_job->submit();
    } catch {
        $submit_error = $_;
    };
    if ($submit_error) {
        $c->stash->{rest} = {error => "Could not submit the genotyping plate upload: $submit_error"};
        return;
    }

    if ($from_upload_manager) {
        $c->stash->{rest} = {success => 1, job_id => $upload_job->sp_job_id()};
        return;
    }

    $upload_job->wait();

    # The script reports its results by writing them to the job, so they have to be read back from
    # the database rather than from the object that submitted it.
    my $finished_job = CXGN::Job->new({
        sp_job_id => $upload_job->sp_job_id(),
        schema => $chado_schema,
        people_schema => $people_schema
    });
    my $job_args = $finished_job->additional_args() || {};

    if ($job_args->{error_messages}) {
        $c->stash->{rest} = {error_string => $job_args->{error_messages}, missing_accessions => $job_args->{missing_accessions}};
        return;
    }
    if (!$job_args->{design}) {
        # The job left the queue without recording an outcome, which happens if the script died
        # before it could report anything.
        $c->stash->{rest} = {error_string => "The genotyping plate upload did not report a result. Check the status of upload job ".$upload_job->sp_job_id()."."};
        return;
    }

    $c->stash->{rest} = {success => "1", design=>$job_args->{design}};
}

=head2 store_genotype_trial_POST()

Hands a genotyping plate to the background script that saves it. The plate is described either by a
layout file that was parsed beforehand or by a layout that was generated on the site, and it is
recorded on the job rather than passed on the command line, since a full plate is too big for one.

The upload manager follows the job itself, so it gets an answer as soon as the job has been
submitted. The upload dialog reports the outcome to the user and passes the saved plate on to the
genotyping facility when that was asked for, so it waits for the job to finish before it is
answered.

=cut

sub store_genotype_trial : Path('/ajax/breeders/storegenotypetrial') ActionClass('REST') {}
sub store_genotype_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_id;
    my $user_name;
    my $user_role;
    my $user_first_name;
    my $user_last_name;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload genotyping plate!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
        $user_first_name = $p->get_first_name();
        $user_last_name = $p->get_last_name();
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload a genotyping plate!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
        $user_first_name = $c->user()->get_object()->get_first_name();
        $user_last_name = $c->user()->get_object()->get_last_name();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a genotyping plate." };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $user_id);
    my $plate_info = decode_json $c->req->param("plate_data");
#    print STDERR "PLATE INFO =".Dumper($plate_info)."\n";
    my $archived_file_id = $c->req->param('archived_file_id') || undef;
    my $file_type = $c->req->param('genotyping_plate_upload_type') || undef;

    #The upload manager stores a plate whose layout file it has already archived, and it follows the job for itself.
    my $from_upload_manager = $archived_file_id ? 1 : 0;

    if ( !$plate_info->{design} || !$plate_info->{genotyping_facility_submit} || !$plate_info->{genotyping_project_id} || !$plate_info->{name} || !$plate_info->{sample_type} || !$plate_info->{plate_format} ) {
        $c->stash->{rest} = { error => "Please provide all parameters in the plate information section" };
        $c->detach();
    }

    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $basepath = $c->config->{basepath};

    # __SP_JOB_ID__ is filled in by CXGN::Job when the job is submitted, so that the script can
    # report its messages back to this job, and can read the plate it is to store off it.
    my $cmd = "perl \"$basepath/bin/store_genotype_trial.pl\" -H \"$dbhost\" -D \"$dbname\" -U \"$dbuser\" -P \"$dbpass\" -w \"$basepath\" -un \"$user_name\" -j __SP_JOB_ID__";

    my $upload_job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $user_id,
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        basepath => $basepath,
        cmd => $cmd,
        name => "$plate_info->{name} genotyping plate upload",
        job_type => 'upload',
        submit_page => ($c->req->referer ? $c->req->referer->as_string : undef),
        additional_args => {
            final_upload => 1,
            file_type => $file_type,
            user_name => "$user_first_name $user_last_name",
            file_id => $archived_file_id,
            genotyping_plate_name => $plate_info->{name},
            plate_data => $plate_info
        }
    });

    my $submit_error;
    try {
        $upload_job->submit();
    } catch {
        $submit_error = $_;
    };
    if ($submit_error) {
        $c->stash->{rest} = {error => "Could not submit the genotyping plate upload: $submit_error"};
        return;
    }

    if ($from_upload_manager) {
        $c->stash->{rest} = {success => 1, job_id => $upload_job->sp_job_id()};
        return;
    }

    $upload_job->wait();

    # The script reports its results by writing them to the job, so they have to be read back from
    # the database rather than from the object that submitted it.
    my $finished_job = CXGN::Job->new({
        sp_job_id => $upload_job->sp_job_id(),
        schema => $schema,
        people_schema => $people_schema
    });
    my $job_args = $finished_job->additional_args() || {};

    if ($job_args->{error_messages}) {
        $c->stash->{rest} = {error => $job_args->{error_messages}};
        return;
    }
    if (!$job_args->{trial_id}) {
        # The job left the queue without recording an outcome, which happens if the script died
        # before it could report anything.
        $c->stash->{rest} = {error => "The genotyping plate upload did not report a result. Check the status of upload job ".$upload_job->sp_job_id()."."};
        return;
    }

    $c->stash->{rest} = {
        message => $job_args->{success_messages},
        trial_id => $job_args->{trial_id},
        plate_data => $job_args->{brapi_plate_data}
    };
}

sub get_genotypingserver_credentials : Path('/ajax/breeders/genotyping_credentials') Args(0) {
    my $self = shift;
    my $c = shift;

    if ($c->user && ($c->user->check_roles("submitter") || $c->user->check_roles("curator"))) {
        $c->stash->{rest} = {
            host => $c->config->{genotyping_server_host},
            username => $c->config->{genotyping_server_username},
            password => $c->config->{genotyping_server_password},
            token => $c->config->{genotyping_server_token},
        };
    }
    else {
        $c->stash->{rest} = {
            error => "Insufficient privileges for this operation."
        };
    }
}

sub get_genotyping_data_projects : Path('/ajax/genotyping_data/projects') : ActionClass('REST') { }

sub get_genotyping_data_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_name = $c->req->param('select_checkbox_name');

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotype_data_project', 'pcr_genotype_data_project']
    });
    my ($data, $total_count) = $trial_search->search();
    my @result;
    foreach (@$data){
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' trial_name='$_->{trial_name}' value='$_->{trial_id}'>";
        }
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $_->{year},
            $_->{location_name},
            $_->{genotyping_facility}
        );
        push @result, \@res;
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

sub get_genotyping_data_protocols : Path('/ajax/genotyping_data/protocols') : ActionClass('REST') { }

sub get_genotyping_data_protocols_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    # my @protocol_list = $c->req->param('protocol_ids') ? split ',', $c->req->param('protocol_ids') : ();
    # my @accession_list = $c->req->param('accession_ids') ? split ',', $c->req->param('accession_ids') : ();
    # my @tissue_sample_list = $c->req->param('tissue_sample_ids') ? split ',', $c->req->param('tissue_sample_ids') : ();
    # my @genotyping_data_project_list = $c->req->param('genotyping_data_project_ids') ? split ',', $c->req->param('genotyping_data_project_ids') : ();
    my $limit;
    my $offset;

    my $data = CXGN::Genotype::Protocol::list_simple($bcs_schema);
    my @result;
    foreach (@$data){
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' protocol_name='$_->{protocol_name}' value='$_->{protocol_id}'>";
        }
        my $num_markers = $_->{marker_count};
        my @trimmed;
        foreach (@{$_->{header_information_lines}}){
            $_ =~ tr/<>//d;
            push @trimmed, $_;
        }
        my $description = join '<br/>', @trimmed;
        push @res, (
            "<a href=\"/breeders_toolbox/protocol/$_->{protocol_id}\">$_->{protocol_name}</a>",
            $description,
            $num_markers,
            $_->{protocol_description},
            $_->{reference_genome_name},
            $_->{species_name},
            $_->{sample_observation_unit_type_name},
            $_->{create_date}
        );
        push @result, \@res;
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}

sub create_plate_order : Path('/ajax/breeders/createplateorder') ActionClass('REST') {}
sub create_plate_order_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $plate_info = decode_json $c->req->param("order_info");

    my $plate_id = $plate_info->{plate_id};
    my $client_id = $plate_info->{client_id};
    my $service_id_list = $plate_info->{service_ids};
    my $facility_id = $plate_info->{facility_id};
    my $organism_name = $plate_info->{organism_name};
    my $add_requirements = $plate_info->{requeriments};

    print STDERR Dumper $plate_info;

    my $submit_samples = CXGN::Genotype::CreatePlateOrder->new({
        bcs_schema=>$schema,
        client_id=>$client_id,
        service_id_list=>$service_id_list,
        plate_id => $plate_id,
        facility_id => $facility_id,
        requeriments => $add_requirements,
        organism_name => $organism_name
    });
    # my $errors = $submit_samples->validate();
    my $order = $submit_samples->create();

    print Dumper $order;

    if($order){
        $c->stash->{rest} = {
            message => "Successfully order created.",
            trial_id => $plate_id,
            order => $order
        };
    }
}

sub store_plate_order : Path('/ajax/breeders/storeplateorder') ActionClass('REST') {}
sub store_plate_order_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $order_info = decode_json $c->req->param("order");

    my $plate_id = $c->req->param("plate_id");
    my $order_id = $order_info->{orderId} || undef;
    my $submission_id = $order_info->{submissionId} || undef;
    my $shipment = $order_info->{shipmentForms};

    my $genotyping_trial;
    my $message;
    if ($plate_id && $order_id) {
        $genotyping_trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $plate_id });
        $genotyping_trial->set_genotyping_vendor_order_id(encode_json $order_info);
        $message = "Successfully stored.";
    } elsif ($plate_id && $submission_id) {
        $genotyping_trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $plate_id });
        $genotyping_trial->set_genotyping_vendor_submission_id(encode_json $order_info);
        $message = "Successfully stored.";
    } else {
        my $error = "There was an error trying to store submission order";
        $c->stash->{rest} = {
            message => $error
        };
    }

    $c->stash->{rest} = {
        message => $message,
        order_id => $order_id
    };

}


sub set_project_for_genotyping_plate : Path('/ajax/breeders/set_project_for_genotyping_plate') ActionClass('REST') {}
sub set_project_for_genotyping_plate_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $genotyping_project_id = $c->req->param("genotyping_project_id");
    my $genotyping_plate_ids = decode_json $c->req->param("genotyping_plate_ids");

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to move genotyping plates to this project.' };
        $c->detach();
    }

    my $genotyping_project_obj = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $schema,
        project_id => $genotyping_project_id,
        new_genotyping_plate_list => $genotyping_plate_ids
    });

    my $errors = $genotyping_project_obj->validate_relationship();
    if (scalar(@{$errors->{error_messages}}) > 0){
        my $error_string = join ', ', @{$errors->{error_messages}};
        $c->stash->{rest} = { error => "Error: $error_string and this project are associated with different genotyping facilities."};
        $c->detach();
    }

    $genotyping_project_obj->set_project_for_genotyping_plate();

    if (!$genotyping_project_obj->set_project_for_genotyping_plate()){
        $c->stash->{rest} = {error => "Error adding genotyping plate to this project",};
        return;
    }

    $c->stash->{rest} = { success => 1};
}


sub plate_genotyping_data_delete : Path('/ajax/breeders/plate_genotyping_data_delete') : ActionClass('REST') { }

sub plate_genotyping_data_delete_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $genotyping_plate_id = $c->req->param("genotyping_plate_id");

    #print STDERR Dumper $c->req->params();
    my $session_id = $c->req->param("sgn_session_id");
    my $user_id;
    my $user_role;
    my $user_name;
    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]) {
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
            return;
        }

        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
            return;
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to delete genotyping data! Please contact us.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $genotyping_data = CXGN::Genotype::Delete->new( { bcs_schema => $schema, genotyping_plate_id => $genotyping_plate_id });
    my $response = $genotyping_data->delete_genotype_data();

    my $empty_protocol_name;
    my $empty_protocol_id;
    if ($response) {
        if ($response->{empty_protocol_id}) {
            $empty_protocol_id = $response->{empty_protocol_id};
            $empty_protocol_name = $response->{empty_protocol_name};
        } else {
            $c->stash->{rest} = { error => "An error occurred attempting to delete genotyping data. ($@)" };
            return;
        }
    }

    my $basepath = $c->config->{basepath};
    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
#    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$dbname, } );
#    my $refresh = $bs->refresh_matviews($dbhost, $dbname, $dbuser, $dbpass, 'fullview', 'concurrent', $basepath);

    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl $basepath/bin/refresh_materialized_markerview.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass");

    if ($empty_protocol_id) {
        $c->stash->{rest} = { empty_protocol_id => $empty_protocol_id, empty_protocol_name => $empty_protocol_name };
    } else {
        $c->stash->{rest} = { success => 1 };
    }

}



1;
