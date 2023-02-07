package CXGN::Phenotypes::ParseUpload::Plugin::AnalysisPhenotypeSpreadsheetCSV;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '2015-06-16T00:53:26Z']
#           varname2 => [120, '']
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
use JSON;
use Data::Dumper;
use Text::CSV;
use CXGN::List::Validate;

sub name {
    return "analysis phenotype spreadsheet csv";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }

    my $num_cols = scalar(@columns);
    if ($num_cols < 2){
        $parse_result{'error'} = 'Header row must contain:  "stock_names" followed by at least one trait.';
        print STDERR "Incorrect header.\n";
        return \%parse_result;
    }

    my $stock_names_header = $columns[0];
    $stock_names_header =~ s/^\s+|\s+$//g;

    if ( $stock_names_header ne "stock_names" ) {
            $parse_result{'error'} = 'File contents incorrect. Header row must contain: "stock_names" followed by all measured traits.';
            print STDERR "File contents incorrect.\n";
            return \%parse_result;
    }

    my %seen_trait_names;
    foreach (1..scalar(@columns)-1) {
        $seen_trait_names{$columns[$_]}++;
    }

    my $num_col_before_traits = 1;
    my %seen_stock_names;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            $parse_result{'error'} = "Could not parse row $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        if (scalar(@columns) != $num_cols){
            $parse_result{'error'} = 'All lines must have same number of columns as header! Error on row: '.$row;
            print STDERR "Line $row does not have complete columns.\n";
            return \%parse_result;
        }

        my $stock_name = $columns[0];
        $stock_name =~ s/^\s+|\s+$//g;
        $seen_stock_names{$stock_name}++;

        for my $col_num ($num_col_before_traits .. $num_cols-1) {
            my $value_string = $columns[$col_num];
            #print STDERR $value_string."\n";
            if ($timestamp_included) {
                my ($value, $timestamp) = split /,/, $value_string;
                if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                    $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
                    print STDERR "value: $timestamp\n";
                    return \%parse_result;
                }
            }
        }
    }

    my @stocks = keys %seen_stock_names;
    my $stocks_validator = CXGN::List::Validate->new();
    my @stocks_missing = @{$stocks_validator->validate($schema,$data_level.'s',\@stocks)->{'missing'}};

    if (scalar(@stocks_missing) > 0) {
        $parse_result{'missing_stocks'} = \@stocks_missing;
        $parse_result{'error'} = "The following stocks are not in the database as uniquenames or synonyms: ".join(',',@stocks_missing);
        return \%parse_result;
    }

    my @traits = keys %seen_trait_names;
    my $traits_validator = CXGN::List::Validate->new();
    my @traits_missing = @{$traits_validator->validate($schema,'traits',\@traits)->{'missing'}};

    if (scalar(@traits_missing) > 0) {
        $parse_result{'missing_traits'} = \@traits_missing;
        $parse_result{'error'} = "The following traits are not in the database: ".join(',',@traits_missing);
        return \%parse_result;
    }

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $user_id = shift; #not relevant for this plugin
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %observation_units_seen;
    my %traits_seen;
    my @observation_units;
    my @traits;
    my %data;

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header row.\n";
        return \%parse_result;
    }
    my $num_cols = scalar(@header_columns);

    my $num_col_before_traits = 1;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            $parse_result{'error'} = "Could not parse row $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        my $observation_unit_name = $columns[0];
        $observation_unit_name =~ s/^\s+|\s+$//g;
        $observation_units_seen{$observation_unit_name} = 1;

        for my $col_num ($num_col_before_traits .. $num_cols-1) {

            my $trait_name = $header_columns[$col_num];
            if ($trait_name) {
                $trait_name =~ s/^\s+|\s+$//g;
                $traits_seen{$trait_name} = 1;
                my $value_string = '';
                if ($columns[$col_num]){
                    $value_string = $columns[$col_num];
                }
                #print STDERR $value_string."\n";
                my $timestamp = '';
                my $value = '';
                if ($timestamp_included){
                    ($value, $timestamp) = split /,/, $value_string;
                } else {
                    $value = $value_string;
                }
                if (!defined($timestamp)){
                    $timestamp = '';
                }
                #print STDERR $trait_value." : ".$timestamp."\n";

                if ( defined($value) && defined($timestamp) ) {
                    if ($value ne '.'){
                        $data{$observation_unit_name}->{$trait_name} = [$value, $timestamp];
                    }
                } else {
                    $parse_result{'error'} = "Value or timestamp missing.";
                    return \%parse_result;
                }
            }
        }

    }

    foreach my $p (sort keys %observation_units_seen) {
        push @observation_units, $p;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@observation_units;
    $parse_result{'variables'} = \@traits;
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;
