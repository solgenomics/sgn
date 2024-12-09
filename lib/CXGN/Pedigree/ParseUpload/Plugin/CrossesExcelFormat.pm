package CXGN::Pedigree::ParseUpload::Plugin::CrossesExcelFormat;

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
    $supported_cross_types{'sib'} = 1; #both parents required but can be the same
    $supported_cross_types{'bulk'} = 1; #both female population and male accession required
    $supported_cross_types{'bulk_self'} = 1; #only female population required
    $supported_cross_types{'bulk_open'} = 1; #only female population required, male parent can be a population or unknown
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
    if (($col_max - $col_min)  < 6 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of crosses
        push @error_messages, "Spreadsheet is missing header or contains no row";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $cross_name_header;
    my $cross_combination_header;
    my $cross_type_header;
    my $female_parent_header;
    my $male_parent_header;
    my $female_plot_plant_header;
    my $male_plot_plant_header;

    if ($worksheet->get_cell(0,0)) {
        $cross_name_header  = $worksheet->get_cell(0,0)->value();
        $cross_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $cross_combination_header  = $worksheet->get_cell(0,1)->value();
        $cross_combination_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $cross_type_header  = $worksheet->get_cell(0,2)->value();
        $cross_type_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $female_parent_header  = $worksheet->get_cell(0,3)->value();
        $female_parent_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $male_parent_header  = $worksheet->get_cell(0,4)->value();
        $male_parent_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $female_plot_plant_header  = $worksheet->get_cell(0,5)->value();
        $female_plot_plant_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $male_plot_plant_header  = $worksheet->get_cell(0,6)->value();
        $male_plot_plant_header =~ s/^\s+|\s+$//g;
    }

    if (!$cross_name_header || $cross_name_header ne 'cross_unique_id' ) {
        push @error_messages, "Cell A1: cross_unique_id is missing from the header";
    }
    if (!$cross_combination_header || $cross_combination_header ne 'cross_combination' ) {
        push @error_messages, "Cell B1: cross_combination is missing from the header";
    }
    if (!$cross_type_header || $cross_type_header ne 'cross_type') {
        push @error_messages, "Cell C1: cross_type is missing from the header";
    }
    if (!$female_parent_header || $female_parent_header ne 'female_parent') {
        push @error_messages, "Cell D1: female_parent is missing from the header";
    }
    if (!$male_parent_header || $male_parent_header ne 'male_parent') {
        push @error_messages, "Cell E1: male_parent is missing from the header";
    }
    if (!$female_plot_plant_header || (($female_plot_plant_header ne 'female_plot') && ($female_plot_plant_header ne 'female_plant'))) {
        push @error_messages, "Cell F1: female_plot or female_plant is missing from the header";
    }
    if (!$male_plot_plant_header || (($male_plot_plant_header ne 'male_plot') && ($male_plot_plant_header ne 'male_plant'))) {
        push @error_messages, "Cell G1: male_plot or male_plant is missing from the header";
    }

    my %valid_additional_info;
    my @valid_info = @{$cross_additional_info};
    foreach my $info(@valid_info){
        $valid_additional_info{$info} = 1;
    }

    for my $column (7 .. $col_max){
        if ($worksheet->get_cell(0, $column)) {
            my $header_string = $worksheet->get_cell(0,$column)->value();
            $header_string =~ s/^\s+|\s+$//g;
            if (($header_string) && (!$valid_additional_info{$header_string})){
                push @error_messages, "Invalid info type: $header_string";
            }
        }
    }

    my %seen_cross_names;
    my %seen_accession_names;
    my %seen_plot_plant_names;
    my %seen_backcross_parents;
    my %seen_population_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $cross_name;
        my $cross_combination;
        my $cross_type;
        my $female_parent;
        my $male_parent;
        my $female_plot_plant_name;
        my $male_plot_plant_name;

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

        if (!defined $cross_name && !defined $cross_type && !defined $female_parent) {
            last;
        }

        if ($worksheet->get_cell($row,4)) {
            $male_parent =  $worksheet->get_cell($row,4)->value();
        }

        if ($worksheet->get_cell($row,5)) {
            $female_plot_plant_name =  $worksheet->get_cell($row,5)->value();
        }

        if ($worksheet->get_cell($row,6)) {
            $male_plot_plant_name =  $worksheet->get_cell($row,6)->value();
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

        #male parent must not be blank if type is biparental or bulk
        if (!$male_parent || $male_parent eq '') {
            if ($cross_type eq ( 'biparental' || 'bulk' || 'sib' || 'polycross' || 'backcross' )) {
                push @error_messages, "Cell E$row_name: male parent required for biparental, sib, polycross, backcross and bulk cross types";
            }
        }

        if ($cross_name){
            $cross_name =~ s/^\s+|\s+$//g;
            $seen_cross_names{$cross_name}++;
        }

        if (($cross_type eq 'bulk') || ($cross_type eq 'bulk_self') || ($cross_type eq 'bulk_open')) {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_population_names{$female_parent}++;
            if ($cross_type eq 'bulk_open') {
                if ($male_parent) {
                    $male_parent =~ s/^\s+|\s+$//g;
                    $seen_population_names{$male_parent}++;
                }
            } elsif ($cross_type eq 'bulk') {
                $male_parent =~ s/^\s+|\s+$//g;
                $seen_accession_names{$male_parent}++;
            }
        } elsif (($cross_type eq 'polycross') || ($cross_type eq 'open')) {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_accession_names{$female_parent}++;
            if ($male_parent) {
                $male_parent =~ s/^\s+|\s+$//g;
                $seen_population_names{$male_parent}++;
            }
        } elsif ($cross_type eq 'backcross') {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_backcross_parents{$female_parent}++;
            $male_parent =~ s/^\s+|\s+$//g;
            $seen_backcross_parents{$male_parent}++;
        } else {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_accession_names{$female_parent}++;

            if ($male_parent){
                $male_parent =~ s/^\s+|\s+$//g;
                $seen_accession_names{$male_parent}++;
            }
        }

        if ($female_plot_plant_name){
            $female_plot_plant_name =~ s/^\s+|\s+$//g;
            $seen_plot_plant_names{$female_plot_plant_name}++;
        }

        if ($male_plot_plant_name){
            $male_plot_plant_name =~ s/^\s+|\s+$//g;
            $seen_plot_plant_names{$male_plot_plant_name}++;
        }
    }


    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames',\@accessions)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as accession uniquenames: ".join(',',@accessions_missing);
        $errors{'missing_accessions'} = \@accessions_missing;
    }

    my @populations = keys %seen_population_names;
    my $population_validator = CXGN::List::Validate->new();
    my @populations_missing = @{$population_validator->validate($schema,'populations',\@populations)->{'missing'}};
    if (scalar(@populations_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as population uniquenames: ".join(',',@populations_missing);
    }

    my @backcross_parents = keys %seen_backcross_parents;
    my $backcross_parent_validator = CXGN::List::Validate->new();
    my @backcross_parents_missing = @{$backcross_parent_validator->validate($schema,'accessions_or_crosses',\@backcross_parents)->{'missing'}};
    if (scalar(@backcross_parents_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as uniquenames: ".join(',',@backcross_parents_missing);
        $errors{'missing_accessions_or_crosses'} = \@backcross_parents_missing;
    }

    if (($female_plot_plant_header eq 'female_plot') && ($male_plot_plant_header eq 'male_plot')) {
        my @plots = keys %seen_plot_plant_names;
        my $plot_validator = CXGN::List::Validate->new();
        my @plots_missing = @{$plot_validator->validate($schema,'plots',\@plots)->{'missing'}};

        if (scalar(@plots_missing) > 0) {
            push @error_messages, "The following plots are not in the database or are not in the database as uniquenames: ".join(',',@plots_missing);
            $errors{'missing_plots'} = \@plots_missing;
        }
    } elsif (($female_plot_plant_header eq 'female_plant') && ($male_plot_plant_header eq 'male_plant')) {
        my @plants = keys %seen_plot_plant_names;
        my $plant_validator = CXGN::List::Validate->new();
        my @plants_missing = @{$plant_validator->validate($schema,'plants',\@plants)->{'missing'}};

        if (scalar(@plants_missing) > 0) {
            push @error_messages, "The following plants are not in the database as uniquenames or synonyms: ".join(',',@plants_missing);
            $errors{'missing_plants'} = \@plants_missing;
        }
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

    return 1; #returns true if validation is passed

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

    my $female_plot_plant_header  = $worksheet->get_cell(0,5)->value();
    my $male_plot_plant_header  = $worksheet->get_cell(0,6)->value();

    for my $row ( 1 .. $row_max ) {
        my $cross_name;
        my $cross_combination;
        my $cross_type;
        my $female_parent;
        my $male_parent;
        my $female_plot;
        my $male_plot;
        my $female_plant;
        my $male_plant;
        my $cross_stock;

        if ($worksheet->get_cell($row,0)) {
            $cross_name = $worksheet->get_cell($row,0)->value();
            $cross_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
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

        if ($worksheet->get_cell($row,5)) {
            if ($female_plot_plant_header eq 'female_plot') {
                $female_plot =  $worksheet->get_cell($row,5)->value();
                $female_plot =~ s/^\s+|\s+$//g;
            } elsif ($female_plot_plant_header eq 'female_plant') {
                $female_plant = $worksheet->get_cell($row,5)->value();
                $female_plant =~ s/^\s+|\s+$//g;
            }
        }

        if ($worksheet->get_cell($row,6)) {
            if ($male_plot_plant_header eq 'male_plot') {
                $male_plot =  $worksheet->get_cell($row,6)->value();
                $male_plot =~ s/^\s+|\s+$//g;
            } elsif ($male_plot_plant_header eq 'male_plant') {
                $male_plant = $worksheet->get_cell($row,6)->value();
                $male_plant =~ s/^\s+|\s+$//g;
            }
        }

        for my $column ( 7 .. $col_max ) {
            if ($worksheet->get_cell($row,$column)) {
                my $info_header =  $worksheet->get_cell(0,$column)->value();
                $info_header =~ s/^\s+|\s+$//g;
                $cross_additional_info{$cross_name}{$info_header} = $worksheet->get_cell($row,$column)->value();
            }
        }

        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_name, cross_combination=>$cross_combination, cross_type=>$cross_type);
        if ($female_parent) {
            my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
            $pedigree->set_female_parent($female_parent_individual);
        }
        if ($male_parent) {
            my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
            $pedigree->set_male_parent($male_parent_individual);
        }
        if ($female_plot) {
            my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $female_plot);
            $pedigree->set_female_plot($female_plot_individual);
        }
        if ($male_plot) {
            my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $male_plot);
            $pedigree->set_male_plot($male_plot_individual);
        }
        if ($female_plant) {
            my $female_plant_individual = Bio::GeneticRelationships::Individual->new(name => $female_plant);
            $pedigree->set_female_plant($female_plant_individual);
        }
        if ($male_plant) {
            my $male_plant_individual = Bio::GeneticRelationships::Individual->new(name => $male_plant);
            $pedigree->set_male_plant($male_plant_individual);
        }

        push @pedigrees, $pedigree;

    }

    $parsed_result{'additional_info'} = \%cross_additional_info;

    $parsed_result{'crosses'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
