package CXGN::Trial::ParseUpload::Plugin::GenotypeTrialXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $include_facility_identifiers = $self->get_facility_identifiers_included();
    my %errors;
    my @error_messages;
    my %missing_accessions;

    # Match a dot, followed by any number of non-dots until the
    # end of the line.
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
    my %seen_plot_names;
    my %seen_accession_names;
    my %seen_seedlot_names;
    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls or .xlsx) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $date_head;
    my $sample_id_head;
    my $well_A01_head;
    my $row_head;
    my $column_head;
    my $source_observation_unit_name_head;
    my $ncbi_taxonomy_id_head;
    my $dna_person_head;
    my $notes_head;
    my $tissue_type_head;
    my $extraction_head;
    my $concentration_head;
    my $volume_head;
    my $is_blank_head;
    my $facility_identifier_head;

    if ($worksheet->get_cell(0,0)) {
        $date_head  = $worksheet->get_cell(0,0)->value();
        $date_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $sample_id_head  = $worksheet->get_cell(0,1)->value();
        $sample_id_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $well_A01_head  = $worksheet->get_cell(0,2)->value();
        $well_A01_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $row_head  = $worksheet->get_cell(0,3)->value();
        $row_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $column_head  = $worksheet->get_cell(0,4)->value();
        $column_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $source_observation_unit_name_head  = $worksheet->get_cell(0,5)->value();
        $source_observation_unit_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $ncbi_taxonomy_id_head  = $worksheet->get_cell(0,6)->value();
        $ncbi_taxonomy_id_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
        $dna_person_head  = $worksheet->get_cell(0,7)->value();
        $dna_person_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,8)) {
        $notes_head  = $worksheet->get_cell(0,8)->value();
        $notes_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,9)) {
        $tissue_type_head  = $worksheet->get_cell(0,9)->value();
        $tissue_type_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,10)) {
        $extraction_head  = $worksheet->get_cell(0,10)->value();
        $extraction_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,11)) {
        $concentration_head = $worksheet->get_cell(0,11)->value();
        $concentration_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,12)) {
        $volume_head = $worksheet->get_cell(0,12)->value();
        $volume_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,13)) {
        $is_blank_head = $worksheet->get_cell(0,13)->value();
        $is_blank_head =~ s/^\s+|\s+$//g;
    }
    if ($include_facility_identifiers){
        if ($worksheet->get_cell(0,14)) {
            $facility_identifier_head = $worksheet->get_cell(0,14)->value();
            $facility_identifier_head =~ s/^\s+|\s+$//g;
        }
    }

    if (!$date_head || $date_head ne 'date' ) {
        push @error_messages, "Cell A1: date is missing from the header";
    }
    if (!$sample_id_head || $sample_id_head ne 'sample_id') {
        push @error_messages, "Cell B1: sample_id is missing from the header";
    }
    if (!$well_A01_head || $well_A01_head ne 'well_A01') {
        push @error_messages, "Cell C1: well_A01 is missing from the header.";
    }
    if (!$row_head || $row_head ne 'row') {
        push @error_messages, "Cell D1: row is missing from the header.";
    }
    if (!$column_head || $column_head ne 'column') {
        push @error_messages, "Cell E1: column is missing from the header.";
    }
    if (!$source_observation_unit_name_head || $source_observation_unit_name_head ne 'source_observation_unit_name') {
        push @error_messages, "Cell F1: source_observation_unit_name is missing from the header.";
    }
    if (!$ncbi_taxonomy_id_head || $ncbi_taxonomy_id_head ne 'ncbi_taxonomy_id') {
        push @error_messages, "Cell G1: ncbi_taxonomy_id is missing from the header. (Header is required, but values are optional)";
    }
    if (!$dna_person_head || $dna_person_head ne 'dna_person') {
        push @error_messages, "Cell H1: dna_person is missing from the header. (Header is required, but values are optional)";
    }
    if (!$notes_head || $notes_head ne 'notes') {
        push @error_messages, "Cell I1: notes is missing from the header. (Header is required, but values are optional)";
    }
    if (!$tissue_type_head || $tissue_type_head ne 'tissue_type') {
        push @error_messages, "Cell J1: tissue_type is missing from the header. (Header is required, but values are optional)";
    }
    if (!$extraction_head || $extraction_head ne 'extraction') {
        push @error_messages, "Cell K1: col_number is missing from the header. (Header is required, but values are optional)";
    }
    if (!$concentration_head || $concentration_head ne 'concentration') {
        push @error_messages, "Cell L1: concentration is missing from the header. (Header is required, but values are optional)";
    }
    if (!$volume_head || $volume_head ne 'volume') {
        push @error_messages, "Cell M1: volume is missing from the header. (Header is required, but values are optional)";
    }
    if (!$is_blank_head || $is_blank_head ne 'is_blank') {
        push @error_messages, "Cell N1: is_blank is missing from the header.";
    }
    if ($include_facility_identifiers) {
        if (!$facility_identifier_head || $facility_identifier_head ne 'facility_identifier') {
            push @error_messages, "Cell O1: facility_identifier is missing from the header.";
        }
    }

    my %seen_sample_ids;
    my %seen_source_observation_unit_names;
    my %seen_well_numbers;
    my %seen_facility_identifiers;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $date;
        my $sample_id;
        my $well_A01;
        my $row_val;
        my $column;
        my $source_observation_unit_name;
        my $ncbi_taxonomy_id;
        my $dna_person;
        my $notes;
        my $tissue_type;
        my $extraction;
        my $concentration;
        my $volume;
        my $is_blank;
        my $facility_identifier;

        if ($worksheet->get_cell($row,0)) {
            $date  = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $sample_id  = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $well_A01  = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $row_val  = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $column  = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $source_observation_unit_name  = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $ncbi_taxonomy_id  = $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $dna_person  = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $notes  = $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $tissue_type  = $worksheet->get_cell($row,9)->value();
            $tissue_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $extraction  = $worksheet->get_cell($row,10)->value();
        }
        if ($worksheet->get_cell($row,11)) {
            $concentration = $worksheet->get_cell($row,11)->value();
        }
        if ($worksheet->get_cell($row,12)) {
            $volume = $worksheet->get_cell($row,12)->value();
        }
        if ($worksheet->get_cell($row,13)) {
            $is_blank = $worksheet->get_cell($row,13)->value();
            $is_blank =~ s/^\s+|\s+$//g;
        }
        if ($include_facility_identifiers) {
            if ($worksheet->get_cell($row,14)) {
                $facility_identifier = $worksheet->get_cell($row,14)->value();
            }
        }

        #skip blank lines
        if (!$date && !$sample_id && !$well_A01 && !$source_observation_unit_name) {
            next;
        }

        #sample_id must not be blank
        if (!$sample_id || $sample_id eq '' ) {
            push @error_messages, "Cell B$row_name: sample_id missing.";
        }
        elsif ($sample_id =~ /\s/ || $sample_id =~ /\// || $sample_id =~ /\\/ ) {
            push @error_messages, "Cell B$row_name: sample_id name must not contain spaces or slashes.";
        }
        else {
            #file must not contain duplicate sample_id
            $sample_id =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            if ($seen_sample_ids{$sample_id}) {
                push @error_messages, "Cell B$row_name: duplicate sample_id at cell B".$seen_sample_ids{$sample_id}.": $sample_id";
            }
            $seen_sample_ids{$sample_id}=$row_name;
        }

        #source_observation_unit_name name must exist in the database
        if ($source_observation_unit_name){
            $source_observation_unit_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_source_observation_unit_names{$source_observation_unit_name}++;
        }

        #well_A01 must not be blank
        if (!$well_A01 || $well_A01 eq '') {
            push @error_messages, "Cell C$row_name: well_A01 missing";
        } else {
            $well_A01 =~ s/^\s+|\s+$//g;
        }
        #well A01 must be unique in file
        if (exists($seen_well_numbers{$well_A01})){
            push @error_messages, "Cell C$row_name: well_A01 must be unique in your file. You already used this plot number in C".$seen_well_numbers{$well_A01};
        } else {
            $seen_well_numbers{$well_A01} = $row_name;
        }

        #row must not be blank
        if (!$row_val || $row_val eq '') {
            push @error_messages, "Cell D$row_name: row missing";
        }
        #column must not be blank
        if (!$column || $column eq '') {
            push @error_messages, "Cell E$row_name: column missing";
        }
        #date must not be blank
        if (!$date || $date eq '') {
            push @error_messages, "Cell A$row_name: date missing";
        } elsif (!$date =~ m/(\d{4})-(\d{2})-(\d{2})/) {
            push @error_messages, "Cell A$row_name: date must be YYYY-MM-DD format";
        }

        if ($is_blank) {
            if (!($is_blank eq "1" || $is_blank eq "0" || $is_blank eq '')) {
                push @error_messages, "Cell M$row_name: is_blank is not either 1, 0, or blank: $is_blank";
            }
        }
        #tissue_type must not be blank and must be either leaf, root, stem, seed, fruit, tuber
        if (!$tissue_type || $tissue_type eq '' || ($tissue_type ne 'leaf' && $tissue_type ne 'root' && $tissue_type ne 'stem' && $tissue_type ne 'seed' && $tissue_type ne 'fruit' && $tissue_type ne 'tuber')) {
            push @error_messages, "Cell E$row_name: column tissue type and must be either stem, leaf, root, seed, fruit or tuber";
        }

        if ($include_facility_identifiers) {
            if (!$facility_identifier || ($facility_identifier eq '')) {
                push @error_messages, "Cell O$row_name: facility_identifier is misssing";
            } else {
                $facility_identifier =~ s/^\s+|\s+$//g;

                if ($seen_facility_identifiers{$facility_identifier}) {
                    push @error_messages, "Cell O$row_name: duplicate facility identifier at cell O".$seen_facility_identifiers{$facility_identifier}.": $facility_identifier";
                }

                $seen_facility_identifiers{$facility_identifier}=$row_name;
            }
        }

    }

    my @sample_ids = keys %seen_sample_ids;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@sample_ids }
    });
    while (my $r=$rs->next){
        push @error_messages, "Cell B".$seen_sample_ids{$r->uniquename}.": sample_id already exists: ".$r->uniquename;
    }

    if ($include_facility_identifiers) {
        my $facility_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'facility_identifier', 'stock_property')->cvterm_id();
        my @identifiers = keys %seen_facility_identifiers;
        my $identifier_rs = $schema->resultset("Stock::Stockprop")->search({
            'type_id' => $facility_identifier_type_id,
            'value' => { -in => \@identifiers }
        });
        while (my $each_id=$identifier_rs->next){
            push @error_messages, "Cell O".$seen_facility_identifiers{$each_id->value}.": facility identifier already exists: ".$each_id->value;
        }
    }

    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id;
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
    my @seen_source_observation_unit_names = keys %seen_source_observation_unit_names;
    $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seen_source_observation_unit_names },
        'type_id' => [$tissue_sample_cvterm_id, $plant_cvterm_id, $plot_cvterm_id, $accession_cvterm_id]
    });
    my %found_source_observation_unit_names;
    while (my $r=$rs->next){
        $found_source_observation_unit_names{$r->uniquename} = 1;
    }
    foreach (@seen_source_observation_unit_names){
        if (!$found_source_observation_unit_names{$_}){
            push @error_messages, "This source observation unit name is not in the database: $_ .";
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
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $include_facility_identifiers = $self->get_facility_identifiers_included();

    # Match a dot, followed by any number of non-dots until the
    # end of the line.
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
    my %design;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $date;
        my $sample_id;
        my $well_A01;
        my $row_val;
        my $column;
        my $source_observation_unit_name;
        my $ncbi_taxonomy_id;
        my $dna_person;
        my $notes;
        my $tissue_type;
        my $extraction;
        my $concentration;
        my $volume;
        my $is_blank;
        my $facility_identifier;

        if ($worksheet->get_cell($row,0)) {
            $date  = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $sample_id  = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $well_A01  = $worksheet->get_cell($row,2)->value();
            $well_A01 =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $row_val  = $worksheet->get_cell($row,3)->value();
            $row_val =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $column  = $worksheet->get_cell($row,4)->value();
            $column =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $source_observation_unit_name  = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $ncbi_taxonomy_id  = $worksheet->get_cell($row,6)->value();
            $ncbi_taxonomy_id =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,7)) {
            $dna_person  = $worksheet->get_cell($row,7)->value();
            $dna_person =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,8)) {
            $notes  = $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $tissue_type  = $worksheet->get_cell($row,9)->value();
            $tissue_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $extraction  = $worksheet->get_cell($row,10)->value();
            $extraction =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,11)) {
            $concentration = $worksheet->get_cell($row,11)->value();
            $concentration =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,12)) {
            $volume = $worksheet->get_cell($row,12)->value();
            $volume =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,13)) {
            $is_blank = $worksheet->get_cell($row,13)->value();
            $is_blank =~ s/^\s+|\s+$//g;
        }
        if ($include_facility_identifiers) {
            if ($worksheet->get_cell($row,14)) {
                $facility_identifier = $worksheet->get_cell($row,14)->value();
                $facility_identifier =~ s/^\s+|\s+$//g;
            }
        }

        #skip blank lines
        if (!$date && !$sample_id && !$well_A01 && !$source_observation_unit_name) {
            next;
        }

        if($is_blank){
            $source_observation_unit_name = 'BLANK';
        }

        $sample_id =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $source_observation_unit_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        my $key = $row;
        $design{$key}->{date} = $date;
        $design{$key}->{sample_id} = $sample_id;
        $design{$key}->{well} = $well_A01;
        $design{$key}->{row} = $row_val;
        $design{$key}->{column} = $column;
        $design{$key}->{source_stock_uniquename} = $source_observation_unit_name;
        $design{$key}->{ncbi_taxonomy_id} = $ncbi_taxonomy_id;
        $design{$key}->{dna_person} = $dna_person;
        $design{$key}->{notes} = $notes;
        $design{$key}->{tissue_type} = $tissue_type;
        $design{$key}->{extraction} = $extraction;
        $design{$key}->{concentration} = $concentration;
        $design{$key}->{volume} = $volume;
        if ($is_blank) {
            $design{$key}->{is_blank} = 1;
        } else {
            $design{$key}->{is_blank} = 0;
        }
        if ($include_facility_identifiers) {
            $design{$key}->{facility_identifier} = $facility_identifier;
        }
    }

    #print STDERR Dumper \%design;
    $self->_set_parsed_data(\%design);

    return 1;
}


1;
