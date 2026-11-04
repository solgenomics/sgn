
package CXGN::Phenotypes::ParseUpload::Plugin::FieldBook;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '2015-06-16T00:53:26Z', 'person1', '']
#           varname2 => [120, '', 'person2', '']
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
use File::Slurp;
use Text::CSV;
use Data::Dumper;
use JSON qw(decode_json);

sub name {
    return "field book";
}

sub validate {
    my $self = shift;
    my SGN::I18N $ui_validate_i18n = SGN::I18N::translate($c);
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;

    my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    my ($extension) = $filename =~/(\.[^.]+)$/;
    my $parser;
    my $excel_obj;
    my $worksheet;
    my @file_lines;
   
    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    
        $excel_obj = $parser->parse($filename);
        if (!$excel_obj) {
            $parse_result{'error'} = $parser->error();
            return \%parse_result;
        }
        $worksheet = ( $excel_obj->worksheets() )[0];
        my ( $row_min, $row_max ) = $worksheet->row_range();
        my ( $col_min, $col_max ) = $worksheet->col_range();

        for my $row ($row_min .. $row_max) {
            my @cells;
            for my $col ($col_min .. $col_max ) {
                my $cell = $worksheet->get_cell($row, $col);
                push @cells, $cell ? $cell->value() : '';
            }
            push @file_lines, join(",", map {
                my $v = $_ // '';
                $v =~ s/"/""/g;
                qq("$v");
            } @cells);
        }
    } else {
        ## Check that the file can be read
        @file_lines = read_file($filename);
    }

    # fix DOS-style line-endings!!!
    #
    foreach my $fl (@file_lines) {
	$fl =~ s/\r//g;
    }

    if (!@file_lines) {
        $parse_result{'error_detail'} = { code => 'unreadable', variables => {} };
        $parse_result{'error'} = SGN::I18N::translate($ui_validate_i18n, "phenotype_upload.fieldbook_error.unreadable", "Could not read file.");
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }
    ## Check that the file has at least 2 lines;
    if (scalar(@file_lines < 2)) {
        $parse_result{'error_detail'} = { code => 'too_short', variables => {} };
        $parse_result{'error'} = SGN::I18N::translate($ui_validate_i18n, "phenotype_upload.fieldbook_error.too_short", "File has less than 2 lines.");
        print STDERR "File has less than 2 lines.\n";
        return \%parse_result;
    }

    my $header = shift(@file_lines);
    my $status = $csv->parse($header);
    my @header_row = $csv->fields();

    if (!$header_row[1]) {
        $parse_result{'error_detail'} = { code => 'no_header', variables => {} };
        $parse_result{'error'} = SGN::I18N::translate($ui_validate_i18n, "phenotype_upload.fieldbook_error.no_header", "File has no header row.");
        print STDERR "File has no header row.\n";
        return \%parse_result;
    }

    # Define possible unit headers for each data level
    my %unit_headers = (
        plots    => [qw(plot_id plot_name ObservationUnitDbId ObservationUnitName)],
        plants   => [qw(plant_name ObservationUnitName)],
        subplots => [qw(subplot_name ObservationUnitName)],
        tissue_samples => [qw(tissue_sample_name ObservationUnitName)],
    );

    my %header_column_info;
    my $header_column_number = 0;
    my $unit_col;
    foreach my $header_cell (@header_row) {
        # $header_cell =~ s/\"//g; #substr($header_cell,1,-1);  #remove double quotes

        if ($header_cell eq "trait") {
            $header_column_info{'trait'} = $header_column_number;
        }
        if ($header_cell eq "value") {
            $header_column_info{'value'} = $header_column_number;
        }
        if ($header_cell eq "timestamp") {
            $header_column_info{'timestamp'} = $header_column_number;
        }
        if ($header_cell eq "person") {
            $header_column_info{'person'} = $header_column_number;
        }
        foreach my $possible_unit_col (@{ $unit_headers{$data_level} }) {
            if ($header_cell eq $possible_unit_col) {
                $header_column_info{$possible_unit_col} = $header_column_number;
                $unit_col = $possible_unit_col unless defined $unit_col; # prefer first match
            }
        }
        $header_column_number++;
    }

    if (!defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
        $parse_result{'error_detail'} = { code => 'missing_trait_value', variables => {} };
        $parse_result{'error'} = SGN::I18N::translate($ui_validate_i18n, "phenotype_upload.fieldbook_error.missing_trait_value", "trait or value column not found. Make sure to use the database Fieldbook format.");
        print STDERR "trait or value column not found. Make sure to use the database Fieldbook format.";
        return \%parse_result;
    }

    return 1;
}

