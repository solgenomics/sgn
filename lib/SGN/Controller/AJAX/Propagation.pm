package SGN::Controller::AJAX::Propagation;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Person;
use SGN::Image;
use CXGN::Stock::StockLookup;
use CXGN::Stock::ParseUpload;
use CXGN::Location::LocationLookup;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::List;
use CXGN::BreedersToolbox::Projects;
use CXGN::Propagation::AddPropagationProject;
use CXGN::Propagation::AddPropagationGroup;
use CXGN::Propagation::AddPropagationIdentifier;
use CXGN::Propagation::AddInventoryIdentifier;
use CXGN::Propagation::Propagation;
use CXGN::Propagation::Status;
use DateTime;
use JSON;
use JSON::Any;
use List::MoreUtils qw /any /;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub add_propagation_project : Path('/ajax/propagation/add_propagation_project') : ActionClass('REST') {}

sub add_propagation_project_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $project_name = $c->req->param('project_name');
    my $propagation_type = $c->req->param('propagation_type');
    my $breeding_program_id = $c->req->param('project_program_id');
    my $location = $c->req->param('project_location');
    my $year = $c->req->param('year');
    my $project_description = $c->req->param('project_description');
    $project_name =~ s/^\s+|\s+$//g;

    print STDERR "PROJECT NAME =".Dumper($project_name)."\n";

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a propagation project." };
        return;
    }

    my $program_name = $schema->resultset('Project::Project')->find({project_id => $breeding_program_id})->name();
    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    if (! ( (exists($has_roles{$program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
        $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $program_name to add new propagation project." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
       $geolocation_lookup->set_location_name($location);
       if(!$geolocation_lookup->get_geolocation()){
           $c->stash->{rest}={error => "Location not found"};
           return;
       }

    my $error;
    my $return;
    my $propagation_project_id;
    eval{
        my $add_propagation_project = CXGN::Propagation::AddPropagationProject->new({
            chado_schema => $schema,
            dbh => $dbh,
            breeding_program_id => $breeding_program_id,
            year => $year,
            project_description => $project_description,
            propagation_project_name => $project_name,
            propagation_type => $propagation_type,
            nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
            owner_id => $user_id
        });

        $return = $add_propagation_project->save_propagation_project();
    };

    if (!$return){
        $c->stash->{rest} = {error => "Error saving project",};
        return;
    }

    if ($return->{error}){
        $error = $return->{error};
        $c->stash->{rest}={error => $error};
        return;
    } else {
        $propagation_project_id = $return->{project_id};
    }

    if ($@) {
        $c->stash->{rest} = {error => $@};
        return;
    };

    $c->stash->{rest} = {success => 1};

}


sub add_propagation_group_identifier : Path('/ajax/propagation/add_propagation_group_identifier') : ActionClass('REST') {}

sub add_propagation_group_identifier_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $propagation_group_identifier = $c->req->param('propagation_group_identifier');
    $propagation_group_identifier =~ s/^\s+|\s+$//g;
    my $propagation_project_id = $c->req->param('propagation_project_id');
    my $accession_name = $c->req->param('accession_name');
    my $material_type = $c->req->param('material_type');
    my $material_source_type = $c->req->param('material_source_type');
    my $source_name = $c->req->param('source_name');
    my $sub_location = $c->req->param('sub_location');
    my $date = $c->req->param('date');
    my $description = $c->req->param('description');
    my $operator_name = $c->req->param('operator_name');
    my $program_name = $c->req->param('breeding_program_name');

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a propagation group ID." };
        return;
    }

    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    if (! ( (exists($has_roles{$program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
        $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $program_name to add propagation group identifiers." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'accession', 'stock_type')->cvterm_id();

    if ($schema->resultset("Stock::Stock")->find({uniquename => $propagation_group_identifier})){
        $c->stash->{rest} = {error =>  "Propagation Group Identifier already exists. Please use another name" };
        return;
    }

    if (! $schema->resultset("Stock::Stock")->find({uniquename => $accession_name, type_id => $accession_cvterm_id })){
        $c->stash->{rest} = {error =>  "Accession name does not exist or does not exist as accession uniquename." };
        return;
    }

    if ($source_name) {
        if (! $schema->resultset("Stock::Stock")->find({uniquename => $source_name})){
            $c->stash->{rest} = {error =>  "Source name does not exist in the database." };
            return;
        }
    }

    my $propagation_group_stock_id;
    eval {
        my $add_propagation_group_identifier = CXGN::Propagation::AddPropagationGroup->new({
            chado_schema => $schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            propagation_project_id => $propagation_project_id,
            propagation_group_identifier => $propagation_group_identifier,
            accession_name => $accession_name,
            material_type => $material_type,
            material_source_type => $material_source_type,
            source_name => $source_name,
            sub_location => $sub_location,
            date => $date,
            description => $description,
            operator_name => $operator_name,
            owner_id => $user_id,
        });

        my $add = $add_propagation_group_identifier->add_propagation_group_identifier();
        $propagation_group_stock_id = $add->{propagation_group_stock_id};
    };

    if ($@) {
        $c->stash->{rest} = { success => 0, error => $@ };
        print STDERR "An error condition occurred, was not able to create propagation group identifier. ($@).\n";
        return;
    }

    $c->stash->{rest} = { success => 1 };

}

sub upload_propagation_group_identifiers : Path('/ajax/propagation/upload_propagation_group_identifiers') : ActionClass('REST'){ }

sub upload_propagation_group_identifiers_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $propagation_project_id = $c->req->param('propagation_project_id');
    my $upload = $c->req->upload('propagation_group_ids_file');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "propagation_group_identifiers_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
    my $session_id = $c->req->param("sgn_session_id");
    my @error_messages;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload propagation group identifers!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload propagation group identifiers!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload propagation group identifiers'};
        $c->detach();
    }

    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    my $program_ref = $program_object->get_breeding_programs_by_trial($propagation_project_id);

    my $program_array = @$program_ref[0];
    my $breeding_program_name = @$program_array[1];
    my @user_roles = $c->user->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    if (! ( (exists($has_roles{$breeding_program_name}) && exists($has_roles{submitter})) || exists($has_roles{curator}))) {
      $c->stash->{rest} = { error => "You need to be either a curator, or a submitter associated with breeding program $breeding_program_name to upload propagation group identifiers." };
      return;
    }


    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

        ## Store uploaded temporary file in arhive
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    #parse uploaded file with appropriate plugin
    my @stock_props = ();
    $parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props=>\@stock_props);

    $parser->load_plugin('PropagationGroupIdentifiersGeneric');
    $parsed_data = $parser->parse();
    #print STDERR "PARSED DATA =". Dumper($parsed_data)."\n";
    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    if ($parsed_data){
        eval {
            foreach my $row (keys %$parsed_data) {
                my $propagation_group_identifier = $parsed_data->{$row}->{'propagation_group_identifier'};
                my $accession_name = $parsed_data->{$row}->{'accession_name'};
                my $material_type = $parsed_data->{$row}->{'material_type'};
                my $material_source_type = $parsed_data->{$row}->{'material_source_type'};
                my $source_name = $parsed_data->{$row}->{'source_name'};
                my $sub_location = $parsed_data->{$row}->{'sub_location'};
                my $date = $parsed_data->{$row}->{'date'};
                my $description = $parsed_data->{$row}->{'description'};
                my $operator_name = $parsed_data->{$row}->{'operator_name'};

                my $add_propagation_group_identifier = CXGN::Propagation::AddPropagationGroup->new({
                    chado_schema => $schema,
                    phenome_schema => $phenome_schema,
                    dbh => $dbh,
                    propagation_project_id => $propagation_project_id,
                    propagation_group_identifier => $propagation_group_identifier,
                    accession_name => $accession_name,
                    material_type => $material_type,
                    material_source_type => $material_source_type,
                    source_name => $source_name,
                    sub_location => $sub_location,
                    date => $date,
                    description => $description,
                    operator_name => $operator_name,
                    owner_id => $user_id,
                });

                my $add = $add_propagation_group_identifier->add_propagation_group_identifier();
            }
        };

        if ($@) {
            $c->stash->{rest} = { success => 0, error => $@ };
            print STDERR "An error condition occurred, was not able to create propagation group ID. ($@).\n";
            return;
        }
    }


    $c->stash->{rest} = {success => "1",};
}


sub add_propagation_identifier : Path('/ajax/propagation/add_propagation_identifier') : ActionClass('REST') {}

sub add_propagation_identifier_POST :Args(0){
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $propagation_identifier = $c->req->param('propagation_identifier');
    $propagation_identifier =~ s/^\s+|\s+$//g;
    my $propagation_group_stock_id = $c->req->param('propagation_group_stock_id');
    my $rootstock_name = $c->req->param('rootstock_name');
    my $time = DateTime->now();
    my $update_date = $time->ymd();

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)){
        $c->stash->{rest} = {error =>  "you have insufficient privileges to add a propagation ID." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $person_name= CXGN::People::Person->new($dbh, $user_id);
    my $full_name = $person_name->get_first_name()." ".$person_name->get_last_name();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,'accession', 'stock_type')->cvterm_id();

    if ($schema->resultset("Stock::Stock")->find({uniquename => $propagation_identifier})){
        $c->stash->{rest} = {error =>  "Propagation Identifier already exists. Please use another name" };
        return;
    }

    if (! $schema->resultset("Stock::Stock")->find({uniquename => $rootstock_name, type_id => $accession_cvterm_id })){
        $c->stash->{rest} = {error =>  "Rootstock name does not exist or does not exist as accession uniquename." };
        return;
    }

    my $propagation_stock_id;
    eval {
        my $add_propagation_identifier = CXGN::Propagation::AddPropagationIdentifier->new({
            chado_schema => $schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            propagation_identifier => $propagation_identifier,
            propagation_group_stock_id => $propagation_group_stock_id,
            rootstock_name => $rootstock_name,
            owner_id => $user_id,
        });

        my $add = $add_propagation_identifier->add_propagation_identifier();
        $propagation_stock_id = $add->{propagation_stock_id};
    };
    print STDERR "PROPAGATION STOCK ID =".Dumper($propagation_stock_id)."\n";
    if ($@) {
        $c->stash->{rest} = { success => 0, error => $@ };
        print STDERR "An error condition occurred, was not able to create propagation identifier. ($@).\n";
        return;
    } else {
        my $status = CXGN::Propagation::Status->new({
            bcs_schema => $schema,
            parent_id => $propagation_stock_id,
        });

        $status->status_type('In Progress');
        $status->update_person($full_name);
        $status->update_date($update_date);

        $status->store();

        if (!$status->store()){
            $c->stash->{rest} = {error => "Error saving new propagation identifier",};
            return;
        }
    }

    $c->stash->{rest} = { success => 1 };

}


sub upload_propagation_identifiers : Path('/ajax/propagation/upload_propagation_identifiers') : ActionClass('REST'){ }

sub upload_propagation_identifiers_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('propagation_ids_file');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "propagation_identifiers_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my $time = DateTime->now();
    my $update_date = $time->ymd();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_role;
    my $user_id;
    my $user_name;
    my $owner_name;
    my $session_id = $c->req->param("sgn_session_id");
    my @error_messages;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload propagation identifers!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload propagation identifiers!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload propagation identifiers'};
        $c->detach();
    }

    my $person_name= CXGN::People::Person->new($dbh, $user_id);
    my $full_name = $person_name->get_first_name()." ".$person_name->get_last_name();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });

        ## Store uploaded temporary file in arhive
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    #parse uploaded file with appropriate plugin
    my @stock_props = ();
    $parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props=>\@stock_props);

    $parser->load_plugin('PropagationIdentifiersGeneric');
    $parsed_data = $parser->parse();
    print STDERR "PARSED DATA =". Dumper($parsed_data)."\n";
    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;
            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    }

    if ($parsed_data){
        foreach my $group_id (sort keys %$parsed_data) {
            my $group_rs = $schema->resultset("Stock::Stock")->find({'uniquename' => $group_id});
            my $group_stock_id = $group_rs->stock_id();

            my $propagation_id_info = $parsed_data->{$group_id};
            foreach my $propagation_identifier (sort keys %$propagation_id_info) {
                my $rootstock_name = $propagation_id_info->{$propagation_identifier}->{'rootstock'};
                my $status = $propagation_id_info->{$propagation_identifier}->{'status'};
                my $status_date = $propagation_id_info->{$propagation_identifier}->{'status_date'};
                my $status_notes = $propagation_id_info->{$propagation_identifier}->{'status_notes'};
                my $status_updated_by = $propagation_id_info->{$propagation_identifier}->{'status_updated_by'};
                my $inventory_identifier = $propagation_id_info->{$propagation_identifier}->{'inventory_identifier'};

                my $add_propagation_identifier = CXGN::Propagation::AddPropagationIdentifier->new({
                    chado_schema => $schema,
                    phenome_schema => $phenome_schema,
                    dbh => $dbh,
                    propagation_identifier => $propagation_identifier,
                    propagation_group_stock_id => $group_stock_id,
                    rootstock_name => $rootstock_name,
                    owner_id => $user_id,
                });

                my $add = $add_propagation_identifier->add_propagation_identifier();
                my $propagation_stock_id = $add->{propagation_stock_id};

                if (!$propagation_stock_id) {
                    $c->stash->{rest} = {error => "Error saving new propagation identifier",};
                    return;
                }

                if (!$status) {
                    $status = 'In Progress';
                }
                if (!$status_date) {
                    $status_date = $update_date;
                }
                if (!$status_updated_by) {
                    $status_updated_by = $full_name;
                }

                if ($propagation_stock_id)  {
                    my $status = CXGN::Propagation::Status->new({
                        bcs_schema => $schema,
                        parent_id => $propagation_stock_id,
                    });

                    $status->status_type($status);
                    $status->update_person($status_updated_by);
                    $status->update_date($status_date);
                    $status->update_notes($status_notes);
                    $status->store();

                    if (!$status->store()){
                        $c->stash->{rest} = {error => "Error saving new propagation identifier",};
                        return;
                    }

                    if (($status eq 'Inventoried') && $inventory_identifier) {
                        my $add_inventory_identifier = CXGN::Propagation::AddInventoryIdentifier->new({
                            chado_schema => $schema,
                            phenome_schema => $phenome_schema,
                            dbh => $dbh,
                            propagation_stock_id => $propagation_stock_id,
                            inventory_identifier => $inventory_identifier,
                            owner_id => $user_id,
                        });

                        my $add = $add_inventory_identifier->add();
                        my $inventory_stock_id = $add->{inventory_stock_id};
                        print STDERR "INVENTORY STOCK ID =".Dumper($inventory_stock_id)."\n";
                        if (!$inventory_stock_id) {
                            $c->stash->{rest} = {error => "Error saving Inventory Identifier!",};
                            return;
                        }
                    }
                }
            }
        }
    }


    $c->stash->{rest} = {success => "1",};
}


