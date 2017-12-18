package CXGN::Stock::ParseUpload::Plugin::AccessionsXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::BreedersToolbox::AccessionsFuzzySearch;
use CXGN::BreedersToolbox::OrganismFuzzySearch;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $parser = Spreadsheet::ParseExcel->new();
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

    #get column headers
    my $accession_name_head;
    my $species_name_head;
    my $population_name_head;
    my $organization_name_head;
    my $synonyms_head;

    if ($worksheet->get_cell(0,0)) {
        $accession_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $species_name_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $population_name_head  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $organization_name_head  = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $synonyms_head  = $worksheet->get_cell(0,4)->value();
    }
    my @allowed_stockprops_head = ('location_code(s)','ploidy_level(s)','genome_structure(s)','variety(s)','donor(s)','donor_institute(s)','donor_PUI(s)','country_of_origin(s)','state(s)','institute_code(s)','institute_name(s)','biological_status_of_accession_code(s)','notes(s)','accession_number(s)','PUI(s)','seed_source(s)','type_of_germplasm_storage_code(s)','acquisition_date(s)','transgenic','introgression_parent','introgression_backcross_parent','introgression_map_version','introgression_chromosome','introgression_start_position_bp','introgression_end_position_bp');
    my %allowed_stockprops_head = map { $_ => 1 } @allowed_stockprops_head;
    for my $i (5..$col_max){
        my $stockprops_head;
        if ($worksheet->get_cell(0,$i)) {
            $stockprops_head  = $worksheet->get_cell(0,5)->value();
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
    if (!$organization_name_head || $organization_name_head ne 'organization_name(s)') {
        push @error_messages, "Cell D1: organization_name(s) is missing from the header";
    }
    if (!$synonyms_head || $synonyms_head ne 'synonym(s)') {
        push @error_messages, "Cell E1: synonym(s) is missing from the header";
    }

    my %seen_accession_names;
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
        elsif ($accession_name =~ /\s/ || $accession_name =~ /\// || $accession_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: accession_name must not contain spaces or slashes.";
        }
        else {
            $seen_accession_names{$accession_name}=$row_name;
        }

        if (!$species_name || $species_name eq '' ) {
            push @error_messages, "Cell B$row_name: species_name missing.";
        }
        else {
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
            $seen_accession_names{$accession_name}++;
        }
        if ($species_name){
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
    my $accessions_in_db_rs = $schema->resultset("Stock::Stock")->search({uniquename=>{-in=>\@accession_list}});
    while(my $r=$accessions_in_db_rs->next){
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }

    my %col_name_map;
    for my $i (5..$col_max){
        my $stockprops_head;
        if ($worksheet->get_cell(0,$i)) {
            $stockprops_head  = $worksheet->get_cell(0,$i)->value();
        }
        my $stockprop_cvterm_name;
        my $internal_ref_name;
        if ($stockprops_head eq 'location_code(s)'){
            $stockprop_cvterm_name = 'location_code';
            $internal_ref_name = 'locationCode';
        }
        if ($stockprops_head eq 'ploidy_level(s)'){
            $stockprop_cvterm_name = 'ploidy_level';
            $internal_ref_name = 'ploidyLevel';
        }
        if ($stockprops_head eq 'genome_structure(s)'){
            $stockprop_cvterm_name = 'genome_structure';
            $internal_ref_name = 'genomeStructure';
        }
        if ($stockprops_head eq 'variety(s)'){
            $stockprop_cvterm_name = 'variety';
            $internal_ref_name = 'variety';
        }
        if ($stockprops_head eq 'donor(s)'){
            $stockprop_cvterm_name = 'donor';
        }
        if ($stockprops_head eq 'donor_institute(s)'){
            $stockprop_cvterm_name = 'donor institute';
        }
        if ($stockprops_head eq 'donor_PUI(s)'){
            $stockprop_cvterm_name = 'donor PUI';
        }
        if ($stockprops_head eq 'country_of_origin(s)'){
            $stockprop_cvterm_name = 'country of origin';
            $internal_ref_name = 'countryOfOriginCode';
        }
        if ($stockprops_head eq 'state(s)'){
            $stockprop_cvterm_name = 'state';
            $internal_ref_name = 'state';
        }
        if ($stockprops_head eq 'institute_code(s)'){
            $stockprop_cvterm_name = 'institute code';
            $internal_ref_name = 'instituteCode';
        }
        if ($stockprops_head eq 'institute_name(s)'){
            $stockprop_cvterm_name = 'institute name';
            $internal_ref_name = 'instituteName';
        }
        if ($stockprops_head eq 'biological_status_of_accession_code(s)'){
            $stockprop_cvterm_name = 'biological status of accession code';
            $internal_ref_name = 'biologicalStatusOfAccessionCode';
        }
        if ($stockprops_head eq 'notes(s)'){
            $stockprop_cvterm_name = 'notes';
            $internal_ref_name = 'notes';
        }
        if ($stockprops_head eq 'accession_number(s)'){
            $stockprop_cvterm_name = 'accession number';
            $internal_ref_name = 'accessionNumber';
        }
        if ($stockprops_head eq 'PUI(s)'){
            $stockprop_cvterm_name = 'PUI';
            $internal_ref_name = 'germplasmPUI';
        }
        if ($stockprops_head eq 'seed_source(s)'){
            $stockprop_cvterm_name = 'seed source';
            $internal_ref_name = 'germplasmSeedSource';
        }
        if ($stockprops_head eq 'type_of_germplasm_storage_code(s)'){
            $stockprop_cvterm_name = 'type of germplasm storage code';
            $internal_ref_name = 'typeOfGermplasmStorageCode';
        }
        if ($stockprops_head eq 'acquisition_date(s)'){
            $stockprop_cvterm_name = 'acquisition date';
            $internal_ref_name = 'acquisitionDate';
        }
        if ($stockprops_head eq 'transgenic(s)'){
            $stockprop_cvterm_name = 'transgenic';
            $internal_ref_name = 'transgenic';
        }
        if ($stockprops_head eq 'introgression_parent'){
            $stockprop_cvterm_name = 'introgression_parent';
            $internal_ref_name = 'introgression_parent';
        }
        if ($stockprops_head eq 'introgression_backcross_parent'){
            $stockprop_cvterm_name = 'introgression_backcross_parent';
            $internal_ref_name = 'introgression_backcross_parent';
        }
        if ($stockprops_head eq 'introgression_map_version'){
            $stockprop_cvterm_name = 'introgression_map_version';
            $internal_ref_name = 'introgression_map_version';
        }
        if ($stockprops_head eq 'introgression_chromosome'){
            $stockprop_cvterm_name = 'introgression_chromosome';
            $internal_ref_name = 'introgression_chromosome';
        }
        if ($stockprops_head eq 'introgression_start_position_bp'){
            $stockprop_cvterm_name = 'introgression_start_position_bp';
            $internal_ref_name = 'introgression_start_position_bp';
        }
        if ($stockprops_head eq 'introgression_end_position_bp'){
            $stockprop_cvterm_name = 'introgression_end_position_bp';
            $internal_ref_name = 'introgression_end_position_bp';
        }
        $col_name_map{$i} = [$stockprop_cvterm_name, $internal_ref_name];
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
        }
        if ($worksheet->get_cell($row,2)) {
            $population_name = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $organization_name = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            @synonyms = split ',', $worksheet->get_cell($row,4)->value();
        }

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
        }

        for my $i (5..$col_max){
            my $stockprops_value;
            if ($worksheet->get_cell($row,$i)) {
                $stockprops_value  = $worksheet->get_cell($row,$i)->value();
            }
            if ($stockprops_value){
                my $key_name;
                if ($col_name_map{$i}->[0] eq 'donor' || $col_name_map{$i}->[0] eq 'donor institute' || $col_name_map{$i}->[0] eq 'donor PUI'){
                    my %donor_key_map = ('donor'=>'donorGermplasmName', 'donor institute'=>'donorInstituteCode', 'donor PUI'=>'germplasmPUI');
                    if (exists($row_info{donors})){
                        my $donors_hash = $row_info{donors};
                        $donors_hash->{$donor_key_map{$col_name_map{$i}->[0]}} = $stockprops_value;
                        $row_info{donors} = $donors_hash;
                    } else {
                        $row_info{donors} = { $donor_key_map{$col_name_map{$i}->[0]} => $stockprops_value };
                    }
                } else {
                    $row_info{$col_name_map{$i}->[1]} = $stockprops_value;
                }
            }
        }

        $parsed_entries{$row} = \%row_info;
    }

    my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema});
    my $fuzzy_organism_search = CXGN::BreedersToolbox::OrganismFuzzySearch->new({schema => $schema});
    my $max_distance = 0.2;
    my $found_accessions;
    my $fuzzy_accessions;
    my $absent_accessions;
    my $found_synonyms = [];
    my $fuzzy_synonyms = [];
    my $absent_synonyms = [];
    my $found_organisms;
    my $fuzzy_organisms;
    my $absent_organisms;

    #remove all trailing and ending spaces from accessions and organisms
    s/^\s+|\s+$//g for @accession_list;
    s/^\s+|\s+$//g for @organism_list;

    my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance);
    #print STDERR "\n\nAccessionFuzzyResult:\n".Data::Dumper::Dumper($fuzzy_search_result)."\n\n";
    print STDERR "DoFuzzySearch 2".localtime()."\n";

    $found_accessions = $fuzzy_search_result->{'found'};
    $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
    $absent_accessions = $fuzzy_search_result->{'absent'};

    if (scalar @synonyms_list > 0){
        my $fuzzy_synonyms_result = $fuzzy_accession_search->get_matches(\@synonyms_list, $max_distance);
        $found_synonyms = $fuzzy_synonyms_result->{'found'};
        $fuzzy_synonyms = $fuzzy_synonyms_result->{'fuzzy'};
        $absent_synonyms = $fuzzy_synonyms_result->{'absent'};
        #print STDERR "\n\nOrganismFuzzyResult:\n".Data::Dumper::Dumper($fuzzy_organism_result)."\n\n";
    }

    if (scalar @organism_list > 0){
        my $fuzzy_organism_result = $fuzzy_organism_search->get_matches(\@organism_list, $max_distance);
        $found_organisms = $fuzzy_organism_result->{'found'};
        $fuzzy_organisms = $fuzzy_organism_result->{'fuzzy'};
        $absent_organisms = $fuzzy_organism_result->{'absent'};
        #print STDERR "\n\nOrganismFuzzyResult:\n".Data::Dumper::Dumper($fuzzy_organism_result)."\n\n";
    }

    if (scalar(@$fuzzy_accessions)>0 || scalar(@$fuzzy_synonyms)>0){
        my %synonym_hash;
        my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id;
        my $synonym_rs = $schema->resultset('Stock::Stock')->search({'stockprops.type_id'=>$synonym_type_id}, {join=>'stockprops', '+select'=>['stockprops.value'], '+as'=>['value']});
        while (my $r = $synonym_rs->next()){
            $synonym_hash{$r->get_column('value')} = $r->uniquename;
        }

        foreach (@$fuzzy_accessions){
            my $matches = $_->{matches};
            foreach my $m (@$matches){
                my $name = $m->{name};
                if (exists($synonym_hash{$name})){
                    $m->{is_synonym} = 1;
                    $m->{synonym_of} = $synonym_hash{$name};
                }
            }
        }

        foreach (@$fuzzy_synonyms){
            my $matches = $_->{matches};
            foreach my $m (@$matches){
                my $name = $m->{name};
                if (exists($synonym_hash{$name})){
                    $m->{is_synonym} = 1;
                    $m->{synonym_of} = $synonym_hash{$name};
                }
            }
        }
    }

    my %return_data = (
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

    $self->_set_parsed_data(\%return_data);
    return 1;
}


1;
