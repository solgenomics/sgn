package SGN::Controller::Transformation;

use Moose;
use URI::FromHash 'uri';
use SGN::Model::Cvterm;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Transformation::Transformation;
use JSON;

BEGIN { extends 'Catalyst::Controller'; }


sub transformation_page : Path('/transformation') Args(1) {
    my $self = shift;
    my $c = shift;
    my $id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;
    my $user_role;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user() && $c->user()->check_roles("curator")) {
        $user_role = "curator";
    }

    my $transformation_stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation', 'stock_type')->cvterm_id();

    my $transformation = $schema->resultset("Stock::Stock")->find( { stock_id => $id, type_id => $transformation_stock_type_id } );

    my $transformation_id;
    my $transformation_name;
	if (!$transformation) {
    	$c->stash->{template} = '/generic_message.mas';
    	$c->stash->{message} = 'The requested transformation does not exist.';
    	return;
    } else {
        $transformation_id = $transformation->stock_id();
        $transformation_name = $transformation->uniquename();
    }

    my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation_id});
    my $info = $transformation_obj->get_transformation_info();
    my $transformants = $transformation_obj->transformants();
    my $number_of_transformants = scalar(@$transformants);
    my $obsoleted_transformants = $transformation_obj->obsoleted_transformants();
    my $number_of_obsoleted_transformants = scalar(@$obsoleted_transformants);
    my $has_associated_transformants;
    if (($number_of_transformants > 0) || ($number_of_obsoleted_transformants > 0)) {
        $has_associated_transformants = 1;
    }

    my $plant_material_id = $info->[0]->[0];
    my $plant_material_name = $info->[0]->[1];
    my $vector_id = $info->[0]->[2];
    my $vector_name = $info->[0]->[3];
    my $plant_material = qq{<a href="/stock/$plant_material_id/view">$plant_material_name</a>};
    my $vector_construct = qq{<a href="/stock/$vector_id/view">$vector_name</a>};
    my $transformation_notes = $info->[0]->[4];

    my $is_a_control = $info->[0]->[5];
    if ($is_a_control) {
        $is_a_control = 'is a control';
    }

    my $control_id = $info->[0]->[6];
    my $control_name = $info->[0]->[7];
    my $control_link;
    if ($control_id) {
        $control_link = qq{<a href="/transformation/$control_id">$control_name</a>}
    }

    my $updated_status_type = $info->[0]->[8];
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

    my $updated_status_string;
    if ($updated_status_type) {
        my $updated_status = CXGN::Stock::Status->new({ bcs_schema => $schema, parent_id => $transformation_id, completed_metadata => $completed_metadata, terminated_metadata => $terminated_metadata});
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

    my $project_info = $transformation_obj->get_associated_projects();
    my $project_id = $project_info->[0]->[0];
    my $project_name = $project_info->[0]->[1];
    my $program_id = $project_info->[0]->[2];
    my $program_name = $project_info->[0]->[3];
    my $project_link = qq{<a href="/breeders/trial/$project_id">$project_name</a>};

    my $transformation_project = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, project_id=>$project_id});
    my $name_format = $transformation_project->get_autogenerated_name_format();

    my $identifier_link;
    my $identifier_id;
    my $identifier_name;
    my $tracking_transformation = $c->config->{tracking_transformation};
    if ($tracking_transformation) {
        my $tracking_info = $transformation_obj->tracking_identifier();
        $identifier_id = $tracking_info->[0]->[0];
        $identifier_name = $tracking_info->[0]->[1];
        $identifier_link = qq{<a href="/activity/details/$identifier_id">$identifier_name</a>};
    } else {
        $identifier_id = 'NA';
        $identifier_name = 'NA';
    }

    my $source_info_hash = {};
    $source_info_hash->{'breedingProgram'} = $program_name;
    $source_info_hash->{'transformationProject'} = $project_name;
    $source_info_hash->{'transformationID'} = $transformation_name;
    $source_info_hash->{'vectorConstruct'} = $vector_name;
    $source_info_hash->{'plantMaterial'} = $plant_material_name;
    my $source_info_string = encode_json $source_info_hash;

    $c->stash->{transformation_id} = $transformation_id;
    $c->stash->{transformation_name} = $transformation_name;
    $c->stash->{plant_material} = $plant_material;
    $c->stash->{vector_construct} = $vector_construct;
    $c->stash->{transformation_notes} = $transformation_notes;
    $c->stash->{updated_status_type} = $updated_status_type;
    $c->stash->{updated_status_string} = $updated_status_string;
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{user_role} = $user_role;
    $c->stash->{identifier_link} = $identifier_link;
    $c->stash->{project_link} = $project_link;
    $c->stash->{program_id} = $program_id;
    $c->stash->{program_name} = $program_name;
    $c->stash->{name_format} = $name_format;
    $c->stash->{source_info} = $source_info_string;
    $c->stash->{stock_type_page} = 'transformation_id';
    $c->stash->{identifier_id} = $identifier_id;
    $c->stash->{identifier_name} = $identifier_name;
    $c->stash->{material_id} = $transformation_id;
    $c->stash->{material_name} = $transformation_name;
    $c->stash->{status_display} = $status_display;
    $c->stash->{has_associated_transformants} = $has_associated_transformants;
    $c->stash->{project_id} = $project_id;
    $c->stash->{is_a_control} = $is_a_control;
    $c->stash->{control_name} = $control_name;
    $c->stash->{control_id} = $control_id;            
    $c->stash->{control_link} = $control_link;

    $c->stash->{template} = '/transformation/transformation.mas';

}


1;
