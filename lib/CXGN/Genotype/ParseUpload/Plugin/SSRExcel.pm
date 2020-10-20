package CXGN::Genotype::ParseUpload::Plugin::SSRExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my %errors;
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0]; #support only one worksheet
    if (!$worksheet){
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 4 ) { #must have header and at least one row of progeny
        push @error_messages, "Spreadsheet is missing header or no progeny data";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $sample_name_head;

    if ($worksheet->get_cell(4,0)) {
        $sample_name_head  = $worksheet->get_cell(4,0)->value();
    }

    if (!$sample_name_head || $sample_name_head ne 'sample_name' ) {
        push @error_messages, "Cell A4:sample_name is missing from the header";
    }

    my %seen_sample_names;

    for my $row (5 .. $row_max){
        my $row_name = $row+1;
        my sample_name;

        if ($worksheet->get_cell($row,0)) {
            $sample_name = $worksheet->get_cell($row,0)->value();
        }

        if (!$sample_name || $sample_name eq '') {
            push @error_messages, "Cell A$row_name: sample name missing";
        } else {
            $sample_name =~ s/^\s+|\s+$//g;
            $seen_sample_names{$sample_name}++;
        }

    }

    my @samples = keys %seen_sample_names;
    my $sample_validator = CXGN::List::Validate->new();
    my @samples_missing = @{sample_validator->validate($schema,'accessions',\@samples)->{'missing'}};

    if (scalar(@samples_missing) > 0){
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@samples_missing);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed

}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    my %sample_marker_hash;

    for my $row (5 .. $row_max){
        my $sample_name;

        if ($worksheet->get_cell($row,0)){
            $sample_name = $worksheet->get_cell($row,0)->value();
            $sample_name =~ s/^\s+|\s+$//g;
        }

        for my $column (1 .. $col_max ){
            if ($worksheet->get_cell($row,$column)) {



            }
        }
    }




    $self->_set_parsed_data(   );
    return 1;
}

1;
