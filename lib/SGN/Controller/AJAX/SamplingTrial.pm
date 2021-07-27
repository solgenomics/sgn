package SGN::Controller::AJAX::SamplingTrial;

use Moose;
use JSON;
use Data::Dumper;
use CXGN::Trial::TrialDesign;
use Try::Tiny;
use List::MoreUtils qw /any /;
use CXGN::People::Person;
use CXGN::Login;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub generate_sampling_trial : Path('/ajax/breeders/generatesamplingtrial') ActionClass('REST') {}
sub generate_sampling_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a sampling trial.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $sampling_data = decode_json $c->req->param("sampling_data");
    print STDERR Dumper $sampling_data;

    if ( !$sampling_data->{elements} || !$sampling_data->{description} || !$sampling_data->{location} || !$sampling_data->{year} || !$sampling_data->{name} || !$sampling_data->{breeding_program} || !$sampling_data->{sampling_facility} || !$sampling_data->{sample_type} ) {
        $c->stash->{rest} = { error => "Please provide all parameters in the basic sampling trial information section" };
        $c->detach();
    }
    if ( !$sampling_data->{replicates}) {
        $c->stash->{rest} = { error => "Please provide number of replicates" };
        $c->detach();
    }

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $sampling_data->{location} } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $sampling_data->{breeding_program} });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }

    my $td = CXGN::Trial::TrialDesign->new( { schema => $schema });

    $td->set_stock_list($sampling_data->{elements});
    $td->set_number_of_reps($sampling_data->{replicates});
    $td->set_trial_name($sampling_data->{name});
    $td->set_design_type("CRD");

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
        $_->{concentration} = $sampling_data->{sample_concentration};
        $_->{volume} = $sampling_data->{sample_volume};
        $_->{tissue_type} = $sampling_data->{sample_tissue};
        $_->{dna_person} = $sampling_data->{sample_person};
        $_->{extraction} = $sampling_data->{sample_extraction};
        $_->{acquisition_date} = $sampling_data->{sample_date};
        $_->{notes} = $sampling_data->{sample_notes};
        $_->{ncbi_taxonomy_id} = $sampling_data->{ncbi_taxonomy_id};

        delete($_->{seedlot_name});
        delete($_->{is_a_control});
        delete($_->{plot_num_per_block});
    }
    #print STDERR Dumper($design);

    $c->stash->{rest} = {success => 1, design=>$design};
}


sub parse_sampling_trial_file : Path('/ajax/breeders/parsesamplingtrial') : ActionClass('REST') { }
sub parse_sampling_trial_file_POST : Args(0) {
    my ($self, $c) = @_;

    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $sampling_trial_name = $c->req->param('sampling_trial_name');
    my $upload_xls = $c->req->upload('sampling_trial_layout_upload');
    if (!$upload_xls ){
        $c->stash->{rest} = {error => "You must upload a sampling trial file!" };
        return;
    }
    if (!$sampling_trial_name){
        $c->stash->{rest} = {error => 'Sampling trial name must be given!'};
        return;
    }
    my $parser;
    my $parsed_data;
    my $upload = $upload_xls;
    my $upload_type = 'SamplingTrialXLS';

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "sampling_trial_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my %upload_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $error;

    if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
        print STDERR "File name must not have spaces or slashes.\n";
        $c->stash->{rest} = {error => "Uploaded file name must not contain spaces or slashes." };
        return;
    }

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload sampling trial!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload sampling trial!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a sampling trial. Please contact us." };
        $c->detach();
    }

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    #Parse of Coordinate Template formatted file requires the plate name to be passed, so that a unique sample name can be created by concatenating the plate name to the well position.

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin($upload_type);
    $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';

        if (! $parser->has_parse_errors() ){
            $return_error = "Could not get parsing errors";
            $c->stash->{rest} = {error_string => $return_error,};
        }
        else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error=$return_error.$error_string."<br>";
            }
        }

        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'}};
        return;
    }
    #print STDERR Dumper $parsed_data;

    #Turn parased data into same format as generate_genotype_trial above
    my %design;
    foreach (sort keys %$parsed_data){
        my $val = $parsed_data->{$_};
        $design{$val->{sample_number}} = {
            acquisition_date => $val->{date},
            plot_name => $val->{sample_name},
            stock_name => $val->{source_stock_uniquename},
            plot_number => $val->{sample_number},
            rep_number => $val->{replicate},
            tissue_type => $val->{tissue_type},
            block_number => 1,
            ncbi_taxonomy_id => $val->{ncbi_taxonomy_id},
            dna_person => $val->{person},
            notes => $val->{notes},
            extraction => $val->{extraction},
            concentration => $val->{concentration},
            volume => $val->{volume},
        };
    }

    $c->stash->{rest} = {success => "1", design=>\%design};
}