sub parse {
    my $self = shift;
    my SGN::I18N $ui_parse_i18n = SGN::I18N::translate($c);
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $user_id = shift; #not relevant for this plugin
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;
    my @file_lines;
    my $header;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %units_seen;
    my %traits_seen;
    my @units;
    my @traits;
    my %data;

    my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    my ($extension) = $filename =~/(\.[^.]+)$/;
    my $parser;
    my $excel_obj;
    my $worksheet;
    my @file_lines;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();

        $excel_obj = $parser->parse($filename);
        if (!$excel_obj) {
            $parse_result{'error'} = $parser->error();
            return \%parse_result;
        }

        $worksheet = ( $excel_obj->worksheets() )[0];
        my ( $row_min, $row_max ) = $worksheet->row_range();
        my ( $col_min, $col_max ) = $worksheet->col_range();

        for my $row ($row_min .. $row_max) {
            my @cells;
            for my $col ($col_min .. $col_max ) {
                my $cell = $worksheet->get_cell($row, $col);
                push @cells, $cell ? $cell->value() : '';
            }
            push @file_lines, join(",", map {
                my $v = $_ // '';
                $v =~ s/"/""/g;
                qq("$v");
            } @cells);
        }
    } else {
        ## Check that the file can be read
        @file_lines = read_file($filename);
    }

    # fix DOS-style line-endings!!!
    #
    foreach my $fl (@file_lines) {
	$fl =~ s/\r//g;
    }

    $header = shift(@file_lines);
    my $status  = $csv->parse($header);
    my @header_row = $csv->fields();

    # Define possible unit headers for each data level
    my %unit_headers = (
        plots    => [qw(plot_id plot_name ObservationUnitDbId ObservationUnitName)],
        plants   => [qw(plant_id plant_name ObservationUnitDbId ObservationUnitName)],
        subplots => [qw(subplot_id subplot_name ObservationUnitDbId ObservationUnitName)],
        tissue_samples => [qw(tissue_sample_id tissue_sample_name ObservationUnitDbId ObservationUnitName)],
    );

    my $header_column_number = 0;
    my $unit_col;
    foreach my $header_cell (@header_row) {
        if ($header_cell eq "trait") {
            $header_column_info{'trait'} = $header_column_number;
        }
        if ($header_cell eq "value") {
            $header_column_info{'value'} = $header_column_number;
        }
        if ($header_cell eq "timestamp") {
            $header_column_info{'timestamp'} = $header_column_number;
        }
        if ($header_cell eq "person") {
            $header_column_info{'person'} = $header_column_number;
        }
        foreach my $possible_unit_col (@{ $unit_headers{$data_level} }) {
            if ($header_cell eq $possible_unit_col) {
                $header_column_info{$possible_unit_col} = $header_column_number;
                $unit_col = $possible_unit_col unless defined $unit_col; # prefer first match
            }
        }
        $header_column_number++;
    }
    
    if (!defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
        $parse_result{'error_detail'} = { code => 'missing_trait_value', variables => {} };
        $parse_result{'error'} = SGN::I18N::translate($ui_parse_i18n, "phenotype_upload.fieldbook_error.missing_trait_value", "trait or value column not found. Make sure to use the database Fieldbook format.");
        return \%parse_result;
    }



    for my $index (0..$#file_lines) {
        my $line = $file_lines[$index];
        my $line_number = $index + 2;
        my $status = $csv->parse($line);
        my @row = $csv->fields();

        my $unit_value = $row[$header_column_info{$unit_col}];
        my $trait = $row[$header_column_info{'trait'}];
        my $value = _normalize_fieldbook_value($row[$header_column_info{'value'}]);
        my $timestamp = defined $header_column_info{'timestamp'} ? $row[$header_column_info{'timestamp'}] : '';
        my $collector = defined $header_column_info{'person'} ? $row[$header_column_info{'person'}] : '';

        if (!defined($unit_value) || !defined($trait) || !defined($value) || !defined($timestamp)) {
            $parse_result{'error_detail'} = { code => 'undefined_fields', variables => { line => $line_number } };
            $parse_result{'error'} = SGN::I18N::translate($ui_parse_i18n, "collection.server.error_parsing_line_line_number_unit_trait_or_value", "Error parsing line %{line_number}: unit, trait, or value is undefined.", {line_number => ("" . ($line_number))});
            return \%parse_result;
        }
        if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
            $parse_result{'error_detail'} = { code => 'timestamp_format', variables => { line => $line_number } };
            $parse_result{'error'} = SGN::I18N::translate($ui_parse_i18n, "collection.server.error_parsing_line_line_number_timestamp_needs_to_be", "Error parsing line %{line_number}: timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000", {line_number => ("" . ($line_number))});
            print STDERR "line $line_number has timestamp: $timestamp\n";
            return \%parse_result;
        }


        if ($unit_col =~ /id/i) { # convert ids to names
            my $row = $schema->resultset("Stock::Stock")->find({ stock_id => $unit_value });
            if ($row) {
                $unit_value = $row->uniquename();
            } else {
                $parse_result{'error_detail'} = { code => 'missing_stock', variables => { stock_id => $unit_value } };
                $parse_result{'error'} = SGN::I18N::translate($ui_parse_i18n, "collection.server.error_stock_id_unit_value_does_not_exist_in", "Error: stock id %{unit_value} does not exist in the database.", {unit_value => ("" . ($unit_value))})
            }
        }

        $units_seen{$unit_value} = 1;
        $traits_seen{$trait} = 1;

        if (defined($value) && defined($timestamp)) {
	    print STDERR "KEEPING $trait with value $value for stock $unit_value...\n";
            push @{$data{$unit_value}->{$trait}}, [$value, $timestamp, $collector, ''];
        }
	else {
	    print STDERR "PROBLEM WITH value $value or TIMESTAMP $timestamp\n";
	}

     #   $data{$unit_value}->{$trait} = [$value, $timestamp, $collector, ''];

    }

    foreach my $unit (sort keys %units_seen) {
        push @units, $unit;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@units;
    $parse_result{'variables'} = \@traits;

    return \%parse_result;
}

sub _normalize_fieldbook_value {
    my $value = shift;
    return $value if !defined($value) || $value !~ /^\s*[\[\{]/;

    my $decoded = eval { decode_json($value) };
    return $value if $@;

    if (ref($decoded) eq "ARRAY") {
        my @values = map { _fieldbook_json_value($_) } @$decoded;
        @values = grep { defined($_) && $_ ne "" } @values;
        return @values ? join(":", @values) : "";
    }

    my $decoded_value = _fieldbook_json_value($decoded);
    return defined($decoded_value) ? $decoded_value : $value;
}

sub _fieldbook_json_value {
    my $entry = shift;
    return if !defined($entry);

    if (ref($entry) eq "HASH") {
        return $entry->{value} if defined($entry->{value});
        return $entry->{label} if defined($entry->{label});
        return;
    }

    return ref($entry) ? undef : $entry;
}

1;
