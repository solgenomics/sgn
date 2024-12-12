package CXGN::Pedigree::ParseUpload::Plugin::CrossesSimplifiedParentInfoExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

# DEPRECATED: This plugin has been replaced by the CrossesGeneric plugin

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $cross_additional_info = $self->get_cross_additional_info();
    my @error_messages;
    my %errors;
    my %supported_cross_types;

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

    #currently supported cross types
    $supported_cross_types{'biparental'} = 1; #both parents required
    $supported_cross_types{'self'} = 1; #only female parent required
    $supported_cross_types{'open'} = 1; #only female parent required
    $supported_cross_types{'sib'} = 1; #both parents required but can be the same.
    $supported_cross_types{'bulk_self'} = 1; #only female population required
    $supported_cross_types{'bulk_open'} = 1; #only female population required
    $supported_cross_types{'bulk'} = 1; #both female population and male accession required
    $supported_cross_types{'doubled_haploid'} = 1; #only female parent required
    $supported_cross_types{'dihaploid_induction'} = 1; # ditto
    $supported_cross_types{'polycross'} = 1; #both parents required
    $supported_cross_types{'backcross'} = 1; #both parents required, parents can be cross or accession stock type

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        push @error_messages,  $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 4 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of crosses
        push @error_messages, "Spreadsheet is missing header or contains no row";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $cross_name_head;
    my $cross_combination_head;
    my $cross_type_head;
    my $female_parent_head;
    my $male_parent_head;

    if ($worksheet->get_cell(0,0)) {
        $cross_name_head  = $worksheet->get_cell(0,0)->value();
        $cross_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $cross_combination_head  = $worksheet->get_cell(0,1)->value();
        $cross_combination_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $cross_type_head  = $worksheet->get_cell(0,2)->value();
        $cross_type_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $female_parent_head  = $worksheet->get_cell(0,3)->value();
        $female_parent_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $male_parent_head  = $worksheet->get_cell(0,4)->value();
        $male_parent_head =~ s/^\s+|\s+$//g;
    }


    if (!$cross_name_head || $cross_name_head ne 'cross_unique_id' ) {
        push @error_messages, "Cell A1: cross_unique_id is missing from the header";
    }
    if (!$cross_combination_head || $cross_combination_head ne 'cross_combination') {
        push @error_messages, "Cell B1: cross_combination is missing from the header";
    }
    if (!$cross_type_head || $cross_type_head ne 'cross_type') {
        push @error_messages, "Cell C1: cross_type is missing from the header";
    }
    if (!$female_parent_head || $female_parent_head ne 'female_parent') {
        push @error_messages, "Cell D1: female_parent is missing from the header";
    }
    if (!$male_parent_head || $male_parent_head ne 'male_parent') {
        push @error_messages, "Cell E1: male_parent is missing from the header";
    }

    my %valid_additional_info;
    my @valid_info = @{$cross_additional_info};
    foreach my $info(@valid_info){
        $valid_additional_info{$info} = 1;
    }

    for my $column (5 .. $col_max){
        if ($worksheet->get_cell(0, $column)) {
            my $header_string = $worksheet->get_cell(0,$column)->value();
            $header_string =~ s/^\s+|\s+$//g;

            if (($header_string) && (!$valid_additional_info{$header_string})){
                push @error_messages, "Invalid info type: $header_string";
            }
        }
    }

    my %seen_cross_names;
    my %seen_parent_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $cross_name;
        my $cross_combination;
        my $cross_type;
        my $female_parent;
        my $male_parent;

        if ($worksheet->get_cell($row,0)) {
            $cross_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $cross_combination =  $worksheet->get_cell($row,1)->value();
            $cross_combination =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $cross_type = $worksheet->get_cell($row,2)->value();
            $cross_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $female_parent =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $male_parent =  $worksheet->get_cell($row,4)->value();
        }

        if (!defined $cross_name && !defined $cross_type && !defined $female_parent) {
            last;
        }

        #cross name must not be blank
        if (!$cross_name || $cross_name eq '') {
            push @error_messages, "Cell A$row_name: cross unique id missing";
        } else {
            $cross_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end.
        }
