
package SGN::Controller::AJAX::VectorViewer;

use Moose;
use Data::Dumper;
use JSON::Any;
use SGN::Model::Cvterm;
use CXGN::VectorViewer;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

sub vector :Chained('/') PathPart('vectorviewer') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;
    print STDERR "VECTORVIEWER for $stock_id!\n";
    $c->stash->{vector_stock_id} = $stock_id;
}
    
sub store :Chained('vector') PathPart('store') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in with corresponding privileges to store vectors.' };
	return;
    }
    
    if ($c->user && ! $c->user->check_roles('curator')) {

	$c->stash->{rest} = { error => 'You do not have the privileges to store vectors.' };
	return;
    }
    
    my $data = $c->req->param('data');
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $vector_data_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vectorviewer_data', 'stock_property')->cvterm_id();
    my $vector_construct_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();
    
    my $vector_check_row = $schema->resultset("Stock::Stock")->find( { type_id => $vector_construct_cvterm_id, stock_id => $c->stash->{vector_stock_id} });
    
    if (!$vector_check_row) {
	$c->stash->{rest} = { error => 'The vector construct with id ".$c->stash->{vector_stock_id}." does not seem to exist' };
	return;
    }

    # maybe include a data check?

    my $new_data = {
	stock_id => $c->stash->{vector_stock_id},
	value_jsonb => $data,
	type_id => $vector_data_cvterm_id,	
    };

    my $row = $schema->resultset("Stock::Stockprop")->find_or_create(
	{
	    stock_id => $c->stash->{vector_stock_id},
	    type_id => $vector_data_cvterm_id,
	});

    my $old_data = {
	stock_id => $row->stock_id,
	value_jsonb => $row->value_jsonb,
	type_id => $row->type_id,
    };

    print STDERR "OLD DATA: ".Dumper($old_data);

    print STDERR "NEW DATA: ".Dumper($new_data);

    $row->update($new_data);

    $c->stash->{rest} = { success => 1 };    
}

sub retrieve :Chained('vector') PathPart('retrieve') Args(0) {
    my $self = shift;
    my $c = shift;
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $vector_data_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vectorviewer_data', 'stock_property')->cvterm_id();

    if (! $c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in to view vector data.' };
	return;
    }

    my $row = $schema->resultset("Stock::Stockprop")->find(
	{
	    stock_id => $c->stash->{vector_stock_id},
	    type_id => $vector_data_cvterm_id,
	});

    if (! defined($row)) {
	$c->stash->{rest} = { error => 'The vector information you are trying to access does not exist.' };
	return;
    }
    
    my $data = $row->value_jsonb();

    print STDERR "RETRIEVED DATA: $data\n";

    my $json_obj = JSON::Any->decode($data);

    $c->stash->{rest} = { data => $json_obj };
}

1;
