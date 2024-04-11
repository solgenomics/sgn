
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
use CXGN::Stock::TrackingActivity::AddTrackingIdentifier;
use CXGN::Stock::TrackingActivity::ActivityInfo;
use CXGN::TrackingActivity::AddActivityProject;
use CXGN::TrackingActivity::ActivityProject;
use SGN::Model::Cvterm;
use CXGN::Location::LocationLookup;
use CXGN::List;
use CXGN::Stock::TrackingIdentifier;

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
    my $material_type = $c->req->param("material_type");
    my $activity_type = $c->req->param("activity_type");
#    print STDERR "MATERIAL TYPE =".Dumper($material_type)."\n";
    my $project_id;
    my $project_rs = $schema->resultset("Project::Project")->find( { name => $project_name });
    if (!$project_rs) {
        $c->stash->{rest} = { error_string => "Error! Project name: $project_name was not found in the database.\n" };
        return;
    } else {
        $project_id = $project_rs->project_id();
    }

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id, activity_type => $activity_type);
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

        my $tracking_obj = CXGN::Stock::TrackingActivity::AddTrackingIdentifier->new({
            schema => $schema,
            phenome_schema => $phenome_schema,
            tracking_identifier => $tracking_identifier,
            material => $material,
            project_id => $project_id,
            user_id => $user_id,
            material_type => $material_type,
            activity_type => $activity_type
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
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

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

    my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
    my $identifier_id = $schema->resultset("Stock::Stock")->find( { uniquename => $tracking_identifier, type_id => $tracking_identifier_cvterm_id  })->stock_id();
    my $tracking_identifier_obj = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier_id);
    my $data_type = $tracking_identifier_obj->data_type;

    my $add_activity_info = CXGN::Stock::TrackingActivity::ActivityInfo->new({
        schema => $schema,
        tracking_identifier => $tracking_identifier,
        selected_type => $selected_type,
        input => $input,
        timestamp => $record_timestamp,
        operator_id => $user_id,
        notes => $notes,
        data_type => $data_type
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

    my $tracking_identifier = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier_id);
    my $data_type = $tracking_identifier->data_type;
    my $types_string;
    my @input_types = ();
    my $tracking_cvterm_id;

    my $tracking_tissue_culture_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id();
    my $tracking_trial_treatment_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_trial_treatments_json', 'stock_property')->cvterm_id();

    if ($data_type eq 'trial_treatments') {
        $types_string = $c->config->{tracking_trial_treatments};
        @input_types = split ',',$types_string;
        $tracking_cvterm_id = $tracking_trial_treatment_json_cvterm_id;
    } else {
        $types_string = $c->config->{tracking_activities};
        @input_types = split ',',$types_string;
        $tracking_cvterm_id = $tracking_tissue_culture_json_cvterm_id;
    }

    my @details;
    my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_cvterm_id});
    if ($activity_info_rs) {
        my $activity_json = $activity_info_rs->value();
        my $info = JSON::Any->jsonToObj($activity_json);
        my %info_hash = %{$info};
        foreach my $type (@input_types){
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
                    push @each_timestamp_details, "input".":"."".$input;
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
        foreach my $type (@input_types) {
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
    my $tracking_identifier = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier_id);
    my $data_type = $tracking_identifier->data_type;
    my $types_string;
    my @input_types = ();
    my $tracking_cvterm_id;
    my @summary = ();

    my $tracking_tissue_culture_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property')->cvterm_id();
    my $tracking_trial_treatment_json_cvterm_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_trial_treatments_json', 'stock_property')->cvterm_id();

    if ($data_type eq 'trial_treatments') {
        $types_string = $c->config->{tracking_trial_treatments};
        @input_types = split ',',$types_string;
        $tracking_cvterm_id = $tracking_trial_treatment_json_cvterm_id;
    } else {
        $types_string = $c->config->{tracking_activities};
        @input_types = split ',',$types_string;
        $tracking_cvterm_id = $tracking_tissue_culture_json_cvterm_id;
    }

    my $activity_info_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $tracking_cvterm_id});
    if ($activity_info_rs) {
        my $input;
        my $activity_json = $activity_info_rs->value();
        my $info = JSON::Any->jsonToObj($activity_json);
        my %info_hash = %{$info};
        foreach my $type (@input_types){
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
        foreach my $type (@input_types) {
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

    my $activity_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_type', 'project_property')->cvterm_id();
    my $activity_type_rs = $schema->resultset("Project::Projectprop")->find ({
        project_id => $project_id,
        type_id => $activity_type_cvterm_id
    });
    my $activity_type;
    if ($activity_type_rs) {
        $activity_type = $activity_type_rs->value();
    }

    my $types_string;
    my @input_types = ();
    if ($activity_type eq 'trial_treatments') {
        $types_string = $c->config->{tracking_trial_treatments};
        @input_types = split ',',$types_string;
    } else {
        $types_string = $c->config->{tracking_activities};
        @input_types = split ',',$types_string;
    }

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id, activity_type => $activity_type);
    my $all_identifier_info = $activity_project->get_project_active_identifiers();
    my @all_identifiers;
    foreach my $identifier_info (@$all_identifier_info) {
        my @row = ();
        my $identifier_id = $identifier_info->[0];
        my $identifier_name = $identifier_info->[1];
        my $material_id = $identifier_info->[2];
        my $material_name = $identifier_info->[3];
        push @row, qq{<a href="/activity/details/$identifier_id">$identifier_name</a>};

        if ($activity_type eq 'trial_treatments') {
            push @row, qq{<a href=\"/breeders_toolbox/trial/$material_id\">$material_name</a>};
        } else {
            push @row, qq{<a href="/stock/$material_id/view">$material_name</a>};
        }
        my $progress = $identifier_info->[4];
        my $input;
        if ($progress) {
            my $progress_ref = JSON::Any->jsonToObj($progress);
            my %progress_hash = %{$progress_ref};
            foreach my $type (@input_types){
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
            foreach my $type (@input_types) {
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

    my $activity_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_type', 'project_property')->cvterm_id();
    my $activity_type_rs = $schema->resultset("Project::Projectprop")->find ({
        project_id => $project_id,
        type_id => $activity_type_cvterm_id
    });
    my $activity_type;
    if ($activity_type_rs) {
        $activity_type = $activity_type_rs->value();
    }


    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id, activity_type => $activity_type);
    my $all_identifier_info = $activity_project->get_project_active_identifiers();
    my @identifier_names;
    foreach my $identifier_info (@$all_identifier_info) {
        push @identifier_names, $identifier_info->[1];
    }

    print STDERR "IDENTIFIER NAMES =".Dumper(\@identifier_names)."\n";

    $c->stash->{rest} = { data => \@identifier_names };

}


sub get_all_project_tracking_identifiers :Path('/ajax/tracking_activity/all_project_tracking_identifiers') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $project_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $activity_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_type', 'project_property')->cvterm_id();
    my $activity_type_rs = $schema->resultset("Project::Projectprop")->find ({
        project_id => $project_id,
        type_id => $activity_type_cvterm_id
    });
    my $activity_type;
    if ($activity_type_rs) {
        $activity_type = $activity_type_rs->value();
    }

    my $activity_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id, activity_type => $activity_type);
    my $all_identifier_info = $activity_project->get_project_active_identifiers();
    my @identifiers;
    foreach my $identifier_info (@$all_identifier_info) {
        push @identifiers, {
            identifier_stock_id => $identifier_info->[0],
            identifier_name => $identifier_info->[1]
        };
    }

    $c->stash->{rest} = { data => \@identifiers };

}


sub delete_identifier : Path('/ajax/tracking_activity/delete_identifier') : ActionClass('REST'){ }

sub delete_identifier_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to delete identifier." };
        return;
    }
    if (!($c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error => "You do not have sufficient privileges to delete tracking identifier." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $identifier_stock_id = $c->req->param("identifier_stock_id");
    my $tracking_identifier_obj = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier_stock_id);

    my $error = $tracking_identifier_obj->delete();
    if ($error) {
        $c->stash->{rest} = { error => "An error occurred attempting to delete the tracking identifier. ($@)" };
        return;
    }

    $c->stash->{rest} = { success => 1 };

}


sub delete_all_project_identifiers : Path('/ajax/tracking_activity/delete_all_project_identifiers') : ActionClass('REST'){ }

sub delete_all_project_identifiers_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to delete tracking identifiers." };
        return;
    }
    if (!($c->user()->has_role('curator'))) {
        $c->stash->{rest} = { error => "You do not have sufficient privileges to delete tracking identifiers." };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $project_id = $c->req->param("project_id");

    my $activity_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'activity_type', 'project_property')->cvterm_id();
    my $activity_type_rs = $schema->resultset("Project::Projectprop")->find ({
        project_id => $project_id,
        type_id => $activity_type_cvterm_id
    });
    my $activity_type;
    if ($activity_type_rs) {
        $activity_type = $activity_type_rs->value();
    }

    my $tracking_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $project_id, activity_type => $activity_type);
    my $all_identifiers = $tracking_project->get_project_active_identifiers();

    foreach my $identifier (@$all_identifiers){
        my $tracking_identifier_obj = CXGN::Stock::TrackingIdentifier->new(schema=>$schema, tracking_identifier_id=>$identifier->[0]);
        my $error = $tracking_identifier_obj->delete();
        if ($error) {
            $c->stash->{rest} = { error => "An error occurred attempting to delete the tracking identifier. ($@)" };
            return;
        }
    }

    $c->stash->{rest} = { success => 1 };

}



1;