#        } elsif ($cross_name =~ /\s/ || $cross_name =~ /\// || $cross_name =~ /\\/ ) {
#            push @error_messages, "Cell A$row_name: cross_name must not contain spaces or slashes.";
        if ($seen_cross_names{$cross_name}) {
            push @error_messages, "Cell A$row_name: duplicate cross unique id: $cross_name";
        }

        #cross type must not be blank
        if (!$cross_type || $cross_type eq '') {
            push @error_messages, "Cell C$row_name: cross type missing";
        } elsif (!$supported_cross_types{$cross_type}){
            push @error_messages, "Cell C$row_name: cross type not supported: $cross_type";
        }

        #female parent must not be blank
        if (!$female_parent || $female_parent eq '') {
            push @error_messages, "Cell D$row_name: female parent missing";
        }

        #male parent must not be blank if type is biparental, sib, polycross or bulk
        if (!$male_parent || $male_parent eq '') {
            if ($cross_type eq ( 'biparental' || 'bulk' || 'sib' || 'polycross' || 'backcross' )) {
                push @error_messages, "Cell E$row_name: male parent required for biparental, sib, polycross, backcross and bulk cross types";
            }
        }

        if ($cross_name){
            $cross_name =~ s/^\s+|\s+$//g;
            $seen_cross_names{$cross_name}++;
        }

        if ($female_parent) {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_parent_names{$female_parent}++;
        }

        if ($male_parent){
            $male_parent =~ s/^\s+|\s+$//g;
            $seen_parent_names{$male_parent}++;
        }
    }

    my @parent_list = keys %seen_parent_names;
    my $parent_validator = CXGN::List::Validate->new();

    my @parents_missing = @{$parent_validator->validate($schema,'accessions_or_populations_or_plots_or_plants',\@parent_list)->{'missing'}};

    if (scalar(@parents_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as accession names, plot names or plant names: ".join(',',@parents_missing);
    }

    my @crosses = keys %seen_cross_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@crosses }
    });
    while (my $r=$rs->next){
        push @error_messages, "Cross unique id already exists in database: ".$r->uniquename;
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1;

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
    my %cross_additional_info;
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my $accession_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();

    for my $row ( 1 .. $row_max ) {
        my $cross_name;
        my $cross_combination;
        my $cross_type;
        my $female_parent;
        my $male_parent;
        my $cross_stock;

        if ($worksheet->get_cell($row,0)) {
            $cross_name = $worksheet->get_cell($row,0)->value();
            $cross_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $cross_combination =  $worksheet->get_cell($row,1)->value();
            $cross_combination =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $cross_type = $worksheet->get_cell($row,2)->value();
            $cross_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $female_parent =  $worksheet->get_cell($row,3)->value();
            $female_parent =~ s/^\s+|\s+$//g;
        }

        if (!defined $cross_name && !defined $cross_type && !defined $female_parent) {
            last;
        }

        if ($worksheet->get_cell($row,4)) {
            $male_parent =  $worksheet->get_cell($row,4)->value();
            $male_parent =~ s/^\s+|\s+$//g;
        }

        for my $column ( 5 .. $col_max ) {
            if ($worksheet->get_cell($row,$column)) {
                my $info_header =  $worksheet->get_cell(0,$column)->value();
                $info_header =~ s/^\s+|\s+$//g;
                $cross_additional_info{$cross_name}{$info_header} = $worksheet->get_cell($row,$column)->value();
            }
        }

        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_name, cross_type=>$cross_type, cross_combination=>$cross_combination);

        my $female_rs = $schema->resultset("Stock::Stock")->find({uniquename => $female_parent});
        my $female_stock_id = $female_rs->stock_id();
        my $female_type_id = $female_rs->type_id();

        my $female_accession_name;
        my $female_accession_stock_id;
        if ($female_type_id == $plot_stock_type_id) {
            $female_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$female_stock_id, type_id=>$plot_of_type_id})->object_id();
            $female_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $female_accession_stock_id})->uniquename();
            my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
            $pedigree->set_female_plot($female_plot_individual);
        } elsif ($female_type_id == $plant_stock_type_id) {
            $female_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$female_stock_id, type_id=>$plant_of_type_id})->object_id();
            $female_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $female_accession_stock_id})->uniquename();
            my $female_plant_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
            $pedigree->set_female_plant($female_plant_individual);
        } else {
            $female_accession_name = $female_parent;
        }

        my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_accession_name);
        $pedigree->set_female_parent($female_parent_individual);

        if ($male_parent) {
            my $male_accession_stock_id;
            my $male_accession_name;
            my $male_rs = $schema->resultset("Stock::Stock")->find({uniquename => $male_parent});
            my $male_stock_id = $male_rs->stock_id();
            my $male_type_id = $male_rs->type_id();

            if ($male_type_id == $plot_stock_type_id) {
                $male_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$male_stock_id, type_id=>$plot_of_type_id})->object_id();
                $male_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $male_accession_stock_id})->uniquename();
                my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
                $pedigree->set_male_plot($male_plot_individual);
            } elsif ($male_type_id == $plant_stock_type_id) {
                $male_accession_stock_id = $schema->resultset("Stock::StockRelationship")->find({subject_id=>$male_stock_id, type_id=>$plant_of_type_id})->object_id();
                $male_accession_name = $schema->resultset("Stock::Stock")->find({stock_id => $male_accession_stock_id})->uniquename();
                my $male_plant_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
                $pedigree->set_male_plant($male_plant_individual);
            } else {
                $male_accession_name = $male_parent
            }

            my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_accession_name);
            $pedigree->set_male_parent($male_parent_individual);
        }

        push @pedigrees, $pedigree;

    }

    $parsed_result{'additional_info'} = \%cross_additional_info;

    $parsed_result{'crosses'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}



1;