sub get_propagation_groups_in_project :Path('/ajax/propagation/propagation_groups_in_project') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $project_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;

    my $propagation_obj = CXGN::Propagation::Propagation->new({schema=>$schema, dbh=>$dbh, project_id=>$project_id});

    my $result = $propagation_obj->get_propagation_groups_in_project();
#    print STDERR "RESULT =".Dumper($result)."\n";
    my @propagations;
    foreach my $r (@$result){
        my $propagation_group_link = qq{<a href="/propagation_group/$r->[0]">$r->[1]</a>};
        my $description = $r->[2];
        my $material_type = $r->[3];
        my $metadata = $r->[4];
        my $metadata_hash = decode_json $metadata;
        my $date = $metadata_hash->{'date'};
        my $operator_name = $metadata_hash->{'operator'};
        my $sub_location = $metadata_hash->{'sub_location'};
        my $material_source_type = $metadata_hash->{'material_source_type'};

        my $accession_link = qq{<a href="/stock/$r->[5]/view">$r->[6]</a>};
        my $source_link = qq{<a href="/stock/$r->[7]/view">$r->[8]</a>};

        push @propagations, [$propagation_group_link, $accession_link, $material_type, $material_source_type, $source_link, $date, $sub_location, $description, $operator_name]

    }
    $c->stash->{rest} = { data => \@propagations };

}


