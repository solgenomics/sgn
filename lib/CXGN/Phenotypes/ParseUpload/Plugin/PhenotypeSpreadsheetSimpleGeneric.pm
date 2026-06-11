package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimpleGeneric;

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
#use File::Slurp;
use CXGN::File::Parse;
use JSON;
use Data::Dumper;

my @oun_aliases = qw|plot_name subplot_name plant_name observationUnitName plotName subplotName plantName|;

sub _parse_measurements {
    my ($value_string, $timestamp_included) = @_;

    $value_string = '' unless defined $value_string;

    my @measurements;
    my @raw_measurements = $timestamp_included ? split(/\|/, $value_string) : ($value_string);

    for my $raw_measurement (@raw_measurements) {
        next unless defined $raw_measurement;

        my ($trait_value, $timestamp) = ('', '');
        if ($timestamp_included) {
            ($trait_value, $timestamp) = split /,/, $raw_measurement, 2;
        }
        else {
            $trait_value = $raw_measurement;
        }

        $trait_value = '' unless defined $trait_value;
        $timestamp = '' unless defined $timestamp;

        $trait_value =~ s/^\s+|\s+$//g;
        $timestamp =~ s/^\s+|\s+$//g;

        next if $trait_value eq '' || $trait_value eq '.';

        push @measurements, [ $trait_value, $timestamp ];
    }

    return \@measurements;
}

sub name {
    return "phenotype spreadsheet simple generic";
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

    # Open and read the file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => [ 'observationunit_name' ],
        column_aliases => {
            'observationunit_name' => [ 'plot_name', 'subplot_name', 'plant_name', 'observationUnitName', 'plotName', 'subplotName', 'plantName', 'observationUnitDbId' ]
        }
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_data = $parsed->{data};
    my $trait_columns = $parsed->{optional_columns};
    my %parse_result;

    # Return parsing error(s)
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $parse_result{'error'} = join(', ', @$parsed_errors);
        return \%parse_result;
    }

    # File has no traits
    if ( scalar(@$trait_columns) < 1 ) {
        $parse_result{'error'} = "Spreadsheet must have at least one trait in the header.";
        return \%parse_result;
    }

    # Check timestamp formats
    if ($timestamp_included) {
        foreach my $d (@$parsed_data) {
            foreach my $t (@$trait_columns) {
                my $value_string = $d->{$t};
                my $measurements = _parse_measurements($value_string, $timestamp_included);
                foreach my $measurement (@$measurements) {
                    my ($value, $timestamp) = @$measurement;
                    next if !$timestamp;
                    if ($timestamp !~ m/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:[+-]\d{4})?$/) {
                        $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
                        return \%parse_result;
                    }
                }
            }
        }
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

    # Try parsing with observationUnitDbId first
    my $parser = CXGN::File::Parse->new(
        file             => $filename,
        required_columns => ["observationunit_id"],
        column_aliases   => {
            'observationunit_id' => ['observationUnitDbId']
        }
    );
    my $parsed = $parser->parse();

    if ( $parsed->{errors} && scalar( @{ $parsed->{errors} } ) > 0 ) {

        # Fall back to name-based parsing
        $parser = CXGN::File::Parse->new(
            file             => $filename,
            required_columns => ["observationunit_name"],
            column_aliases   => {
                'observationunit_name' => [
                    'plot_name',    'subplot_name',
                    'plant_name',   'observationUnitName',
                    'plotName',     'subplotName',
                    'plantName'
                ]
            }
        );
        $parsed = $parser->parse();

        # If name-based also fails, return the errors
        if ( $parsed->{errors} && scalar( @{ $parsed->{errors} } ) > 0 ) {
            my %parse_result;
            $parse_result{'error'} =
              "File must have a plot name or observationUnitDbId column. Errors: "
              . join( ", ", @{ $parsed->{errors} } );
            return \%parse_result;
        }
    }

    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $trait_columns = $parsed->{optional_columns};
    my $columns = $parsed->{columns};

    my $observationunit_type;
    if ( grep { $_ eq 'observationunit_id' } @$columns ) {
        $observationunit_type = 'id';
    }
    elsif ( grep { $_ eq 'observationunit_name' } @$columns ) {
        $observationunit_type = 'name';
    }
    else {
        my %parse_result;
        $parse_result{'error'} =
          "File must have a plot name or observationUnitDbId column.";
        return \%parse_result;
    }

    print STDERR "obsunit type: $observationunit_type\n";

    # If IDs used, convert to uniquenames
    my %id_to_name;
    if ( $observationunit_type eq 'id' ) {

        # Collect all stock ids from the parsed data
        my @stock_ids =
          map  { $_->{'observationunit_id'} }
          grep { $_ && ref($_) eq 'HASH' && defined $_->{'observationunit_id'} }
          @$parsed_data;

        if ( !@stock_ids ) {
            my %parse_result;
            $parse_result{'error'} =
              "No valid observationUnitDbId values found in the file.";
            return \%parse_result;
        }

        my $transform_plugin = CXGN::List::Transform->new();
        my $transform_result = $transform_plugin->transform( $schema, 'stock_ids_2_stocks', \@stock_ids );

        if ( $transform_result->{missing} && @{ $transform_result->{missing} } ) {
            my %parse_result;
            $parse_result{'error'} =
                "The following observationUnitDbId values could not be found in the database: "
              . join( ", ", @{ $transform_result->{missing} } );
            return \%parse_result;
        }

        my @transformed_names = @{ $transform_result->{transform} };
        @id_to_name{@stock_ids} = @transformed_names;
    }

    my %data;
    my %units_seen;

    for my $row (@$parsed_data) {
        next unless $row && ref($row) eq 'HASH';

        my $observationunit_name;
        if ( $observationunit_type eq 'id' ) {
            my $stock_id = $row->{'observationunit_id'};
            next unless defined $stock_id && $stock_id ne '';
            $observationunit_name = $id_to_name{$stock_id};
            next
              unless defined $observationunit_name
              && $observationunit_name ne '';
        }
        else {
            $observationunit_name = $row->{'observationunit_name'};
            next
              unless defined $observationunit_name
              && $observationunit_name ne '';
        }

        $units_seen{$observationunit_name} = 1;

        for my $trait_name (@$trait_columns) {
            next unless defined $trait_name && $trait_name ne '';

            my $value_string = defined($row->{$trait_name}) ? $row->{$trait_name} : '';
            my @trait_values;

            if ($timestamp_included) {
                my @values = split(/\|/, $value_string, -1);

                foreach my $v (@values) {
                    next unless defined $v;

                    my ($trait_value, $timestamp) = split(/,/, $v, 2);

                    $trait_value = '' unless defined $trait_value;
                    $timestamp   = '' unless defined $timestamp;

                    # Skip only fully empty timestamp tokens.
                    # Keep empty values when they have timestamps.
                    next if $trait_value eq '' && $timestamp eq '';

                    next if $trait_value eq '.';

                    push @trait_values, [ $trait_value, $timestamp ];
                }
            }
            else {
                # Simple trait without timestamp:
                # keep empty values, but still skip "." missing marker.
                if ($value_string ne '.') {
                    push @trait_values, [ $value_string, '' ];
                }
            }

            push @{ $data{$observationunit_name}->{$trait_name} }, @trait_values
              if @trait_values;
        }
    }

    my @sorted_units = sort keys %units_seen;
    my @sorted_variables = sort @$trait_columns;

    my %parse_result;
    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@sorted_units;
    $parse_result{'variables'} = \@sorted_variables;

    return \%parse_result;
}

1;
