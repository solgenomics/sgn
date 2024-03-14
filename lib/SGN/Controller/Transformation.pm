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
    my $result = $transformation_obj->get_transformants();
    my $number_of_transformants = scalar(@$result);
    my $basename = $transformation_name.'_T';
    my $next_new_transformant = $basename. (sprintf "%04d", $number_of_transformants + 1);

    $c->stash->{transformation_id} = $transformation_id;
    $c->stash->{transformation_name} = $transformation_name;
    $c->stash->{next_new_transformant} = $next_new_transformant;
    $c->stash->{last_number} = $number_of_transformants;
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{template} = '/transformation/transformation.mas';

}


1;