sub get_active_propagation_ids_in_group :Path('/ajax/propagation/active_propagation_ids_in_group') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $propagation_group_stock_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;

    my $propagation_obj = CXGN::Propagation::Propagation->new({schema=>$schema, dbh=>$dbh, propagation_group_stock_id=>$propagation_group_stock_id});

    my $result = $propagation_obj->get_propagation_ids_in_group();
    my @propagations;
    foreach my $r (@$result){
        my ($propagation_stock_id, $propagation_name, $accession_stock_id, $accession_name, $rootstock_stock_id, $rootstock_name, $status) =@$r;
        my $status_info = decode_json $status;
        my $status_type = $status_info->{status_type};
        my $updated_date = $status_info->{update_date};
        my $updated_by = $status_info->{update_person};

        if ($status_type eq 'In Progress') {
            push @propagations, {
                propagation_stock_id => $propagation_stock_id,
                propagation_name => $propagation_name,
                accession_stock_id => $accession_stock_id,
                accession_name => $accession_name,
                rootstock_stock_id => $rootstock_stock_id,
                rootstock_name => $rootstock_name,
                propagation_status => $status_type,
                updated_date => $updated_date,
                updated_by => $updated_by,
            };
        }
    }

    $c->stash->{rest} = { data => \@propagations };

}


