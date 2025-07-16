
package SGN::Controller::ActivityInfo;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;
use CXGN::TrackingActivity::TrackingIdentifier;
use CXGN::Stock::Status;
use CXGN::People::Person;
use CXGN::Transformation::Transformation;
use JSON;

BEGIN { extends 'Catalyst::Controller'; }

sub activity_details :Path('/activity/details') : Args(1) {
    my $self = shift;
    my $c = shift;
    my $identifier_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;
    my $user_role;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user() && $c->user()->check_roles("curator")) {
        $user_role = "curator";
    }

    my $tracking_identifier_obj = CXGN::TrackingActivity::TrackingIdentifier->new({schema=>$schema, dbh=>$dbh, tracking_identifier_stock_id=>$identifier_id});
    my $tracking_info = $tracking_identifier_obj->get_tracking_identifier_info();

    my $identifier_name = $tracking_info->[0]->[1];
    my $material_id = $tracking_info->[0]->[2];
    my $material_name = $tracking_info->[0]->[3];
    my $material_type = $tracking_info->[0]->[4];

    my $updated_status_type = $tracking_info->[0]->[7];
    my $completed_metadata;
    my $terminated_metadata;
    my $status_display;
    if ($updated_status_type eq 'terminated_metadata') {
        $status_display = '<span style="color:red">'.'TERMINATED'.'</span>';
        $terminated_metadata = 1;
    } elsif ($updated_status_type eq 'completed_metadata') {
        $status_display = '<span style="color:red">'.'COMPLETED'.'</span>';
        $completed_metadata = 1;
    }

    my $associated_projects = $tracking_identifier_obj->get_associated_project_program();
    my $tracking_project_id = $associated_projects->[0]->[0];
    my $program_name = $associated_projects->[0]->[3];
    my $tracking_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $tracking_project_id);
    my $activity_type = $tracking_project->get_project_activity_type();

    my $types;
    my $activity_type_header;
    if ($activity_type eq 'tissue_culture') {
        $types = $c->config->{tracking_tissue_culture_info};
        $activity_type_header = $c->config->{tracking_tissue_culture_info_header};
    } elsif ($activity_type eq 'transformation') {
        $types = $c->config->{tracking_transformation_info};
        $activity_type_header = $c->config->{tracking_transformation_info_header};
    }

    my @type_select_options = split ',',$types;
    my @activity_headers = split ',',$activity_type_header;

    my @options = ();
    for my $i (0 .. $#type_select_options) {
        push @options, [$type_select_options[$i], $activity_headers[$i]];
    }

    my $updated_status_string;
    if ($updated_status_type) {
        my $updated_status = CXGN::Stock::Status->new({ bcs_schema => $schema, parent_id => $identifier_id, completed_metadata => $completed_metadata, terminated_metadata => $terminated_metadata});
        my $updated_status_info = $updated_status->get_status_details();
        my $person_id = $updated_status_info->[0];
        my $person= CXGN::People::Person->new($dbh, $person_id);
        my $person_name=$person->get_first_name()." ".$person->get_last_name();
        my $operator_info = "Updated by". ":"."".$person_name;
        my $date_info = "Updated Date". ":"."".$updated_status_info->[1];
        my $reason_info = "Comments". ":"."".$updated_status_info->[2];
        my @all_info = ($operator_info, $date_info, $reason_info);
        my $all_info_string = join("<br>", @all_info);
        $updated_status_string = '<span style="color:red">'.$all_info_string.'</span>';
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $date = $time->ymd();

    my $source_info_string;
    if ($material_type eq 'transformation') {
        my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$material_id});
        my $info = $transformation_obj->get_transformation_info();
        my $plant_material_name = $info->[0]->[1];
        my $vector_name = $info->[0]->[3];
        my $transformation_project_name = $associated_projects->[0]->[5];
        my $source_info_hash = {};
        $source_info_hash->{'breedingProgram'} = $program_name;
        $source_info_hash->{'transformationProject'} = $transformation_project_name;
        $source_info_hash->{'transformationID'} = $material_name;
        $source_info_hash->{'vectorConstruct'} = $vector_name;
        $source_info_hash->{'plantMaterial'} = $plant_material_name;
        $source_info_string = encode_json $source_info_hash;
    }

    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{identifier_name} = $identifier_name;
    $c->stash->{type_select_options} = \@options;
    $c->stash->{activity_headers} = \@activity_headers;
    $c->stash->{material_name} = $material_name;
    $c->stash->{material_id} = $material_id;
    $c->stash->{material_type} = $material_type;
    $c->stash->{updated_status_type} = $updated_status_type;
    $c->stash->{updated_status_string} = $updated_status_string;
    $c->stash->{status_display} = $status_display;
    $c->stash->{timestamp} = $timestamp;
    $c->stash->{date} = $date;
    $c->stash->{user_role} = $user_role;
    $c->stash->{project_id} = $tracking_project_id;
    $c->stash->{activity_type} = $activity_type;
    $c->stash->{program_name} = $program_name;
    $c->stash->{source_info} = $source_info_string;
    $c->stash->{stock_type_page} = 'tracking_id';    
    $c->stash->{template} = '/tracking_activities/activity_info_details.mas';

}


