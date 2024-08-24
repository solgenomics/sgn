
package SGN::Controller::AJAX::TrackingActivity;

use Moose;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use Data::Dumper;
use JSON;
use DateTime;
use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Trial::Download;
use CXGN::Stock::TrackingActivity::TrackingIdentifier;
use CXGN::Stock::TrackingActivity::ActivityInfo;
use CXGN::TrackingActivity::AddActivityProject;
use CXGN::TrackingActivity::ActivityProject;
use SGN::Model::Cvterm;
use CXGN::Location::LocationLookup;
use CXGN::List;
use CXGN::Stock::Status;

use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use File::Path qw(make_path);
use File::Spec::Functions qw / catfile catdir/;

use LWP::UserAgent;
use LWP::Simple;
use HTML::Entities;
use URI::Encode qw(uri_encode uri_decode);
use Tie::UrlEncoder; our(%urlencode);


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub create_tracking_activity_project : Path('/ajax/tracking_activity/create_tracking_activity_project') : ActionClass('REST'){ }

sub create_tracking_activity_project_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (!($user->has_role('submitter') or $user->has_role('curator'))) {
        $c->stash->{rest} = { error => "You do not have sufficient privileges to create tracking activity project." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my $project_name = $c->req->param("project_name");
    my $activity_type = $c->req->param("activity_type");
    my $breeding_program_id = $c->req->param("breeding_program");
    my $project_location = $c->req->param("project_location");
    my $year = $c->req->param("year");
    my $project_description = $c->req->param("project_description");

    my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema =>$schema);
    $geolocation_lookup->set_location_name($project_location);
    if(!$geolocation_lookup->get_geolocation()){
        $c->stash->{rest}={error => "Location not found"};
        return;
    }

    my $error;
    eval{
        my $add_activity_project = CXGN::TrackingActivity::AddActivityProject->new({
            bcs_schema => $schema,
            dbh => $dbh,
            breeding_program_id => $breeding_program_id,
            year => $year,
            project_description => $project_description,
            activity_project_name => $project_name,
            activity_type => $activity_type,
            nd_geolocation_id => $geolocation_lookup->get_geolocation()->nd_geolocation_id(),
            owner_id => $user_id
        });

        my $return = $add_activity_project->save_activity_project();
        if (!$return){
            $c->stash->{rest} = {error => "Error saving project",};
            return;
        }

#        if ($return->{error}){
#            $error = $return->{error};
#        }
    };

    if ($@) {
        $c->stash->{rest} = {error => $@};
        return;
    };


    if ($error){
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {success => 1};
    }

}


sub generate_tracking_identifiers : Path('/ajax/tracking_activity/generate_tracking_identifiers') : ActionClass('REST'){ }

sub generate_tracking_identifiers_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->stash->{rest} = { error_string => "You must be logged in to generate tracking identifiers." };
        return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error_string => "You do not have sufficient privileges to generate tracking identifiers." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh();

    my $project_name = $c->req->param("project_name");
    my $list_id = $c->req->param("list_id");
    my $project_id;
    my $project_rs = $schema->resultset("Project::Project")->find( { name => $project_name });
    if (!$project_rs) {
        $c->stash->{rest} = { error_string => "Error! Project name: $project_name was not found in the database.\n" };
        return;
    } else {
        $project_id = $project_rs->project_id();
    }

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id);
    my $all_identifiers = $activity_project->get_project_active_identifiers();
    my $last_number = scalar (@$all_identifiers);

    my $list = CXGN::List->new( { dbh=>$dbh, list_id=>$list_id });
    my $material_names = $list->elements();

    my @check_identifier_names;
    my @tracking_identifiers;
    my @error_messages;
    foreach my $name (sort @$material_names) {
        $last_number++;
        my $tracking_id = $project_name.":".$name."_"."T".(sprintf "%04d", $last_number);
        push @tracking_identifiers, [$tracking_id, $name];
        push @check_identifier_names, $tracking_id;
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@check_identifier_names }
    });
    while (my $r=$rs->next){
        push @error_messages, "Tracking identifier name already exists in database: ".$r->uniquename;
    }

    if (scalar(@error_messages) >= 1) {
        $c->stash->{rest} = { error_string => \@error_messages};
        return;
    }

    foreach my $identifier_info (@tracking_identifiers) {
        my $tracking_identifier = $identifier_info->[0];
        my $material = $identifier_info->[1];

        my $tracking_obj = CXGN::Stock::TrackingActivity::TrackingIdentifier->new({
            schema => $schema,
            phenome_schema => $phenome_schema,
            tracking_identifier => $tracking_identifier,
            material => $material,
            project_id => $project_id,
            user_id => $user_id
         });

        my $return = $tracking_obj->store();
        if (!$return){
            $c->stash->{rest} = {error_string => "Error generating tracking identifier",};
            return;
        }
    }

    $c->stash->{rest} = { success => 1};

}


