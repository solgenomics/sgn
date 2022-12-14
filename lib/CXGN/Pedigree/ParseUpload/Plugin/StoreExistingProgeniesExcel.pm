package CXGN::Pedigree::ParseUpload::Plugin::StoreExistingProgeniesExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::RelatedStocks;


sub _validate_with_plugin {
    return 1; #storing after validation plugin
}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    my %cross_progenies_hash;

    for my $row (1 .. $row_max){
        my $cross_name;
        my $progeny_name;

        if ($worksheet->get_cell($row,0)){
            $cross_name = $worksheet->get_cell($row,0)->value();
            $cross_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)){
            $progeny_name = $worksheet->get_cell($row,1)->value();
            $progeny_name =~ s/^\s+|\s+$//g;
        }
        #skip blank lines or lines with no name, type and parent
        if (!$cross_name && !$progeny_name) {
            next;
        }

        push @{$cross_progenies_hash{$cross_name}}, $progeny_name;
    }
    $self->_set_parsed_data(\%cross_progenies_hash);
    return 1;
}

1;
