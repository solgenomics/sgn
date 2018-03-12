
package SGN::Controller::AJAX::GenotypingTrial;

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
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub generate_genotype_trial : Path('/ajax/breeders/generategenotypetrial') ActionClass('REST') {}
sub generate_genotype_trial_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
        $c->stash->{rest} = { error => 'You do not have the required privileges to create a genotyping trial.' };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $plate_info = decode_json $c->req->param("plate_data");
    print STDERR Dumper $plate_info;

    if ( !$plate_info->{elements} || !$plate_info->{genotyping_facility_submit} || !$plate_info->{project_name} || !$plate_info->{description} || !$plate_info->{location} || !$plate_info->{year} || !$plate_info->{name} || !$plate_info->{breeding_program} || !$plate_info->{genotyping_facility} || !$plate_info->{sample_type} || !$plate_info->{plate_format} ) {
        $c->stash->{rest} = { error => "Please provide all parameters" };
        $c->detach();
    }

    if ( $plate_info->{genotyping_facility} eq 'igd' && $plate_info->{genotyping_facility_submit} eq 'yes' && $plate_info->{blank_well} eq ''){
        $c->stash->{rest} = { error => "To submit to Cornell IGD you need to provide the blank well!" };
        $c->detach();
    }

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $plate_info->{location} } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $plate_info->{breeding_program} });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
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


sub parse_genotype_trial_file : Path('/ajax/breeders/parsegenotypetrial') : ActionClass('REST') { }
sub parse_genotype_trial_file_POST : Args(0) {
    my ($self, $c) = @_;

    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('genotyping_trial_layout_upload');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "genotyping_trial_upload";
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
            $c->stash->{rest} = {error=>'You must be logged in to upload genotyping trial!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload a genotyping trial!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a genotyping trial." };
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

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('GenotypeTrialXLS');
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
        $design{$val->{well}} = {
            plot_name => $val->{sample_id},
            stock_name => $val->{source_stock_uniquename},
            plot_number => $val->{well},
            row_number => $val->{row},
            col_number => $val->{column},
            is_blank => $val->{is_blank},
            concentration => $val->{concentration},
            volume => $val->{volume},
            tissue_type => $val->{tissue_type},
            dna_person => $val->{dna_person},
            extraction => $val->{extraction},
            acquisition_date => $val->{date},
            notes => $val->{notes},
            ncbi_taxonomy_id => $val->{ncbi_taxonomy_id}
        };
    }

    $c->stash->{rest} = {success => "1", design=>\%design};
}

sub store_genotype_trial : Path('/ajax/breeders/storegenotypetrial') ActionClass('REST') {}
sub store_genotype_trial_POST : Args(0) {
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
            $c->stash->{rest} = {error=>'You must be logged in to upload genotyping trial!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload a genotyping trial!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator' && $user_role ne 'submitter') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a genotyping trial." };
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $plate_info = decode_json $c->req->param("plate_data");
    #print STDERR Dumper $plate_info;

    if ( !$plate_info->{design} || !$plate_info->{genotyping_facility_submit} || !$plate_info->{project_name} || !$plate_info->{description} || !$plate_info->{location} || !$plate_info->{year} || !$plate_info->{name} || !$plate_info->{breeding_program} || !$plate_info->{genotyping_facility} || !$plate_info->{sample_type} || !$plate_info->{plate_format} ) {
        $c->stash->{rest} = { error => "Please provide all parameters" };
        $c->detach();
    }

    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $plate_info->{location} } );
    if (!$location) {
        $c->stash->{rest} = { error => "Unknown location" };
        $c->detach();
    }

    my $breeding_program = $schema->resultset("Project::Project")->find( { project_id => $plate_info->{breeding_program} });
    if (!$breeding_program) {
        $c->stash->{rest} = { error => "Unknown breeding program" };
        $c->detach();
    }

    print STDERR "Creating the genotyping trial...\n";

    my $message;
    my $coderef = sub {

        my $ct = CXGN::Trial::TrialCreate->new( {
            chado_schema => $schema,
            dbh => $c->dbc->dbh(),
            user_name => $user_name, #not implemented,
            operator => $user_name,
            trial_year => $plate_info->{year},
            trial_location => $location->description(),
            program => $breeding_program->name(),
            trial_description => $plate_info->{description},
            design_type => 'genotyping_plate',
            design => $plate_info->{design},
            trial_name => $plate_info->{name},
            is_genotyping => 1,
            genotyping_user_id => $user_id,
            genotyping_project_name => $plate_info->{project_name},
            genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
            genotyping_facility => $plate_info->{genotyping_facility},
            genotyping_plate_format => $plate_info->{plate_format},
            genotyping_plate_sample_type => $plate_info->{sample_type},
        });

        $message = $ct->save_trial();
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $c->stash->{rest} = {error => "Error saving genotyping trial in the database: $_"};
        $c->detach;
    };

    my $error;
    if ($message->{'error'}) {
        $error = $message->{'error'};
    }
    if ($error){
        $c->stash->{rest} = {error => "Error saving genotyping trial in the database: $error"};
        $c->detach;
    }
    #print STDERR Dumper(%message);

    my $saved_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $message->{trial_id}, experiment_type=>'genotyping_layout'});
    my $saved_design = $saved_layout->get_design();
    #print STDERR Dumper $saved_design;

    my @brapi_samples;
    foreach (values %$saved_design){
        push @brapi_samples, {
            sampleDbId => $_->{plot_id},
            sampleName => $_->{plot_name},
            well => $_->{plot_number},
            row => $_->{row_number},
            column => $_->{col_number},
            concentration => $_->{concentration},
            volume => $_->{volume},
            tissueType => $_->{tissue_type},
            taxonId => {
                sourceName => 'NCBI',
                taxonId => $_->{ncbi_taxonomy_id}
            }
        };
    }

    my $brapi_plate_data = {
        vendorProjectDbId => $plate_info->{project_name},
        clientPlateDbId => $message->{trial_id},
        clientPlateName => $plate_info->{name},
        plateFormat => $plate_info->{plate_format},
        sampleType => $plate_info->{sample_type},
        samples => \@brapi_samples
    };

    $c->stash->{rest} = {
        message => "Successfully stored the genotyping trial.",
        trial_id => $message->{trial_id},
        plate_data => $brapi_plate_data
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

1;
