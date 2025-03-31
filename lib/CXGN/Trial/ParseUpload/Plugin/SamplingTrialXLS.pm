package CXGN::Trial::ParseUpload::Plugin::SamplingTrialXLS;

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
    my %errors;
    my @error_messages;
    my %missing_accessions;

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
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
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
    my $sample_name_head;
    my $source_observation_unit_name_head;
    my $sample_number_head;
    my $replicate_head;
    my $tissue_type_head;
    my $ncbi_taxonomy_id_head;
    my $person_head;
    my $notes_head;
    my $extraction_head;
    my $concentration_head;
    my $volume_head;

    if ($worksheet->get_cell(0,0)) {
        $date_head  = $worksheet->get_cell(0,0)->value();
        $date_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $sample_name_head  = $worksheet->get_cell(0,1)->value();
        $sample_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $source_observation_unit_name_head  = $worksheet->get_cell(0,2)->value();
        $source_observation_unit_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $sample_number_head  = $worksheet->get_cell(0,3)->value();
        $sample_number_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $replicate_head  = $worksheet->get_cell(0,4)->value();
        $replicate_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $tissue_type_head  = $worksheet->get_cell(0,5)->value();
        $tissue_type_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $ncbi_taxonomy_id_head  = $worksheet->get_cell(0,6)->value();
        $ncbi_taxonomy_id_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
        $person_head  = $worksheet->get_cell(0,7)->value();
        $person_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,8)) {
        $notes_head  = $worksheet->get_cell(0,8)->value();
        $notes_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,9)) {
        $extraction_head  = $worksheet->get_cell(0,9)->value();
        $extraction_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,10)) {
        $concentration_head  = $worksheet->get_cell(0,10)->value();
        $concentration_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,11)) {
        $volume_head  = $worksheet->get_cell(0,11)->value();
        $volume_head =~ s/^\s+|\s+$//g;
    }

    if (!$date_head || $date_head ne 'date' ) {
        push @error_messages, "Cell A1: date is missing from the header";
    }
    if (!$sample_name_head || $sample_name_head ne 'sample_name') {
        push @error_messages, "Cell B1: sample_name is missing from the header";
    }
    if (!$source_observation_unit_name_head || $source_observation_unit_name_head ne 'source_observation_unit_name') {
        push @error_messages, "Cell C1: source_observation_unit_name is missing from the header.";
    }
    if (!$sample_number_head || $sample_number_head ne 'sample_number') {
        push @error_messages, "Cell D1: sample_number is missing from the header.";
    }
    if (!$replicate_head || $replicate_head ne 'replicate') {
        push @error_messages, "Cell E1: replicate is missing from the header.";
    }
    if (!$tissue_type_head || $tissue_type_head ne 'tissue_type') {
        push @error_messages, "Cell F1: tissue_type is missing from the header.";
    }
    if (!$ncbi_taxonomy_id_head || $ncbi_taxonomy_id_head ne 'ncbi_taxonomy_id') {
        push @error_messages, "Cell G1: ncbi_taxonomy_id is missing from the header. (Header is required, but values are optional)";
    }
    if (!$person_head || $person_head ne 'person') {
        push @error_messages, "Cell H1: person is missing from the header. (Header is required, but values are optional)";
    }
    if (!$notes_head || $notes_head ne 'notes') {
        push @error_messages, "Cell I1: notes is missing from the header. (Header is required, but values are optional)";
    }
    if (!$extraction_head || $extraction_head ne 'extraction') {
        push @error_messages, "Cell J1: extraction is missing from the header. (Header is required, but values are optional)";
    }
    if (!$concentration_head || $concentration_head ne 'concentration') {
        push @error_messages, "Cell K1: concentration is missing from the header. (Header is required, but values are optional)";
    }
    if (!$volume_head || $volume_head ne 'volume') {
        push @error_messages, "Cell L1: volume is missing from the header. (Header is required, but values are optional)";
    }

    my %seen_sample_ids;
    my %seen_source_observation_unit_names;
    my %seen_sample_numbers;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $date;
        my $sample_name;
        my $source_observation_unit_name;
        my $sample_number;
        my $replicate;
        my $tissue_type;
        my $ncbi_taxonomy_id;
        my $person;
        my $notes;
        my $extraction;
        my $concentration;
        my $volume;

        if ($worksheet->get_cell($row,0)) {
            $date  = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $sample_name  = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $source_observation_unit_name  = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $sample_number  = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $replicate  = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $tissue_type  = $worksheet->get_cell($row,5)->value();
            $tissue_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $ncbi_taxonomy_id  = $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $person  = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $notes  = $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $extraction  = $worksheet->get_cell($row,9)->value();
        }
        if ($worksheet->get_cell($row,10)) {
            $concentration  = $worksheet->get_cell($row,10)->value();
        }
        if ($worksheet->get_cell($row,11)) {
            $volume  = $worksheet->get_cell($row,11)->value();
        }

        #skip blank lines
        if (!$date && !$sample_name && !$source_observation_unit_name && !$sample_number && !$replicate && !$tissue_type) {
            next;
        }

        if (!$sample_name || $sample_name eq '' ) {
            push @error_messages, "Cell B$row_name: sample_name missing.";
        }
        elsif ($sample_name =~ /\s/ || $sample_name =~ /\// || $sample_name =~ /\\/ ) {
            push @error_messages, "Cell B$row_name: sample_name name must not contain spaces or slashes.";
        }
        else {
            #file must not contain duplicate sample_id
            $sample_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            if ($seen_sample_ids{$sample_name}) {
                push @error_messages, "Cell B$row_name: duplicate sample_id at cell B".$seen_sample_ids{$sample_name}.": $sample_name";
            }
            $seen_sample_ids{$sample_name}=$row_name;
        }

        #source_observation_unit_name name must exist in the database
        if ($source_observation_unit_name){
            $source_observation_unit_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_source_observation_unit_names{$source_observation_unit_name}++;
        }

        #replicate must not be blank
        if (!$replicate || $replicate eq '') {
            push @error_messages, "Cell E$row_name: replicate missing";
        }
        if (!$sample_number || $sample_number eq '') {
            push @error_messages, "Cell D$row_name: sample_number missing";
        }
        #well A01 must be unique in file
        if (exists($seen_sample_numbers{$sample_number})){
            push @error_messages, "Cell D$row_name: sample_number must be unique in your file. You already used this sample_number in D".$seen_sample_numbers{$sample_number};
        } else {
            $seen_sample_numbers{$sample_number} = $row_name;
        }

        #date must not be blank
        if ( ($date || $date ne '') && !$date =~ m/(\d{4})-(\d{2})-(\d{2})/ ) {
            push @error_messages, "Cell A$row_name: date must be YYYY-MM-DD format";
        }

        #tissue_type must not be blank and must be either leaf, root, stem, fruit, seed, tuber
        if (!$tissue_type || $tissue_type eq '' || ($tissue_type ne 'leaf' && $tissue_type ne 'root' && $tissue_type ne 'stem' && $tissue_type ne 'fruit' && $tissue_type ne 'seed' && $tissue_type ne 'tuber' && $tissue_type ne 'sink leaf' && $tissue_type ne 'source leaf' && $tissue_type ne 'petiole' && $tissue_type ne 'apex' && $tissue_type ne 'upper stem (bulk)' && $tissue_type ne 'middle stem (bulk)' && $tissue_type ne 'middle stem core' && $tissue_type ne 'middle stem peel' && $tissue_type ne 'lower stem (bulk)' && $tissue_type ne 'lower stem core' && $tissue_type ne 'lower stem peel' && $tissue_type ne 'storage root' && $tissue_type ne 'storage root core' && $tissue_type ne 'storage root peel' && $tissue_type ne 'fibrous root')) {
            push @error_messages, "Cell F$row_name: column tissue type and must be either leaf, root, stem, seed, fruit, tuber, sink leaf, source leaf, petiole, apex, upper stem (bulk), middle stem (bulk), middle stem core, middle stem peel, lower stem (bulk), lower stem core, lower stem peel, storage root, storage root core, storage root peel, or fibrous root";
        }

    }

    my @sample_ids = keys %seen_sample_ids;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@sample_ids }
    });
    while (my $r=$rs->next){
        push @error_messages, "Cell B".$seen_sample_ids{$r->uniquename}.": sample_name already exists: ".$r->uniquename;
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
    print STDERR "Parsing sampling trial file upload\n";
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
        my $sample_name;
        my $source_observation_unit_name;
        my $sample_number;
        my $replicate;
        my $tissue_type;
        my $ncbi_taxonomy_id;
        my $person;
        my $notes;
        my $extraction;
        my $concentration;
        my $volume;

        if ($worksheet->get_cell($row,0)) {
            $date  = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $sample_name  = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $source_observation_unit_name  = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $sample_number  = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $replicate  = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $tissue_type  = $worksheet->get_cell($row,5)->value();
            $tissue_type =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $ncbi_taxonomy_id  = $worksheet->get_cell($row,6)->value();
            $ncbi_taxonomy_id =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,7)) {
            $person  = $worksheet->get_cell($row,7)->value();
            $person =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,8)) {
            $notes  = $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $extraction  = $worksheet->get_cell($row,9)->value();
            $extraction =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $concentration  = $worksheet->get_cell($row,10)->value();
        }
        if ($worksheet->get_cell($row,11)) {
            $volume  = $worksheet->get_cell($row,11)->value();
        }

        #skip blank lines
        if (!$date && !$sample_name && !$source_observation_unit_name && !$sample_number && !$replicate && !$tissue_type) {
            next;
        }

        $sample_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $source_observation_unit_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

        my $key = $row;
        $design{$key}->{date} = $date;
        $design{$key}->{sample_name} = $sample_name;
        $design{$key}->{source_stock_uniquename} = $source_observation_unit_name;
        $design{$key}->{sample_number} = $sample_number;
        $design{$key}->{replicate} = $replicate;
        $design{$key}->{tissue_type} = $tissue_type;
        $design{$key}->{ncbi_taxonomy_id} = $ncbi_taxonomy_id;
        $design{$key}->{person} = $person;
        $design{$key}->{notes} = $notes;
        $design{$key}->{extraction} = $extraction;
        $design{$key}->{concentration} = $concentration;
        $design{$key}->{volume} = $volume;
    }

    #print STDERR Dumper \%design;
    $self->_set_parsed_data(\%design);

    return 1;
}


1;