sub store_sampling_trial : Path('/ajax/breeders/storesamplingtrial') ActionClass('REST') {}
sub store_sampling_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload sampling trial!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload a sampling trial!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a sampling trial." };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $sampling_data = decode_json $c->req->param("sampling_data");
    #print STDERR Dumper $plate_info;
    if ( !$sampling_data->{design} || !$sampling_data->{description} || !$sampling_data->{location} || !$sampling_data->{year} || !$sampling_data->{name} || !$sampling_data->{breeding_program} || !$sampling_data->{sampling_facility} || !$sampling_data->{sample_type} ) {
        $c->stash->{rest} = { error => "Please provide all parameters in the sampling trial information section" };
        $c->detach();
    }

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $sampling_data->{location} } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $sampling_data->{breeding_program} });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }

    my $field_nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id;
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
    my %source_stock_names;
    foreach (values %{$sampling_data->{design}}){
        $source_stock_names{$_->{stock_name}}++;
    }
    my @source_stock_names = keys %source_stock_names;

    #If plots or plants or tissue samples are provided as the source, we can get the field trial and use it to save the link between genotyping plate and field trial directly.
    my %field_trial_ids;
    my $plant_rs = $schema->resultset('Stock::Stock')->search({'me.uniquename' => {-in => \@source_stock_names}, 'me.type_id' => {-in => [$plot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id]}, 'nd_experiment_stocks.type_id'=>$field_nd_experiment_type_id, 'nd_experiment.type_id'=>$field_nd_experiment_type_id}, {'join' => {'nd_experiment_stocks' => {'nd_experiment' => 'nd_experiment_projects'}}, '+select'=>['nd_experiment_projects.project_id'], '+as'=>['trial_id']});
    while(my $r=$plant_rs->next){
        $field_trial_ids{$r->get_column('trial_id')}++;
    }
    my @field_trial_ids = keys %field_trial_ids;
    #print STDERR Dumper \@field_trial_ids;

    print STDERR "Creating the sampling trial...\n";

    my $message;
    my $coderef = sub {

        my $ct = CXGN::Trial::TrialCreate->new({
            chado_schema => $schema,
            dbh => $c->dbc->dbh(),
            owner_id => $user_id,
            operator => $user_name,
            trial_year => $sampling_data->{year},
            trial_location => $location->description(),
            program => $breeding_program->name(),
            trial_description => $sampling_data->{description},
            design_type => 'sampling_trial',
            design => $sampling_data->{design},
            trial_name => $sampling_data->{name},
            is_sampling_trial => 1,
            sampling_trial_facility => $sampling_data->{sampling_facility},
            sampling_trial_sample_type => $sampling_data->{sample_type},
            sampling_trial_from_field_trial => \@field_trial_ids,
        });

        $message = $ct->save_trial();
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $c->stash->{rest} = {error => "Error saving sampling trial in the database: $_"};
        $c->detach;
    };

    my $error;
    if ($message->{'error'}) {
        $error = $message->{'error'};
    }
    if ($error){
        $c->stash->{rest} = {error => "Error saving sampling trial in the database: $error"};
        $c->detach;
    }
    #print STDERR Dumper(%message);

    my $dbh = $c->dbc->dbh();
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

    my $saved_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $message->{trial_id}, experiment_type=>'sampling_layout'});
    my $saved_design = $saved_layout->get_design();
    #print STDERR Dumper $saved_design;

    $c->stash->{rest} = {
        message => "Successfully stored the sampling trial.",
        trial_id => $message->{trial_id},
        saved_design => $saved_design
    };
}

1;