sub get_inactive_propagation_ids_in_group :Path('/ajax/propagation/inactive_propagation_ids_in_group') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $propagation_group_stock_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;

    my $propagation_obj = CXGN::Propagation::Propagation->new({schema=>$schema, dbh=>$dbh, propagation_group_stock_id=>$propagation_group_stock_id});

    my $result = $propagation_obj->get_propagation_ids_in_group();
    my @propagations;
    foreach my $r (@$result){
        my ($propagation_stock_id, $propagation_name, $accession_stock_id, $accession_name, $rootstock_stock_id, $rootstock_name, $status) =@$r;
#        print STDERR "STATUS 2 =".Dumper($status)."\n";

        my $status_info = decode_json $status;
        my $status_type = $status_info->{status_type};
        my $updated_date = $status_info->{update_date};
        my $updated_by = $status_info->{update_person};
        my $notes = $status_info->{update_notes};

        if ($status_type eq 'Inventoried') {
            my $inventory = CXGN::Propagation::Propagation->new({schema=>$schema, dbh=>$dbh, propagation_stock_id=>$propagation_stock_id});
            my $inventory_info = $inventory->get_associated_inventory_identifier();
            my $inventory_identifier = $inventory_info->[1];
            $status_type = 'Inventoried'.':'. ' '.$inventory_identifier;
        }

        if ($status_type ne 'In Progress') {
            push @propagations, {
                propagation_stock_id => $propagation_stock_id,
                propagation_name => $propagation_name,
                accession_stock_id => $accession_stock_id,
                accession_name => $accession_name,
                rootstock_stock_id => $rootstock_stock_id,
                rootstock_name => $rootstock_name,
                propagation_status => $status_type,
                updated_date => $updated_date,
                updated_by => $updated_by,
                notes => $notes
            };
        }
    }

    $c->stash->{rest} = { data => \@propagations };

}


