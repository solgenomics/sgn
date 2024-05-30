package CXGN::Pedigree::ParseUpload::Plugin::PedigreesExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

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
    my @pedigrees;
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $progeny_name;
        my $female_parent;
        my $male_parent;
        my $type;
        my $female_parent_individual;
        my $male_parent_individual;

        if ($worksheet->get_cell($row,0)) {
            $progeny_name = $worksheet->get_cell($row,0)->value();
            $progeny_name =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)) {
            $female_parent =  $worksheet->get_cell($row,1)->value();
            $female_parent =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,2)) {
            $male_parent = $worksheet->get_cell($row,2)->value();
            $male_parent =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,3)) {
            $type =  $worksheet->get_cell($row,3)->value();
            $type =~ s/^\s+|\s+$//g;
        }

        if (!defined $progeny_name && !defined $female_parent && !defined $type) {
            last;
        }

        if ($female_parent) {
            $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
        }
        if ($male_parent) {
            $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
        }

        my $pedigree_info = {
            cross_type => $type,
            female_parent => $female_parent_individual,
            name => $progeny_name,
        };

        if ($male_parent) {
            $pedigree_info->{male_parent} = $male_parent_individual;
        }

        my $pedigree = Bio::GeneticRelationships::Pedigree->new($pedigree_info);
        push @pedigrees, $pedigree;
    }

    $parsed_result{'pedigrees'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
