package CXGN::Trial::ParseUpload::Plugin::ProfileXLS;

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
    my $parser = Spreadsheet::ParseExcel->new();
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
    if (($col_max - $col_min)  < 5 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of info
        push @error_messages, "Spreadsheet is missing header or no profile info";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $trait_name_header;
    my $target_value_header;
    my $benchmark_variety_header;
    my $performance_header;
    my $weight_header;
    my $trait_type_header;

    if ($worksheet->get_cell(0,0)) {
        $trait_name_header  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $target_value_header  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $benchmark_variety_header  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $performance_header  = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $weight_header  = $worksheet->get_cell(0,4)->value();
    }
    if ($worksheet->get_cell(0,5)) {
        $trait_type_header  = $worksheet->get_cell(0,5)->value();
    }

    if (!$trait_name_header || $trait_name_header ne 'Trait Name' ) {
        push @error_messages, "Cell A1: Trait Name is missing from the header";
    }
    if (!$target_value_header || $target_value_header ne 'Target Value') {
        push @error_messages, "Cell B1: Target Value is missing from the header";
    }
    if (!$benchmark_variety_header || $benchmark_variety_header ne 'Benchmark Variety') {
        push @error_messages, "Cell C1: Benchmark Variety is missing from the header";
    }
    if (!$performance_header || $performance_header ne 'Performance (equal, smaller, larger)') {
        push @error_messages, "Cell D1: Performance is missing from the header";
    }
    if (!$weight_header || $weight_header ne 'Weight') {
        push @error_messages, "Cell E1: Weight is missing from the header";
    }
    if (!$trait_type_header || $trait_type_header ne 'Trait Type') {
        push @error_messages, "Cell F1: Trait Type is missing from the header";
    }

    my %seen_trait_names;
    my %seen_accession_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $trait_name;
        my $target_value;
        my $benchmark_variety;
        my $performance;
        my $weight;
        my $trait_type;


        if ($worksheet->get_cell($row,0)) {
            $trait_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $target_value =  $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $benchmark_variety = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $performance =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $trait_type =  $worksheet->get_cell($row,5)->value();
        }

        if (!$trait_name || $trait_name eq '') {
            push @error_messages, "Cell A$row_name: Trait name missing";
        }

        if ((!$target_value || $target_value eq '') && (!$benchmark_variety || $benchmark_variety eq '')) {
            push @error_messages, "Cell B$row_name or C$row_name: You must indicate either Target Value or Benchmark Variety";
        }

        if (defined $target_value && defined $benchmark_variety) {
            push @error_messages, "Cell B$row_name or C$row_name: You must indicate either Target Value or Benchmark Variety, not both";
        }

        if (!$performance || $performance eq '') {
            push @error_messages, "Cell D$row_name: Performance parameter missing";
        }

        if ($trait_name){
            $trait_name =~ s/^\s+|\s+$//g;
            $seen_trait_names{$trait_name}++;
        }

        if ($benchmark_variety){
            $benchmark_variety =~ s/^\s+|\s+$//g;
            $seen_accession_names{$benchmark_variety}++;
        }

    }

    my @traits = keys %seen_trait_names;
    my $trait_validator = CXGN::List::Validate->new();
    my @traits_missing = @{$trait_validator->validate($schema,'traits',\@traits)->{'missing'}};

    if (scalar(@traits_missing) > 0){
        push @error_messages, "The following Traits are not in the database: ".join(',',@traits_missing);
        $errors{'missing_traits'} = \@traits_missing;
    }

    my @accession_names = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accession_names_missing = @{$accession_validator->validate($schema,'accessions',\@accession_names)->{'missing'}};

#    if (scalar(@accession_names_missing) > 0){
#        push @error_messages, "The following benchmark varieties are not in the database: ".join(',',@accession_names_missing);
#        $errors{'missing_accessions'} = \@accession_names_missing;
#    }

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
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $trait_name;
        my $target_value;
        my $benchmark_variety;
        my $performance;
        my $weight;
        my $trait_type;


        if ($worksheet->get_cell($row,0)) {
            $trait_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $target_value =  $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $benchmark_variety = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $performance =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
        } else {
            $weight = 1;
        }

        if ($worksheet->get_cell($row,5)) {
            $trait_type =  $worksheet->get_cell($row,5)->value();
        }

        $parsed_result{$trait_name} = {
            'target_value' => $target_value,
            'benchmark_variety' => $benchmark_variety,
            'performance' => $performance,
            'weight' => $weight,
            'trait_type' => $trait_type
        }
    }
#    print STDERR "PARSED RESULT =".Dumper(%parsed_result)."\n";

    $self->_set_parsed_data(\%parsed_result);

    return 1;
}

1;