sub activity_info_save : Path('/ajax/tracking_activity/save') : ActionClass('REST'){ }

sub activity_info_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to add new information." };
        return;
    }
    if (!($c->user()->has_role('submitter') or $c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error => "You do not have sufficient privileges to record new information." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $tracking_identifier = $c->req->param("tracking_identifier");
    my $selected_type = $c->req->param("selected_type");
    my $input = $c->req->param("input");
    my $notes = $c->req->param("notes");
    my $record_timestamp = $c->req->param("record_timestamp");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $add_activity_info = CXGN::Stock::TrackingActivity::ActivityInfo->new({
        schema => $schema,
        tracking_identifier => $tracking_identifier,
        selected_type => $selected_type,
        input => $input,
        timestamp => $record_timestamp,
        operator_id => $user_id,
        notes => $notes,
    });
    my $return = $add_activity_info->add_info();
#    print STDERR "ADD INFO =".Dumper ($add_activity_info->add_info())."\n";

    if (!$return){
        $c->stash->{rest} = {error => "Error saving info",};
        return;
    } else {
        $c->stash->{rest} = $return;
    }

}


sub get_activity_details :Path('/ajax/tracking_activity/details') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $identifier_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my @details;
    my $tracking_activities = $c->config->{tracking_activities};
    my @activity_types = split ',',$tracking_activities;

    my $tracking_data_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id();
    my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_data_json_cvterm_id});
    if ($activity_info_rs) {
        my $activity_json = $activity_info_rs->value();
        my $info = JSON::Any->jsonToObj($activity_json);
        my %info_hash = %{$info};
        foreach my $type (@activity_types){
            my $empty_string;
            my @each_type_details = ();
            my $each_timestamp_string;
            my $each_type_string;
            if ($info_hash{$type}) {
                my @each_type_details = ();
                my $details = {};
                my %details_hash = ();
                $details = $info_hash{$type};
                %details_hash = %{$details};
#                print STDERR "DETAILS HASH =".Dumper(\%details_hash);
                foreach my $timestamp (sort keys %details_hash) {
                    my @each_timestamp_details = ();
                    push @each_timestamp_details, "timestamp".":"."".$timestamp;
                    my $operator_id = $details_hash{$timestamp}{'operator_id'};

                    my $person= CXGN::People::Person->new($dbh, $operator_id);
                    my $operator_name = $person->get_first_name()." ".$person->get_last_name();

                    push @each_timestamp_details, "operator".":"."".$operator_name;
                    my $input = $details_hash{$timestamp}{'input'};
                    push @each_timestamp_details, "count".":"."".$input;
                    my $notes = $details_hash{$timestamp}{'notes'};
                    push @each_timestamp_details, "notes".":"."".$notes;

                    push @each_timestamp_details, $empty_string;

                    $each_timestamp_string = join("<br>", @each_timestamp_details);
                    push @each_type_details, $each_timestamp_string;
                }

                $each_type_string = join("<br>", @each_type_details);
#                print STDERR "EACH TYPE STRING =".Dumper($each_type_string)."\n";
                push @details, $each_type_string;
            } else {
                my $empty_string;
                push @details, $empty_string;
            }
        }
    } else {
        foreach my $type (@activity_types) {
            push @details, 'NA';
        }
    }

    my @all_details;
    push @all_details, [@details];

#    print STDERR "ALL DETAILS =".Dumper(\@all_details)."\n";

    $c->stash->{rest} = { data => \@all_details };

}


