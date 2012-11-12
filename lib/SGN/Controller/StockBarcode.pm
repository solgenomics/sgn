
package SGN::Controller::StockBarcode;

use Moose;
use CXGN::Stock::StockBarcode;

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;


sub download_zdl_barcodes {
    my $self = shift;
    my $c = shift;

    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");

    my $complete_list = $stock_names ."\n".$stock_names_file;

    
    my @names = split /\n/, $complete_list;

    my @non_existent;
    my @labels;

    foreach my $name (@names) { 

	if (!$name) { 
	    next; 
	}

	my $stock = $c->dbic_schema('Stock::Stock')->find( { name=>$name });
	my $stock_id = $stock->stock_id();

	if (!$stock_id) { 
	    push @non_existent, $name;
	}

	# generate new label
	#
	my $label = CXGN::ZPL->new();
	$label->start_format();
	$label->barcode_code128($c->config->{identifier_prefix}.$stock_id);
	$label->end_format();
	push @labels, $label;
    }

    foreach my $label (@labels) { 
	print $label->render();
    }
	
	

}

sub upload_barcode_output {
    my ($self, $c) = shift;
    my $upload = $c->req->upload('phenotype_file');
    my $contents = $upload->slurp;
    my $tempfile = $upload->tempname; #create a tempfile with the uploaded file
    my $sb = CXGN::Stock::Barcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse($contents, $identifier_prefix, $db_name);
    my @errors = $sb->verify;

    $c->{template} = '/stock/barcode/upload_confirm.mas';
    $c->{tempfile} = $tempfile;
    $c->{errors} = \@errors;


}

sub store_barcode_output {
    my ($self, $c) = shift;
    my $contents = $c->req->param('tempfile');

    my $sb = CXGN::Stock::Barcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse($contents, $identifier_prefix, $db_name);
    $sb->store;

    $c->{template} = '/stock/barcode/confirm_store.mas';

}

###
1;#
###
