package CXGN::Stock::ParseUpload::Plugin::AccessionsXLS;

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
    my $location_code_head;
    my $synonyms_head;
    my $ploidy_level_head;
    my $genome_structure_head;
    my $variety_head;
    my $donor_head;
    my $donor_institute_head;
    my $donor_PUI_head;
    my $country_of_origin_head;
    my $state_head;
    my $institute_code_head;
    my $institute_name_head;
    my $biological_status_of_accession_code_head;
    my $notes_head;
    my $accession_number_head;
    my $PUI_head;
    my $seed_source_head;
    my $type_of_germplasm_storage_code_head;
    my $acquisition_date_head;
    my $transgenic_head;

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
        $location_code_head  = $worksheet->get_cell(0,4)->value();
    }
    if ($worksheet->get_cell(0,5)) {
        $synonyms_head  = $worksheet->get_cell(0,5)->value();
    }
    if ($worksheet->get_cell(0,6)) {
        $ploidy_level_head  = $worksheet->get_cell(0,6)->value();
    }
    if ($worksheet->get_cell(0,7)) {
        $genome_structure_head  = $worksheet->get_cell(0,7)->value();
    }
    if ($worksheet->get_cell(0,8)) {
        $variety_head  = $worksheet->get_cell(0,8)->value();
    }
    if ($worksheet->get_cell(0,9)) {
        $donor_head  = $worksheet->get_cell(0,9)->value();
    }
    if ($worksheet->get_cell(0,10)) {
        $donor_institute_head  = $worksheet->get_cell(0,10)->value();
    }
    if ($worksheet->get_cell(0,11)) {
        $donor_PUI_head  = $worksheet->get_cell(0,11)->value();
    }
    if ($worksheet->get_cell(0,12)) {
        $country_of_origin_head  = $worksheet->get_cell(0,12)->value();
    }
    if ($worksheet->get_cell(0,13)) {
        $state_head  = $worksheet->get_cell(0,13)->value();
    }
    if ($worksheet->get_cell(0,14)) {
        $institute_code_head  = $worksheet->get_cell(0,14)->value();
    }
    if ($worksheet->get_cell(0,15)) {
        $institute_name_head  = $worksheet->get_cell(0,15)->value();
    }
    if ($worksheet->get_cell(0,16)) {
        $biological_status_of_accession_code_head  = $worksheet->get_cell(0,16)->value();
    }
    if ($worksheet->get_cell(0,17)) {
        $notes_head  = $worksheet->get_cell(0,17)->value();
    }
    if ($worksheet->get_cell(0,18)) {
        $accession_number_head  = $worksheet->get_cell(0,18)->value();
    }
    if ($worksheet->get_cell(0,19)) {
        $PUI_head  = $worksheet->get_cell(0,19)->value();
    }
    if ($worksheet->get_cell(0,20)) {
        $seed_source_head  = $worksheet->get_cell(0,20)->value();
    }
    if ($worksheet->get_cell(0,21)) {
        $type_of_germplasm_storage_code_head  = $worksheet->get_cell(0,21)->value();
    }
    if ($worksheet->get_cell(0,22)) {
        $acquisition_date_head  = $worksheet->get_cell(0,22)->value();
    }
    if ($worksheet->get_cell(0,23)) {
        $transgenic_head  = $worksheet->get_cell(0,23)->value();
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
    if (!$organization_name_head || $organization_name_head ne 'organization_name') {
        push @error_messages, "Cell D1: organization_name is missing from the header";
    }
    if (!$location_code_head || $location_code_head ne 'location_code') {
        push @error_messages, "Cell E1: location_code is missing from the header";
    }
    if (!$synonyms_head || $synonyms_head ne 'synonyms') {
        push @error_messages, "Cell F1: synonyms is missing from the header";
    }
    if (!$ploidy_level_head || $ploidy_level_head ne 'ploidy_level') {
        push @error_messages, "Cell G1: ploidy_level is missing from the header";
    }
    if (!$genome_structure_head || $genome_structure_head ne 'genome_structure') {
        push @error_messages, "Cell H1: genome_structure is missing from the header";
    }
    if (!$variety_head || $variety_head ne 'variety') {
        push @error_messages, "Cell I1: variety is missing from the header";
    }
    if (!$donor_head || $donor_head ne 'donor') {
        push @error_messages, "Cell J1: donor is missing from the header";
    }
    if (!$donor_institute_head || $donor_institute_head ne 'donor_institute') {
        push @error_messages, "Cell K1: donor_institute is missing from the header";
    }
    if (!$donor_PUI_head || $donor_PUI_head ne 'donor_PUI') {
        push @error_messages, "Cell L1: donor_PUI is missing from the header";
    }
    if (!$country_of_origin_head || $country_of_origin_head ne 'country_of_origin') {
        push @error_messages, "Cell M1: country_of_origin is missing from the header";
    }
    if (!$state_head || $state_head ne 'state') {
        push @error_messages, "Cell N1: state is missing from the header";
    }
    if (!$institute_code_head || $institute_code_head ne 'institute_code') {
        push @error_messages, "Cell O1: institute_code is missing from the header";
    }
    if (!$institute_name_head || $institute_name_head ne 'institute_name') {
        push @error_messages, "Cell P1: institute_name is missing from the header";
    }
    if (!$biological_status_of_accession_code_head || $biological_status_of_accession_code_head ne 'biological_status_of_accession_code') {
        push @error_messages, "Cell Q1: biological_status_of_accession_code is missing from the header";
    }
    if (!$notes_head || $notes_head ne 'notes') {
        push @error_messages, "Cell R1: notes is missing from the header";
    }
    if (!$accession_number_head || $accession_number_head ne 'accession_number') {
        push @error_messages, "Cell S1: accession_number is missing from the header";
    }
    if (!$PUI_head || $PUI_head ne 'PUI') {
        push @error_messages, "Cell T1: PUI is missing from the header";
    }
    if (!$seed_source_head || $seed_source_head ne 'seed_source') {
        push @error_messages, "Cell U1: seed_source is missing from the header";
    }
    if (!$type_of_germplasm_storage_code_head || $type_of_germplasm_storage_code_head ne 'type_of_germplasm_storage_code') {
        push @error_messages, "Cell V1: type_of_germplasm_storage_code is missing from the header";
    }
    if (!$acquisition_date_head || $acquisition_date_head ne 'acquisition_date') {
        push @error_messages, "Cell W1: acquisition_date is missing from the header";
    }
    if (!$transgenic_head || $transgenic_head ne 'transgenic') {
        push @error_messages, "Cell X1: transgenic is missing from the header";
    }

    my %seen_accession_names;
    my %seen_species_names;
    my %seen_synonyms;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $accession_name;
        my $species_name;
        my $synonyms_string;

        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $species_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $synonyms_string = $worksheet->get_cell($row,5)->value();
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

        if ($synonyms_string && $synonyms_string ne '' ) {
            my @synonym_names = split ',', $synonyms_string;
            foreach (@synonym_names){
                $seen_synonyms{$_}=$row_name;
            }
        }

    }

    my @accessions = keys %seen_accession_names;
    my $accession_rs = $schema->resultset('Stock::Stock')->search({ 'uniquename' => {-in => \@accessions} });
    my %not_new_accessions;
    while (my $r = $accession_rs->next){
        #push @error_messages, "The following accession_name is already in the database and is not unique ".$r->uniquename;
        $not_new_accessions{$r->uniquename} = $r->stock_id;
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
        if ($worksheet->get_cell($row,5)) {
            $synonyms_string = $worksheet->get_cell($row,5)->value();
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
                $seen_synonyms{$_}=$row_name;
            }
        }
    }
    my @accessions = keys %seen_accession_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@accessions }
    });
    my %accession_lookup;
    while (my $r=$rs->next){
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $accession_name;
        my $species_name;
        my $population_name;
        my $organization_name;
        my $location_code;
        my $synonyms_string;
        my $ploidy_level;
        my $genome_structure;
        my $variety;
        my $donor;
        my $donor_institute;
        my $donor_PUI;
        my $country_of_origin;
        my $state;
        my $institute_code;
        my $institute_name;
        my $biological_status_of_accession_code;
        my $notes;
        my $accession_number;
        my $PUI_head;
        my $seed_source;
        my $type_of_germplasm_storage_code;
        my $acquisition_date;
        my $transgenic;

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
            $location_code = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $synonyms_string = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $ploidy_level = $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $genome_structure = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $variety = $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $donor = $worksheet->get_cell($row,9)->value();
        }
        if ($worksheet->get_cell($row,10)) {
            $donor_institute = $worksheet->get_cell($row,10)->value();
        }
        if ($worksheet->get_cell($row,11)) {
            $donor_PUI = $worksheet->get_cell($row,11)->value();
        }
        if ($worksheet->get_cell($row,12)) {
            $country_of_origin = $worksheet->get_cell($row,12)->value();
        }
        if ($worksheet->get_cell($row,13)) {
            $state = $worksheet->get_cell($row,13)->value();
        }
        if ($worksheet->get_cell($row,14)) {
            $institute_code = $worksheet->get_cell($row,14)->value();
        }
        if ($worksheet->get_cell($row,15)) {
            $institute_name = $worksheet->get_cell($row,15)->value();
        }
        if ($worksheet->get_cell($row,16)) {
            $biological_status_of_accession_code = $worksheet->get_cell($row,16)->value();
        }
        if ($worksheet->get_cell($row,17)) {
            $notes = $worksheet->get_cell($row,17)->value();
        }
        if ($worksheet->get_cell($row,18)) {
            $accession_number = $worksheet->get_cell($row,18)->value();
        }
        if ($worksheet->get_cell($row,19)) {
            $PUI_head = $worksheet->get_cell($row,19)->value();
        }
        if ($worksheet->get_cell($row,20)) {
            $seed_source = $worksheet->get_cell($row,20)->value();
        }
        if ($worksheet->get_cell($row,21)) {
            $type_of_germplasm_storage_code = $worksheet->get_cell($row,21)->value();
        }
        if ($worksheet->get_cell($row,22)) {
            $acquisition_date = $worksheet->get_cell($row,22)->value();
        }
        if ($worksheet->get_cell($row,23)) {
            $transgenic = $worksheet->get_cell($row,23)->value();
        }

        #skip blank lines
        if (!$accession_name && !$species_name) {
            next;
        }

        $parsed_entries{$row} = {
            plot_name => $plot_name,
            plot_stock_id => $plot_lookup{$plot_name},
            plant_name => $plant_name,
        };
    }

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
