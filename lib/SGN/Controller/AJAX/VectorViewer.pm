
package SGN::Controller::AJAX::VectorViewer;

use Moose;
use Data::Dumper;
use File::Spec;
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

sub store :Chained('vector') PathPart('store') ActionClass('REST') {}

sub store_POST : Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
	
    if (! $c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in with corresponding privileges to store vectors.' };
	return;
    }
    
    if ($c->user && ! ($c->user->check_roles('submitter') || $c->user->check_roles('curator'))) {

	$c->stash->{rest} = { error => 'You do not have the privileges to store vectors.' };
	return;
    }
    
    my $data = $c->req->param('data');

    
    print STDERR "VECTOR DATA RECEIVED TO STORE: ".Dumper($data);
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

    print STDERR "RETRIEVING VECTOR... ".$c->stash->{vector_stock_id}."\n";
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
	
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $vector_data_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vectorviewer_data', 'stock_property')->cvterm_id();
    my $genbank_record_term = SGN::Model::Cvterm->get_cvterm_row($schema, 'GenbankRecord', 'stock_property');
    my $genbank_record_id;
    if ($genbank_record_term) {
	$genbank_record_id = $genbank_record_term->cvterm_id();
    }
    if (! $c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in to view vector data.' };
	return;
    }

    my $error;
    my $row = $schema->resultset("Stock::Stockprop")->find(
	{
	    stock_id => $c->stash->{vector_stock_id},
	    type_id => $vector_data_cvterm_id,
	});

    if (! defined($row)) {
	
	# there is no vectorviewer_data, let's check if a Genbank record was uploaded
	#
	print STDERR "NO vector data available, checking genbank record...\n";
	
	if ($genbank_record_id) {
	    
	    my $gb_row = $schema->resultset("Stock::Stockprop")->find(
		{
		    stock_id => $c->stash->{vector_stock_id},
		    type_id => $genbank_record_id,
		});

	    if ($gb_row) {

		print STDERR "Genkrecord found...\n";
		my $record = $gb_row->value();

		if (! $record) {
		    $error = "No vectorviewer data or genbank record.";
		}
		else {
		    print STDERR "Parsing genbank record ($record)...\n";
		    my $vv = CXGN::VectorViewer->new();
		    $vv->parse_genbank($record);

		    my $data =  { re_sites => $vv->re_sites(), features => $vv->features(), sequence => $vv->sequence(), metadata => $vv->metadata() };
		    
		    print STDERR "RETURN VALUE = ".Dumper($data);
		    
		    $c->stash->{rest} = $data;
		    return;
		}
		
	    }
	}

	print STDERR "No GenbankRecord stockprop found, trying uploaded files...\n";
	my $vector = CXGN::Stock->new( { schema => $schema, stock_id => $c->stash->{vector_stock_id} });

	my $file_data = $vector->get_additional_uploaded_files();

	print STDERR "FILEDATA = ".Dumper($file_data);
	my $files = $file_data->{files};
	
	foreach my $f (@$files) {
	    my ($file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype) = @$f;
	    print STDERR "FILE: ".Dumper($f);
	    
	    my $record = "";
	    if ($basename =~ /\.gb$/) {
		print STDERR "FOUND GENBANK RECORD FILE!\n";
		my $filename = File::Spec->catdir($dirname, $basename);
		open(my $F, "<", $filename) || die "Can't open file $filename for genbank data";

		
		while(<$F>) {
		    $record .= $_;
		}
	    }
	    
	    my $vv = CXGN::VectorViewer->new();
	    $vv->parse_genbank($record);
	    
	    my $data =  { re_sites => $vv->re_sites(), features => $vv->features(), sequence => $vv->sequence(), metadata => $vv->metadata() };
	    
	    print STDERR "RETURN VALUE = ".Dumper($data);
	    
	    $c->stash->{rest} = $data;
	    return;
	}
	
	$c->stash->{rest} = { error => 'The vector information you are trying to access does not exist.' };
	return;
    }
    
    my $data = $row->value_jsonb();

    print STDERR "RETRIEVED DATA: $data\n";

    my $json_obj = JSON::Any->decode($data);

    $c->stash->{rest} = $json_obj;
}


sub import :Chained('vector') PathPart('import') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    $c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    
    if (! $c->user()) {
	$c->stash->{rest} = { error => 'You need to be logged in to store vectors.' };
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    my $vector_construct_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();

    my $vector_check_row = $schema->resultset("Stock::Stock")->find( { type_id => $vector_construct_cvterm_id, stock_id => $c->stash->{vector_stock_id} });

    if (!$vector_check_row) {
	$c->stash->{rest} = { error => 'The vector construct with id ".$c->stash->{vector_stock_id}." does not seem to exist' };
	return;
    }

    my ($vv, $parsed, $sequence, $metadata, $re);

    if ($c->user && ($c->user->check_roles('curator') || $c->user->check_roles('submitter')) ) {  
	my $data = $c->req->param('data');
	my $format = $c->req->param('format');
	
	my $vector_data_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vectorviewer_data', 'stock_property')->cvterm_id();
	my $vector_construct_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();
	
	if (! $format || $format eq "genbank") { 
	    $vv = CXGN::VectorViewer->new();

	    $parsed = $vv->parse_genbank($data);
	    
	}
	else {
	    $c->stash->{rest} = { error => "Unknown data format for vector: $format" };
	    return;
	}
	
	#my $re = $vv->restriction_analysis($data);
	
	$c->stash->{rest} = { sequence => $sequence, re_sites => $vv->re_sites(), features => $parsed, metadata => $metadata };
    }
    else { $c->stash->{rest} = { error => "You do not have the privileges to import vector data." };
	   
    }
}

1;
