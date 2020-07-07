package CXGN::Pedigree::ParseUpload::Plugin::ValidateExistingProgeniesExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::RelatedStocks;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my @existing_pedigrees;
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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of progeny
        push @error_messages, "Spreadsheet is missing header or no progeny data";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $cross_name_head;
    my $progeny_name_head;

    if ($worksheet->get_cell(0,0)) {
        $cross_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $progeny_name_head  = $worksheet->get_cell(0,1)->value();
    }

    if (!$cross_name_head || $cross_name_head ne 'cross_unique_id' ) {
        push @error_messages, "Cell A1: cross_unique_id is missing from the header";
    }
    if (!$progeny_name_head || $progeny_name_head ne 'progeny_name') {
        push @error_messages, "Cell B1: progeny_name is missing from the header";
    }

    my %seen_cross_names;
    my %seen_progeny_names;

    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $cross_name;
        my $progeny_name;

        if ($worksheet->get_cell($row,0)) {
            $cross_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $progeny_name = $worksheet->get_cell($row,1)->value();
        }

        if (!$cross_name || $cross_name eq '') {
            push @error_messages, "Cell A$row_name: cross unique id missing";
        } else {
            $cross_name =~ s/^\s+|\s+$//g;
            $seen_cross_names{$cross_name}++;
        }

        if (!$progeny_name || $progeny_name eq '') {
            push @error_messages, "Cell B$row_name: progeny name missing";
        } else {
            $progeny_name =~ s/^\s+|\s+$//g;
            $seen_progeny_names{$progeny_name}++;
        }
    }

    my @crosses = keys %seen_cross_names;
    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',\@crosses)->{'missing'}};

    if (scalar(@crosses_missing) > 0){
        push @error_messages, "The following cross unique ids are not in the database as uniquenames or synonyms: ".join(',',@crosses_missing);
    }

    my @progenies = keys %seen_progeny_names;
    my $progeny_validator = CXGN::List::Validate->new();
    my @progenies_missing = @{$progeny_validator->validate($schema,'uniquenames',\@progenies)->{'missing'}};

    if (scalar(@progenies_missing) > 0) {
        push @error_messages, "The following progeny names are not in the database, or are not in the database as uniquenames: ".join(',',@progenies_missing);
        $errors{'missing_accessions'} = \@progenies_missing;
    }

    #check if progeny is already associated with cross_unique_id
    foreach my $progeny_name(@progenies) {
        my $cross_progeny_linkage = CXGN::Stock::RelatedStocks->get_cross_of_progeny($progeny_name, $schema);
        my @previous_cross = @$cross_progeny_linkage;
        if (scalar(@previous_cross) > 0) {
            push @error_messages, "The following progeny name is already associated with a cross unique id: ".$progeny_name;
            $errors{'existing_another_cross_linkage'} = $progeny_name;
        }
    }

    #check if progeny already has pedigree
    my %progenies_hash;
    my @progeny_stock_ids;
    my %return;
    foreach my $progeny_name(@progenies) {
        my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
        $stock_lookup->set_stock_name($progeny_name);
        my $progeny_stock = $stock_lookup->get_stock_exact();
        my $progeny_stock_id = $progeny_stock->stock_id();
        push @progeny_stock_ids, $progeny_stock_id;
        $progenies_hash{$progeny_stock_id} = $progeny_name;
    }
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id;;
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id;;

    my $progeny_female_parent_search = $schema->resultset('Stock::StockRelationship')->search({
        type_id => $female_parent_cvterm_id,
        object_id => { '-in'=>\@progeny_stock_ids },
    });
    my %progeny_with_female_parent_already;
    while (my $r=$progeny_female_parent_search->next){
        $progeny_with_female_parent_already{$r->object_id} = [$r->subject_id, $r->value];
    }
    my $progeny_male_parent_search = $schema->resultset('Stock::StockRelationship')->search({
        type_id => $male_parent_cvterm_id,
        object_id => { '-in'=>\@progeny_stock_ids },
    });
    my %progeny_with_male_parent_already;
    while (my $r=$progeny_male_parent_search->next){
        $progeny_with_male_parent_already{$r->object_id} = $r->subject_id;
    }

        foreach (@progeny_stock_ids){
            if (exists($progeny_with_female_parent_already{$_})){
                push @existing_pedigrees, $progenies_hash{$_}." already has female parent stockID ".$progeny_with_female_parent_already{$_}->[0]." saved with cross type ".$progeny_with_female_parent_already{$_}->[1];
            }
            if (exists($progeny_with_male_parent_already{$_})){
                push @existing_pedigrees, $progenies_hash{$_}." already has male parent stockID ".$progeny_with_male_parent_already{$_};
            }
        }

    #store any errors found in the parsed file to parse_errors accessor
        $errors{'error_messages'} = \@error_messages;
        $errors{'existing_pedigrees'} = \@existing_pedigrees;
        $self->_set_parse_errors(\%errors);
        return;

}

1;