sub get_activity_summary :Path('/ajax/tracking_activity/summary') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $identifier_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my @summary = ();
    my $tracking_activities = $c->config->{tracking_activities};
    my @activity_types = split ',',$tracking_activities;

    my $tracking_data_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id();
    my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_data_json_cvterm_id});
    if ($activity_info_rs) {
        my $input;
        my $activity_json = $activity_info_rs->value();
        my $info = JSON::Any->jsonToObj($activity_json);
        my %info_hash = %{$info};
        foreach my $type (@activity_types){
            my $empty_string;
            my @each_type_details = ();
            my $each_timestamp_string;
            my $each_type_string;
            if ($info_hash{$type}) {
                my $details = {};
                my %details_hash = ();
                $details = $info_hash{$type};
                %details_hash = %{$details};
                my $input = 0;
                foreach my $key (keys %details_hash) {
                    $input += $details_hash{$key}{'input'};
                }
                push @summary, $input;
            } else {
                push @summary, $input;
            }
        }
    } else {
        foreach my $type (@activity_types) {
            push @summary, 'NA';
        }
    }

    my @all_summary;
    push @all_summary, [@summary];

    $c->stash->{rest} = { data => \@all_summary };

}

sub get_project_active_identifiers :Path('/ajax/tracking_activity/project_active_identifiers') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $project_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $tracking_activities = $c->config->{tracking_activities};
    my @activity_types = split ',',$tracking_activities;

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id);
    my $all_identifier_info = $activity_project->get_project_active_identifiers();
    my @all_identifiers;
    foreach my $identifier_info (@$all_identifier_info) {
        my @row = ();
        my $identifier_id = $identifier_info->[0];
        my $identifier_name = $identifier_info->[1];
        my $material_id = $identifier_info->[2];
        my $material_name = $identifier_info->[3];
        push @row, qq{<a href="/activity/details/$identifier_id">$identifier_name</a>};
        push @row, qq{<a href="/stock/$material_id/view">$material_name</a>};
        my $progress = $identifier_info->[5];
        my $input;
        if ($progress) {
            my $progress_ref = JSON::Any->jsonToObj($progress);
            my %progress_hash = %{$progress_ref};
            foreach my $type (@activity_types){
                if ($progress_hash{$type}) {
                    my $details = {};
                    my %details_hash = ();
                    $details = $progress_hash{$type};
                    %details_hash = %{$details};
                    my $input = 0;
                    foreach my $key (keys %details_hash) {
                        $input += $details_hash{$key}{'input'};
                    }
                    push @row, $input
                } else {
                    push @row, $input;
                }
            }
        } else {
            foreach my $type (@activity_types) {
                push @row, $input;
            }
        }
        push @row, $identifier_name;
        push @all_identifiers,[@row];
    }

    $c->stash->{rest} = { data => \@all_identifiers };

}


sub get_project_active_identifier_names :Path('/ajax/tracking_activity/project_active_identifier_names') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $project_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id);
    my $all_identifier_info = $activity_project->get_project_active_identifiers();
    my @identifier_names;
    foreach my $identifier_info (@$all_identifier_info) {
        push @identifier_names, $identifier_info->[1];
    }

    $c->stash->{rest} = { data => \@identifier_names };

}


sub update_status : Path('/ajax/tracking_activity/update_status') : ActionClass('REST'){ }

sub update_status_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh();
    my $identifier_id = $c->req->param("identifier_id");
    my $status_type = $c->req->param("status_type");
    my $comments = $c->req->param("comments");
    my $time = DateTime->now();
    my $update_date = $time->ymd();

    if (!$c->user()){
        $c->stash->{rest} = { error_string => "You must be logged in to update status" };
        return;
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error_string => "You do not have the correct role to update status. Please contact us." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $tracking_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "tracking_identifier", 'stock_type')->cvterm_id();

    my $identifier_rs = $schema->resultset("Stock::Stock")->find( { stock_id => $identifier_id, type_id => $tracking_identifier_type_id });
    if (!$identifier_rs) {
        $c->stash->{rest} = { error_string => 'Error. No stock entry found in the database.' };
	    return;
    }

    my $update_status = CXGN::Stock::Status->new({
        bcs_schema => $schema,
        parent_id => $identifier_id,
    });

    $update_status->person_id($user_id);
    $update_status->update_date($update_date);
    $update_status->comments($comments);

    $update_status->store();

    if (!$update_status->store()){
        $c->stash->{rest} = {error_string => "Error updating status"};
        return;
    }

    $c->stash->{rest} = {success => "1",};

}



1;
