
package SGN::Controller::StockBarcode;

use Moose;
use CXGN::Stock::StockBarcode;

BEGIN { extends "Catalyst::Controller"; }

use CXGN::ZPL;


sub download_zdl_barcodes {
    my $self = shift;
    my $c = shift;

    #$c->schema('Stock::Stock')->

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