sub record_activity :Path('/activity/record') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my $identifier_name = $c->req->param("identifier_name");

    if (! $c->user()) {
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    my $identifier_id;
    my @options = ();
    my @activity_headers = ();
    my $material_stock_id;
    my $material_name;
    my $material_type;
    my $tracking_project_id;
    my $activity_type;
    my $program_name;
    my $source_info_string;

    if ($identifier_name) {
        my $identifier_rs = $schema->resultset("Stock::Stock")->find({uniquename => $identifier_name});
        if (!$identifier_rs) {
            $c->stash->{message} = "The tracking identifier does not exist or has been deleted.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        } else {
            $identifier_id = $identifier_rs->stock_id();
        }

        my $tracking_identifier_obj = CXGN::TrackingActivity::TrackingIdentifier->new({schema=>$schema, dbh=>$dbh, tracking_identifier_stock_id=>$identifier_id});
        my $associated_projects = $tracking_identifier_obj->get_associated_project_program();
        $program_name = $associated_projects->[0]->[3];
        my $material_info = $tracking_identifier_obj->get_tracking_identifier_info();
        $material_stock_id = $material_info->[0]->[2];
        $material_name = $material_info->[0]->[3];
        $material_type = $material_info->[0]->[4];

        if ($material_type eq 'transformation') {
            my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$material_stock_id});
            my $info = $transformation_obj->get_transformation_info();
            my $plant_material_name = $info->[0]->[1];
            my $vector_name = $info->[0]->[3];
            my $transformation_project_name = $associated_projects->[0]->[5];
            my $source_info_hash = {};
            $source_info_hash->{'breedingProgram'} = $program_name;
            $source_info_hash->{'transformationProject'} = $transformation_project_name;
            $source_info_hash->{'transformationID'} = $material_name;
            $source_info_hash->{'vectorConstruct'} = $vector_name;
            $source_info_hash->{'plantMaterial'} = $plant_material_name;
            $source_info_string = encode_json $source_info_hash;
        }

        $tracking_project_id = $associated_projects->[0]->[0];
        my $tracking_project = CXGN::TrackingActivity::ActivityProject->new(bcs_schema => $schema, trial_id => $tracking_project_id);
        $activity_type = $tracking_project->get_project_activity_type();

        my $types;
        my $activity_type_header;
        if ($activity_type eq 'tissue_culture') {
            $types = $c->config->{tracking_tissue_culture_info};
            $activity_type_header = $c->config->{tracking_tissue_culture_info_header};
        } elsif ($activity_type eq 'transformation') {
            $types = $c->config->{tracking_transformation_info};
            $activity_type_header = $c->config->{tracking_transformation_info_header};
        }

        my @type_select_options = split ',',$types;
        @activity_headers = split ',',$activity_type_header;

        for my $i (0 .. $#type_select_options) {
            push @options, [$type_select_options[$i], $activity_headers[$i]];
        }
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $date = $time->ymd();

    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{type_select_options} = \@options;
    $c->stash->{activity_headers} = \@activity_headers;
    $c->stash->{material_stock_id} = $material_stock_id;
    $c->stash->{material_name} = $material_name;
    $c->stash->{material_type} = $material_type;
    $c->stash->{timestamp} = $timestamp;
    $c->stash->{date} = $date;
    $c->stash->{project_id} = $tracking_project_id;
    $c->stash->{activity_type} = $activity_type;
    $c->stash->{program_name} = $program_name;
    $c->stash->{source_info} = $source_info_string;
    $c->stash->{template} = '/tracking_activities/record_activity.mas';

}



1;
