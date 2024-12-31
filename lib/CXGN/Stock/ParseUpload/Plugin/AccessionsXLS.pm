package CXGN::Stock::ParseUpload::Plugin::AccessionsXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::BreedersToolbox::StocksFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;

#
# DEPRECATED: This plugin has been replaced by the AccessionsGeneric plugin
#

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $editable_stockprops = $self->get_editable_stock_props();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my @error_messages;
    my %errors;
    my %missing_accessions;

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
    my $accession_name_head;
    my $species_name_head;
    my $population_name_head;
    my $organization_name_head;
    my $synonyms_head;

    if ($worksheet->get_cell(0,0)) {
        $accession_name_head  = $worksheet->get_cell(0,0)->value();
        $accession_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $species_name_head  = $worksheet->get_cell(0,1)->value();
        $species_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $population_name_head  = $worksheet->get_cell(0,2)->value();
        $population_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $organization_name_head  = $worksheet->get_cell(0,3)->value();
        $organization_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $synonyms_head  = $worksheet->get_cell(0,4)->value();
        $synonyms_head =~ s/^\s+|\s+$//g;
    }
    push @$editable_stockprops, ('location_code(s)','ploidy_level(s)','genome_structure(s)','variety(s)','donor(s)','donor_institute(s)','donor_PUI(s)','country_of_origin(s)','state(s)','institute_code(s)','institute_name(s)','biological_status_of_accession_code(s)','notes(s)','accession_number(s)','PUI(s)','seed_source(s)','type_of_germplasm_storage_code(s)','acquisition_date(s)','transgenic','introgression_parent','introgression_backcross_parent','introgression_map_version','introgression_chromosome','introgression_start_position_bp','introgression_end_position_bp');
    my %allowed_stockprops_head = map { $_ => 1 } @$editable_stockprops;
    for my $i (5..$col_max){
        my $stockprops_head;
        if ($worksheet->get_cell(0,$i)) {
            $stockprops_head  = $worksheet->get_cell(0,$i)->value();
        }
        if ($stockprops_head && !exists($allowed_stockprops_head{$stockprops_head})){
            push @error_messages, "$stockprops_head is not a valid property to have in the header! Please check the spreadsheet format help.";
        }
    }

    if (!$accession_name_head || $accession_name_head ne 'accession_name' ) {
        push @error_messages, "Cell A1: accession_name is missing from the header";
    }
    if (!$species_name_head || $species_name_head ne 'species_name') {
        push @error_messages, "Cell B1: species_name is missing from the header";
    }
    if (!$population_name_head || $population_name_head ne 'population_name') {
        push @error_messages, "Cell C1: population_name is missing from the header";
    }
    if (!$organization_name_head || ($organization_name_head ne 'organization_name(s)' && $organization_name_head ne 'organization_name') ) {
        push @error_messages, "Cell D1: organization_name is missing from the header";
    }
    if (!$synonyms_head || ($synonyms_head ne 'synonym(s)' && $synonyms_head ne 'synonym') ) {
        push @error_messages, "Cell E1: synonym is missing from the header";
    }

    my %seen_accession_names;
    my %accession_name_counts;
    my %seen_species_names;
    my %seen_synonyms;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $accession_name;
        my $species_name;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }

        if (!$accession_name || $accession_name eq '' ) {
            push @error_messages, "Cell A$row_name: accession_name missing.";
        }
        #elsif ($accession_name =~ /\s/ || $accession_name =~ /\// || $accession_name =~ /\\/ ) {
        #    push @error_messages, "Cell A$row_name: accession_name must not contain spaces or slashes.";
        #}
        else {
            $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accession_names{$accession_name}=$row_name;
	    $accession_name_counts{$accession_name}++;
        }

        if (!$species_name || $species_name eq '' ) {
            push @error_messages, "Cell B$row_name: species_name missing.";
        }
        else {
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

    foreach my $k (keys %accession_name_counts) {
	if ($accession_name_counts{$k} > 1) {
	    push @error_messages, "Accession $k occures $accession_name_counts{$k} times in the file. Accession names must be unique. Please remove duplicated accession names.";
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
    my $append_synonyms = $self->get_append_synonyms();

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

    my %seen_accession_names;
    my %seen_species_names;
    my %seen_synonyms;
    for my $row ( 1 .. $row_max ) {
        my $accession_name;
        my $species_name;
        my $synonyms_string;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $synonyms_string = $worksheet->get_cell($row,4)->value();
        }
        if ($accession_name){
            $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_accession_names{$accession_name}++;
        }
        if ($species_name){
            $species_name =~ s/^\s+|\s+$//g;
            $seen_species_names{$species_name}++;
        }
        if ($synonyms_string && $synonyms_string ne '' ) {
            my @synonym_names = split ',', $synonyms_string;
            foreach (@synonym_names){
                $seen_synonyms{$_}=$row;
            }
        }
    }

    my @accession_list = keys %seen_accession_names;
    my @synonyms_list = keys %seen_synonyms;
    my @organism_list = keys %seen_species_names;
    my %accession_lookup;
    my $accessions_in_db_rs = $schema->resultset("Stock::Stock")->search({uniquename=>{-ilike=>\@accession_list}});
    while(my $r=$accessions_in_db_rs->next){
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }

    # Old accession upload format had "(s)" appended to the editable_stock_props terms... this is now not the case, but should still allow for it. Now the header of the uploaded file should use the terms in the editable_stock_props configuration key directly.
    my %col_name_map = (
        'location_code(s)' => ['location_code', 'locationCode'],
        'location_code' => ['location_code', 'locationCode'],
        'ploidy_level(s)' => ['ploidy_level', 'ploidyLevel'],
        'ploidy_level' => ['ploidy_level', 'ploidyLevel'],
        'genome_structure(s)' => ['genome_structure', 'genomeStructure'],
        'genome_structure' => ['genome_structure', 'genomeStructure'],
        'variety(s)' => ['variety', 'variety'],
        'variety' => ['variety', 'variety'],
        'donor(s)' => ['donor', ''],
        'donor' => ['donor', ''],
        'donor_institute(s)' => ['donor institute', ''],
        'donor institute' => ['donor institute', ''],
        'donor_PUI(s)' => ['donor PUI', ''],
        'donor PUI' => ['donor PUI', ''],
        'country_of_origin(s)' => ['country of origin', 'countryOfOriginCode'],
        'country of origin' => ['country of origin', 'countryOfOriginCode'],
        'state(s)' => ['state', 'state'],
        'state' => ['state', 'state'],
        'institute_code(s)' => ['institute code', 'instituteCode'],
        'institute code' => ['institute code', 'instituteCode'],
        'institute_name(s)' => ['institute name', 'instituteName'],
        'institute name' => ['institute name', 'instituteName'],
        'biological_status_of_accession_code(s)' => ['biological status of accession code', 'biologicalStatusOfAccessionCode'],
        'biological status of accession code' => ['biological status of accession code', 'biologicalStatusOfAccessionCode'],
        'notes(s)' => ['notes', 'notes'],
        'notes' => ['notes', 'notes'],
        'accession_number(s)' => ['accession number', 'accessionNumber'],
        'accession number' => ['accession number', 'accessionNumber'],
        'PUI(s)' => ['PUI', 'germplasmPUI'],
        'PUI' => ['PUI', 'germplasmPUI'],
        'seed_source(s)' => ['seed source', 'germplasmSeedSource'],
        'seed source' => ['seed source', 'germplasmSeedSource'],
        'type_of_germplasm_storage_code(s)' => ['type of germplasm storage code', 'typeOfGermplasmStorageCode'],
        'type of germplasm storage code' => ['type of germplasm storage code', 'typeOfGermplasmStorageCode'],
        'acquisition_date(s)' => ['acquisition date', 'acquisitionDate'],
        'acquisition date' => ['acquisition date', 'acquisitionDate'],
        'transgenic(s)' => ['transgenic', 'transgenic'],
        'transgenic' => ['transgenic', 'transgenic'],
        'introgression_parent' => ['introgression_parent', 'introgression_parent'],
        'introgression_backcross_parent' => ['introgression_backcross_parent', 'introgression_backcross_parent'],
        'introgression_chromosome' => ['introgression_chromosome', 'introgression_chromosome'],
        'introgression_start_position_bp' => ['introgression_start_position_bp', 'introgression_start_position_bp'],
        'introgression_end_position_bp' => ['introgression_end_position_bp', 'introgression_end_position_bp']
    );

    my @header;
    for my $i (5..$col_max){
        my $stockprops_head;
        if ($worksheet->get_cell(0,$i)) {
            $stockprops_head  = $worksheet->get_cell(0,$i)->value();
        }
        push @header, $stockprops_head;
    }

    for my $row ( 1 .. $row_max ) {
        my $accession_name;
        my $species_name;
        my $population_name;
        my $organization_name;
        my @synonyms;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
            $species_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $population_name = $worksheet->get_cell($row,2)->value();
            $population_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $organization_name = $worksheet->get_cell($row,3)->value();
            $organization_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            @synonyms = split ',', $worksheet->get_cell($row,4)->value();
        }

        $accession_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        if (!$accession_name && !$species_name) {
            next;
        }

        my $stock_id;
        if(exists($accession_lookup{$accession_name})){
            $stock_id = $accession_lookup{$accession_name};
        }

        my %row_info = (
            germplasmName => $accession_name,
            defaultDisplayName => $accession_name,
            species => $species_name,
            populationName => $population_name,
            organizationName => $organization_name,
            synonyms => \@synonyms
        );
        #For "updating" existing accessions by adding properties.
        if ($stock_id){
            $row_info{stock_id} = $stock_id;

            # lookup existing accessions, if append_synonyms is selected
            if ( $append_synonyms ) {
                my @existing_synonyms;
                my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
                my $rs = $schema->resultset("Stock::Stockprop")->search({ type_id => $synonym_type_id, stock_id => $stock_id });
                while( my $r = $rs->next() ) {
                    push(@existing_synonyms, $r->value);
                }
                push(@existing_synonyms, @synonyms);
                s{^\s+|\s+$}{}g foreach @existing_synonyms;
                $row_info{synonyms} = \@existing_synonyms;
            }
        }

        my $counter = 0;
        for my $i (5..$col_max){
            my $stockprop_header_term = $header[$counter];
            my $stockprops_value;
            if ($worksheet->get_cell($row,$i)) {
                $stockprops_value  = $worksheet->get_cell($row,$i)->value();
            }
            if ($stockprops_value){
                my $key_name;
                if (exists($col_name_map{$stockprop_header_term}) && ($col_name_map{$stockprop_header_term}->[0] eq 'donor' || $col_name_map{$stockprop_header_term}->[0] eq 'donor institute' || $col_name_map{$stockprop_header_term}->[0] eq 'donor PUI') ) {
                    my %donor_key_map = ('donor'=>'donorGermplasmName', 'donor institute'=>'donorInstituteCode', 'donor PUI'=>'germplasmPUI');
                    if (exists($row_info{donors})){
                        my $donors_hash = $row_info{donors}->[0];
                        $donors_hash->{$donor_key_map{$col_name_map{$stockprop_header_term}->[0]}} = $stockprops_value;
                        $row_info{donors} = [$donors_hash];
                    } else {
                        $row_info{donors} = [{ $donor_key_map{$col_name_map{$stockprop_header_term}->[0]} => $stockprops_value }];
                    }
                } elsif (exists($col_name_map{$stockprop_header_term})) {
                    $row_info{$col_name_map{$stockprop_header_term}->[1]} = $stockprops_value;
                } else {
                    $row_info{other_editable_stock_props}->{$stockprop_header_term} = $stockprops_value;
                }
            }
            $counter++;
        }

        $parsed_entries{$row} = \%row_info;
    }

    my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $max_distance = 0.2;
    my $found_accessions = [];
    my $fuzzy_accessions = [];
    my $absent_accessions = [];
    my $found_synonyms = [];
    my $fuzzy_synonyms = [];
    my $absent_synonyms = [];
    my $found_organisms;
    my $fuzzy_organisms;
    my $absent_organisms;
    my %return_data;

    #remove all trailing and ending spaces from accessions and organisms
    s/^\s+|\s+$//g for @accession_list;
    s/^\s+|\s+$//g for @organism_list;
    s/^\s+|\s+$//g for @synonyms_list;

    if ($do_fuzzy_search) {
        my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance, 'accession');

        $found_accessions = $fuzzy_search_result->{'found'};
        $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
        $absent_accessions = $fuzzy_search_result->{'absent'};

        if (scalar @synonyms_list > 0){
            my $fuzzy_synonyms_result = $fuzzy_accession_search->get_matches(\@synonyms_list, $max_distance, 'accession');
            $found_synonyms = $fuzzy_synonyms_result->{'found'};
            $fuzzy_synonyms = $fuzzy_synonyms_result->{'fuzzy'};
            $absent_synonyms = $fuzzy_synonyms_result->{'absent'};
        }

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
        my $absent_accessions = $validator->validate($schema, 'accessions', \@accession_list)->{'missing'};
        my %accessions_missing_hash = map { $_ => 1 } @$absent_accessions;

        foreach (@accession_list){
            if (!exists($accessions_missing_hash{$_})){
                push @$found_accessions, { unique_name => $_,  matched_string => $_};
                push @$fuzzy_accessions, { unique_name => $_,  matched_string => $_};
            }
        }
    }

    %return_data = (
        parsed_data => \%parsed_entries,
        found_accessions => $found_accessions,
        fuzzy_accessions => $fuzzy_accessions,
        absent_accessions => $absent_accessions,
        found_synonyms => $found_synonyms,
        fuzzy_synonyms => $fuzzy_synonyms,
        absent_synonyms => $absent_synonyms,
        found_organisms => $found_organisms,
        fuzzy_organisms => $fuzzy_organisms,
        absent_organisms => $absent_organisms
    );
    print STDERR "\n\nAccessionsXLS parsed results :\n".Data::Dumper::Dumper(%return_data)."\n\n";

    $self->_set_parsed_data(\%return_data);
    return 1;
}


1;