sub update_propagation_status : Path('/ajax/propagation/update_status') : ActionClass('REST'){ }

sub update_propagation_status_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;

    my $propagation_stock_id = $c->req->param('propagation_stock_id');
    my $status_type = $c->req->param('propagation_status');
    my $update_notes = $c->req->param('propagation_status_notes');
    my $inventory_identifier = $c->req->param('inventory_identifier');
    my $time = DateTime->now();
    my $update_date = $time->ymd();
    my $user_id;

    if (!$c->user){
        $c->stash->{rest} = {error=>'You must be logged in to update the status!'};
        $c->detach();
    }

    if ($c->user) {
        $user_id = $c->user()->get_object()->get_sp_person_id();
    }

    my $person_name= CXGN::People::Person->new($dbh, $user_id);
    my $full_name = $person_name->get_first_name()." ".$person_name->get_last_name();

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");

    if ($inventory_identifier) {
        my $inventory_identifier_stock = $schema->resultset('Stock::Stock')->find({ uniquename => $inventory_identifier});
        if ($inventory_identifier_stock) {
            $c->stash->{rest} = {error => "Error: inventory identifier already exists, please use another inventory identifier!"};
            return;
        }
    }

    my $propagation_status_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_status', 'stock_property')->cvterm_id();
    my $previous_status = $schema->resultset("Stock::Stockprop")->find( {stock_id => $propagation_stock_id, type_id => $propagation_status_cvterm_id });
    my $previous_stockprop_id;
    if($previous_status) {
        $previous_stockprop_id = $previous_status->stockprop_id();
    }

    my $status = CXGN::Propagation::Status->new({
        bcs_schema => $schema,
        parent_id => $propagation_stock_id,
        prop_id => $previous_stockprop_id
    });

    $status->status_type($status_type);
    $status->update_person($full_name);
    $status->update_date($update_date);
    $status->update_notes($update_notes);
    $status->store();

    if (!$status->store()){
        $c->stash->{rest} = {error => "Error saving propagation status",};
        return;
    }

    my $inventory_stock_id;
    if ($status->store() && $inventory_identifier) {
        my $add_inventory_identifier = CXGN::Propagation::AddInventoryIdentifier->new({
            chado_schema => $schema,
            phenome_schema => $phenome_schema,
            dbh => $dbh,
            propagation_stock_id => $propagation_stock_id,
            inventory_identifier => $inventory_identifier,
            owner_id => $user_id,
        });

        my $add = $add_inventory_identifier->add();
        $inventory_stock_id = $add->{inventory_stock_id};
        print STDERR "INVENTORY STOCK ID =".Dumper($inventory_stock_id)."\n";
        if (!$inventory_stock_id) {
            $c->stash->{rest} = {error => "Error saving Inventory Identifier!",};
            return;
        }
    }

    $c->stash->{rest} = {success => "1",};

}



###
1;#
###
