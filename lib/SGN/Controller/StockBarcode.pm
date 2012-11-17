
package SGN::Controller::StockBarcode;

use Moose;
use File::Slurp;
use Bio::Chado::Schema::Result::Stock::Stock;
use CXGN::Stock::StockBarcode;

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;


sub download_zdl_barcodes : Path('/barcode/stock/download') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $stock_names = $c->req->param("stock_names");
    my $stock_names_file = $c->req->upload("stock_names_file");

    my $complete_list = $stock_names ."\n".$stock_names_file;

    $complete_list =~ s/\r//g; 
    
    my @names = split /\n/, $complete_list;

    my @not_found;
    my @found;
    my @labels;

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    
    foreach my $name (@names) { 

	# skip empty lines
	#
	if (!$name) { 
	    next; 
	}

	my $stock = $schema->resultset("Stock::Stock")->find( { name=>$name });

	if (!$stock) { 
	    push @not_found, $name;
	    next;
	}

	my $stock_id = $stock->stock_id();

	push @found, $name;

	# generate new label
	#
	my $label = CXGN::ZPL->new();
	$label->start_format();
	$label->barcode_code128($c->config->{identifier_prefix}.$stock_id);
	$label->end_format();
	push @labels, $label;
    }


    ####$c->res->content_type("text/download");

    my $dir = $c->tempfiles_subdir('zpl');
    my ($FH, $filename) = $c->tempfile(TEMPLATE=>"zpl/zpl-XXXXX", UNLINK=>0);

    foreach my $label (@labels) { 
        print $FH $label->render();
    }
    close($FH);

    $c->stash->{not_found} = \@not_found;
    $c->stash->{found} = \@found;
    $c->stash->{zpl_file} = $filename;
    $c->stash->{template} = '/barcode/stock_download_result.mas';

}

sub upload_barcode_output : Path('/breeders/phenotype/upload') :Args(0) {
    my ($self, $c) = @_;
    my $upload = $c->req->upload('phenotype_file');
    my @contents = split /\n/, $upload->slurp;
    my $basename = $upload->basename;
    my $tempfile = $upload->tempname; #create a tempfile with the uploaded file
    if (! -e $tempfile) { 
        die "The file does not exist!\n\n";
    }
    my $archive_path = $c->config->{archive_path};

    $tempfile = $archive_path . "/" . $basename ;
    my $upload_err = $upload->copy_to($archive_path . "/" . $basename);

    my $sb = CXGN::Stock::StockBarcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};

    $sb->parse(\@contents, $identifier_prefix, $db_name);
    my $parse_errors = $sb->parse_errors;
    $sb->verify;
    my $verify_errors = $sb->verify_errors;
    my @errors = @$parse_errors, @$verify_errors;
    my $warnings = $sb->warnings;
    $c->stash->{tempfile} = $tempfile;
    $c->stash(
        template => '/stock/barcode/upload_confirm.mas',
        tempfile => $tempfile,
        errors   => \@errors,
        warnings => $warnings,
        feedback_email => $c->config->{feedback_email},
        );

}

sub store_barcode_output  : Path('/barcode/stock/store') :Args(0) {
    my ($self, $c) = @_;
    my $filename = $c->req->param('tempfile');
    
    my @contents = read_file($filename);

    my $sb = CXGN::Stock::StockBarcode->new( { schema=> $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado') });
    my $identifier_prefix = $c->config->{identifier_prefix};
    my $db_name = $c->config->{trait_ontology_db_name};
    $sb->parse(\@contents, $identifier_prefix, $db_name);
    my $error = $sb->store;

    $c->stash(
        template => '/stock/barcode/confirm_store.mas',
        error    => $error,
        );

}

###
1;#
###
