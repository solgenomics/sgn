package CXGN::Stock::ParseUpload::Plugin::VectorsXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::BreedersToolbox::StocksFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $editable_stockprops = $self->get_editable_stock_props();

    # Match a dot, extension .xls / .xlsx
    my $extension = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my @error_messages;
    my %errors;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if (!$excel_obj) {
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # get column headers
    #
    my $uniquename_head;
    my $species_name_head;

    if ($worksheet->get_cell(0,0)) {
        $uniquename_head  = $worksheet->get_cell(0,0)->value();
        $uniquename_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $species_name_head  = $worksheet->get_cell(0,1)->value();
        $species_name_head =~ s/^\s+|\s+$//g;
    }

    push @$editable_stockprops, ('VectorType','Strain','CloningOrganism','InherentMarker','Backbone','SelectionMarker','CassetteName','Gene','Promotors','Terminators','BacterialResistantMarker','PlantAntibioticResistantMarker');
    my %allowed_stockprops_head = map { $_ => 1 } @$editable_stockprops;
    for my $i (3..$col_max){
        my $stockprops_head;
        if ($worksheet->get_cell(0,$i)) {
            $stockprops_head  = $worksheet->get_cell(0,$i)->value();
        }
        if ($stockprops_head && !exists($allowed_stockprops_head{$stockprops_head})){
            push @error_messages, "$stockprops_head is not a valid property to have in the header! Please check the spreadsheet format help.";
        }
    }

    if (!$uniquename_head || $uniquename_head ne 'uniquename' ) {
        push @error_messages, "Cell A1: uniquename is missing from the header";
    }
    if (!$species_name_head || $species_name_head ne 'species_name') {
        push @error_messages, "Cell B1: species_name is missing from the header";
    }

    my %seen_vector_names;
    my %vector_name_counts;
    my %seen_species_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $vector_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $vector_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }

        if (!$vector_name || $vector_name eq '' ) {
            push @error_messages, "Cell A$row_name: vector_name missing.";
        } else {
            $vector_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_vector_names{$vector_name}=$row_name;
	        $vector_name_counts{$vector_name}++;
        }

        if (!$species_name || $species_name eq '' ) {
            push @error_messages, "Cell B$row_name: species_name missing.";
        } else {
            $species_name =~ s/^\s+|\s+$//g;
            $seen_species_names{$species_name}=$row_name;
        }
    }

    my @species = keys %seen_species_names;
    my $species_validator = CXGN::List::Validate->new();
    my @species_missing = @{$species_validator->validate($schema,'species',\@species)->{'missing'}};

    if (scalar(@species_missing) > 0) {
        push @error_messages, "The following species are not in the database as species in the organism table: ".join(',',@species_missing);
        $errors{'missing_species'} = \@species_missing;
    }

    foreach my $k (keys %vector_name_counts) {
        if ($vector_name_counts{$k} > 1) {
            push @error_messages, "Vector $k occures $vector_name_counts{$k} times in the file. Vector names must be unique. Please remove duplicated vector names.";
        }
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
    my $editable_stockprops = $self->get_editable_stock_props();
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $do_fuzzy_search = $self->get_do_fuzzy_search();

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
    my %parsed_entries;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_vector_names;
    my %seen_species_names;

    for my $row ( 1 .. $row_max ) {
        my $vector_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $vector_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }
        if ($vector_name){
            $vector_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_vector_names{$vector_name}++;
        }
        if ($species_name){
            $species_name =~ s/^\s+|\s+$//g;
            $seen_species_names{$species_name}++;
        }
    }

    my @vector_list = keys %seen_vector_names;
    my @organism_list = keys %seen_species_names;
    my %vector_lookup;
    my $vector_in_db_rs = $schema->resultset("Stock::Stock")->search({uniquename=>{-ilike=>\@vector_list}});
    while(my $r=$vector_in_db_rs->next){
        $vector_lookup{$r->uniquename} = $r->stock_id;
    }

    my %col_name_map = (
        'vector_type' => ['vector_type','VectorType'],
        'strain' => ['strain','Strain'],
        'cloning_organism' => ['cloning_organism','CloningOrganism'],
        'inherent_marker' => ['inherent_marker','InherentMarker'],
        'backbone' => ['backbone','Backbone'],
        'selection_marker' => ['selection_marker','SelectionMarker'],
        'cassette_name' => ['cassette_name','CassetteName'],
        'gene' => ['gene','Gene'],
        'promotors' => ['promotors','Promotors'],
        'terminators' => ['terminators','Terminators'],
        'plant_antibiotic_resistant_marker' => ['plant_antibiotic_resistant_marker','PlantAntibioticResistantMarker'],
        'bacterial_resistant_marker' => ['bacterial_resistant_marker','BacterialResistantMarker'],
    );

    my @header;
    for my $i (2..$col_max){
        my $stockprops_head;
        if ($worksheet->get_cell(0,$i)) {
            $stockprops_head  = $worksheet->get_cell(0,$i)->value();
        }
        push @header, $stockprops_head;
    }

    for my $row ( 1 .. $row_max ) {
        my $vector_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $vector_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
            $species_name =~ s/^\s+|\s+$//g;
        }


        $vector_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        if (!$vector_name && !$species_name) {
            next;
        }

        my $stock_id;
        if(exists($vector_lookup{$vector_name})){
            $stock_id = $vector_lookup{$vector_name};
        }

        my %row_info = (
            germplasmName => $vector_name,
            uniqueName => $vector_name,
            species_name => $species_name,
        );
        #For "updating" existing vectors by adding properties.
        if ($stock_id){
            $row_info{stock_id} = $stock_id;
        }

        my $counter = 0;
        for my $i (2..$col_max){
            my $stockprop_header_term = $header[$counter];
            my $stockprops_value;
            if ($worksheet->get_cell($row,$i)) {
                $stockprops_value  = $worksheet->get_cell($row,$i)->value();
            }
            if ($stockprops_value){
                my $key_name;
                if (exists($col_name_map{$stockprop_header_term})) {
                    $row_info{$col_name_map{$stockprop_header_term}->[1]} = $stockprops_value;
                } else {
                    $row_info{$stockprop_header_term} = $stockprops_value;
                }
            }
            $counter++;
        }

        $parsed_entries{$row} = \%row_info;
    }

    my $fuzzy_vector_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $max_distance = 0.2;
    my $found_vectors = [];
    my $fuzzy_vectors = [];
    my $absent_vectors = [];
    my $found_organisms;
    my $fuzzy_organisms;
    my $absent_organisms;
    my %return_data;

    #remove all trailing and ending spaces from vectors and organisms
    s/^\s+|\s+$//g for @vector_list;
    s/^\s+|\s+$//g for @organism_list;

    if (scalar(@vector_list) <1) { return; }

    if ($do_fuzzy_search) {
        my $fuzzy_search_result = $fuzzy_vector_search->get_matches(\@vector_list, $max_distance, 'vector_construct');

        $found_vectors = $fuzzy_search_result->{'found'};
        $fuzzy_vectors = $fuzzy_search_result->{'fuzzy'};
        $absent_vectors = $fuzzy_search_result->{'absent'};

        if (scalar @organism_list > 0){
            my $fuzzy_organism_result = $fuzzy_organism_search->get_matches(\@organism_list, $max_distance);
            $found_organisms = $fuzzy_organism_result->{'found'};
            $fuzzy_organisms = $fuzzy_organism_result->{'fuzzy'};
            $absent_organisms = $fuzzy_organism_result->{'absent'};
        }

        if ($fuzzy_search_result->{'error'}){
            $return_data{error_string} = $fuzzy_search_result->{'error'};
        }
    } else {
        my $validator = CXGN::List::Validate->new();
        my $absent_vectors = $validator->validate($schema, 'vector_construct', \@vector_list)->{'missing'};
        my %vectors_missing_hash = map { $_ => 1 } @$absent_vectors;

        foreach (@vector_list){
            if (!exists($vectors_missing_hash{$_})){
                push @$found_vectors, { unique_name => $_,  matched_string => $_};
                push @$fuzzy_vectors, { unique_name => $_,  matched_string => $_};
            }
        }
    }

    %return_data = (
        parsed_data => \%parsed_entries,
        found_vectors => $found_vectors,
        fuzzy_vectors => $fuzzy_vectors,
        absent_vectors => $absent_vectors,
        found_organisms => $found_organisms,
        fuzzy_organisms => $fuzzy_organisms,
        absent_organisms => $absent_organisms
    );
    # print STDERR "\n\nVectorsXLS parsed results :\n".Data::Dumper::Dumper(%return_data)."\n\n";

    $self->_set_parsed_data(\%return_data);
    return 1;
}


1;
