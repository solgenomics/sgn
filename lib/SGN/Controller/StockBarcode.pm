
package SGN::Controller::StockBarcode;

use Moose;

BEGIN { extends "Catalyst::Controller"; }

use ZPL;




sub download_zdl_barcodes { 
    my $self = shift;
    my $c = shift;

    #$c->schema('Stock::Stock')->
    



}

1;
