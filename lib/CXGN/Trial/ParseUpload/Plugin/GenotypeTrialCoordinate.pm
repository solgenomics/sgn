package CXGN::Trial::ParseUpload::Plugin::GenotypeTrialCoordinate;

use Moose::Role;
use Text::CSV;
use CXGN::List::Validate;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $include_facility_identifiers = $self->get_facility_identifiers_included();
    my $delimiter = ',';
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $num_cols = scalar(@columns);
    if ($include_facility_identifiers){
        if ($num_cols != 12){
            push @error_messages, 'Header row must contain: "date","plate_id","plate_name","sample_id","well_A01","well_01A","tissue_id","dna_person","notes","tissue_type","extraction", "facility_identifier"';
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }
    } else {
        if ($num_cols != 11){
            push @error_messages, 'Header row must contain: "date","plate_id","plate_name","sample_id","well_A01","well_01A","tissue_id","dna_person","notes","tissue_type","extraction"';
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }
    }

    my $date_header = $columns[0];
    $date_header =~ s/^\s+|\s+$//g;
    my $plate_id_header = $columns[1];
    $plate_id_header =~ s/^\s+|\s+$//g;
    my $plate_name_header = $columns[2];
    $plate_name_header =~ s/^\s+|\s+$//g;
    my $sample_id_header = $columns[3];
    $sample_id_header =~ s/^\s+|\s+$//g;
    my $well_A01_header = $columns[4];
    $well_A01_header =~ s/^\s+|\s+$//g;
    my $well_01A_header = $columns[5];
    $well_01A_header =~ s/^\s+|\s+$//g;
    my $tissue_id_header = $columns[6];
    $tissue_id_header =~ s/^\s+|\s+$//g;
    my $dna_person_header = $columns[7];
    $dna_person_header =~ s/^\s+|\s+$//g;
    my $notes_header = $columns[8];
    $notes_header =~ s/^\s+|\s+$//g;
    my $tissue_type_header = $columns[9];
    $tissue_type_header =~ s/^\s+|\s+$//g;
    my $extraction_header = $columns[10];
    $extraction_header =~ s/^\s+|\s+$//g;
    my $facility_identifier_header;
    if ($include_facility_identifiers) {
        $facility_identifier_header = $columns[11];
        $facility_identifier_header =~ s/^\s+|\s+$//g;
    }

    if ($include_facility_identifiers) {
        if ( $date_header ne "date" ||
            $plate_id_header ne "plate_id" ||
            $plate_name_header ne "plate_name" ||
            $sample_id_header ne "sample_id" ||
            $well_A01_header ne "well_A01" ||
            $well_01A_header ne "well_01A" ||
            $tissue_id_header ne "tissue_id" ||
            $dna_person_header ne "dna_person" ||
            $notes_header ne "notes" ||
            $tissue_type_header ne "tissue_type" ||
            $extraction_header ne "extraction" ||
            $facility_identifier_header ne "facility_identifier") {
            push @error_messages, 'File contents incorrect. Header row must contain: "date","plate_id","plate_name","sample_id","well_A01","well_01A","tissue_id","dna_person","notes","tissue_type","extraction", "facility_identifier"';
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }
    } else {
            if ( $date_header ne "date" ||
                $plate_id_header ne "plate_id" ||
                $plate_name_header ne "plate_name" ||
                $sample_id_header ne "sample_id" ||
                $well_A01_header ne "well_A01" ||
                $well_01A_header ne "well_01A" ||
                $tissue_id_header ne "tissue_id" ||
                $dna_person_header ne "dna_person" ||
                $notes_header ne "notes" ||
                $tissue_type_header ne "tissue_type" ||
                $extraction_header ne "extraction" ) {
                push @error_messages, 'File contents incorrect. Header row must contain: "date","plate_id","plate_name","sample_id","well_A01","well_01A","tissue_id","dna_person","notes","tissue_type","extraction"';
                $errors{'error_messages'} = \@error_messages;
                $self->_set_parse_errors(\%errors);
                return;
            }
        }

    my %seen_sample_ids;
    my %seen_source_names;
    my %seen_facility_identifiers;

    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        if (scalar(@columns) != $num_cols){
            push @error_messages, 'All lines must have same number of columns as header! Error on row: '.$row;
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        if (!$columns[0] || $columns[0] eq ''){
            push @error_messages, 'The first column must contain a date on row: '.$row;
        } elsif (!$columns[0] =~ m/(\d{4})-(\d{2})-(\d{2})/) {
            push @error_messages, "Date must be YYYY-MM-DD format";
        }
        if (!$columns[1] || $columns[1] eq ''){
            push @error_messages, 'The second column must contain a plate_id on row: '.$row;
        }
        if (!$columns[2] || $columns[2] eq ''){
            push @error_messages, 'The third column must contain an plate_name on row: '.$row;
        }
        if (!$columns[3] || $columns[3] eq ''){
            push @error_messages, 'The fourth column must contain an sample_id on row: '.$row;
        } else {
            if ($columns[3] =~ /\s/ || $columns[3] =~ /\// || $columns[3] =~ /\\/ ) {
                push @error_messages, "Row: $row: sample_id name must not contain spaces or slashes.";
            }
            if ($seen_sample_ids{$columns[3]}){
                push @error_messages, 'Duplicate sample_id in your file on row: '.$row;
            }
            $seen_sample_ids{$columns[3]} = $row;
        }
        if (!$columns[4] || $columns[4] eq ''){
            push @error_messages, 'The fifth column must contain well_A01 on row: '.$row;
        }
        if (!$columns[5] || $columns[5] eq ''){
            push @error_messages, 'The sixth column must contain well_01A on row: '.$row;
        }
        if (!$columns[6] || $columns[6] eq ''){
            push @error_messages, 'The seventh column must contain tissue_id on row: '.$row;
        } else {
            my $source_name = $columns[6];
            $source_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            if (index($source_name, 'BLANK') != -1) {
                $source_name = 'BLANK';
            }
            $seen_source_names{$source_name}++;
        }
        if (!$columns[7] || $columns[7] eq ''){
            push @error_messages, 'The seventh column must contain dna_person on row: '.$row;
        }
        if (!$columns[9] || $columns[9] eq '' || ($columns[9] ne 'leaf' && $columns[9] ne 'root' && $columns[9] ne 'stem')){
            push @error_messages, 'The tenth column must contain tissue type of either leaf, root, or stem on row: '.$row;
        }
        if ($include_facility_identifiers) {
            if (!$columns[11] || $columns[11] eq ''){
                push @error_messages, 'The twelfth column must contain facility identifier on row: '.$row;
            } else {
                if ($seen_facility_identifiers{$columns[11]}){
                    push @error_messages, 'Duplicate facility identifier in your file on row: '.$row;
                }
                $seen_facility_identifiers{$columns[11]} = $row;
            }
        }
    }

    my @sample_ids = keys %seen_sample_ids;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@sample_ids }
    });
    while (my $r=$rs->next){
        push @error_messages, "Row".$seen_sample_ids{$r->uniquename}.": sample_id already exists: ".$r->uniquename;
    }

    if ($include_facility_identifiers) {
        my $facility_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'facility_identifier', 'stock_property')->cvterm_id();
        my @identifiers = keys %seen_facility_identifiers;
        my $identifier_rs = $schema->resultset("Stock::Stockprop")->search({
            'type_id' => $facility_identifier_type_id,
            'value' => { -in => \@identifiers }
        });
        while (my $each_id=$identifier_rs->next){
            push @error_messages, "Row".$seen_facility_identifiers{$each_id->value}.": facility identifier already exists: ".$each_id->value;
        }
    }

    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id;
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
    my @seen_source_observation_unit_names = keys %seen_source_names;
    $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seen_source_observation_unit_names },
        'type_id' => [$tissue_sample_cvterm_id, $plant_cvterm_id, $plot_cvterm_id, $subplot_cvterm_id, $accession_cvterm_id]
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
    print STDERR "Parsing genotype trial file upload\n";
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $include_facility_identifiers = $self->get_facility_identifiers_included();
    my $delimiter = ',';
    my %parse_result;
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my $num_cols = scalar(@header_columns);

    my %seen_seedlot_names;
    my %design;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        my $date = $columns[0];
        my $plate_id = $columns[1];
        my $plate_name = $columns[2];
        my $sample_id = $columns[3];
        my $well_A01 = $columns[4];
        my $well_01A = $columns[5];
        my $source_name = $columns[6];
        my $dna_person = $columns[7];
        my $notes = $columns[8];
        my $tissue_type = $columns[9];
        my $extraction = $columns[10];
        $source_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        my $facility_identifier;
        if ($include_facility_identifiers) {
            $facility_identifier = $columns[11];
            $facility_identifier =~ s/^\s+|\s+$//g;
        }

        my $key = $row;
        if (index($source_name, 'BLANK') != -1) {
            $source_name = 'BLANK';
            $design{$key}->{is_blank} = 1;
        } else {
            $design{$key}->{is_blank} = 0;
        }

        $design{$key}->{date} = $date;
        $design{$key}->{sample_id} = $sample_id;
        $design{$key}->{well} = $well_A01;

        my $row_number = substr $well_A01, 0, 1;
        my $col_number = substr $well_A01, 1, 2;

        $design{$key}->{row} = $row_number;
        $design{$key}->{column} = $col_number;
        $design{$key}->{source_stock_uniquename} = $source_name;
        $design{$key}->{ncbi_taxonomy_id} = 'NA';
        $design{$key}->{dna_person} = $dna_person;
        $design{$key}->{notes} = $notes;
        $design{$key}->{tissue_type} = $tissue_type;
        $design{$key}->{extraction} = $extraction;
        $design{$key}->{concentration} = 'NA';
        $design{$key}->{volume} = 'NA';
        if ($include_facility_identifiers) {
            $design{$key}->{facility_identifier} = $facility_identifier;
        }
    }

#    print STDERR "UPLOADED DESIGN =".Dumper(\%design)."\n";
    $self->_set_parsed_data(\%design);

    return 1;
}


1;
