package SGN::Controller::Transformation;

use Moose;
use URI::FromHash 'uri';
use SGN::Model::Cvterm;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Transformation::Transformation;

BEGIN { extends 'Catalyst::Controller'; }


sub transformation_page : Path('/transformation') Args(1) {
    my $self = shift;
    my $c = shift;
    my $id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;
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
    my $plant_material = qq{<a href="/stock/$info->[0]->[0]/view">$info->[0]->[1]</a>};
    my $vector_construct = qq{<a href="/stock/$info->[0]->[2]/view">$info->[0]->[3]</a>};
    my $transformation_notes = $info->[0]->[4];
    my $result = $transformation_obj->get_transformants();
    my $number_of_transformants = scalar(@$result);
    my $basename = $transformation_name.'_T';
    my $next_new_transformant = $basename. (sprintf "%04d", $number_of_transformants + 1);

    my $updated_status_type = $info->[0]->[5];
    my $completed_metadata;
    my $terminated_metadata;
    if ($updated_status_type eq 'terminated_metadata') {
        $updated_status_type = '<span style="color:red">'.'TERMINATED'.'</span>';
        $terminated_metadata = 1;
    } elsif ($updated_status_type eq 'completed_metadata') {
        $updated_status_type = '<span style="color:red">'.'COMPLETED'.'</span>';
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

    $c->stash->{transformation_id} = $transformation_id;
    $c->stash->{transformation_name} = $transformation_name;
    $c->stash->{next_new_transformant} = $next_new_transformant;
    $c->stash->{last_number} = $number_of_transformants;
    $c->stash->{plant_material} = $plant_material;
    $c->stash->{vector_construct} = $vector_construct;
    $c->stash->{transformation_notes} = $transformation_notes;
    $c->stash->{updated_status_type} = $updated_status_type;
    $c->stash->{updated_status_string} = $updated_status_string;
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{template} = '/transformation/transformation.mas';

}


1;
