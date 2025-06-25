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
            'observationunit_name' => [ 'plot_name', 'subplot_name', 'plant_name', 'observationUnitName', 'plotName', 'subplotName', 'plantName' ]
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
                my ($value, $timestamp) = split /,/, $value_string;
                if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                    $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
                    return \%parse_result;
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

    # Open and read the file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => [ "observationunit_name" ],
        column_aliases => {
            'observationunit_name' => [ 'plot_name', 'subplot_name', 'plant_name', 'observationUnitName', 'plotName', 'subplotName', 'plantName' ]
        }
    );
    my $parsed = $parser->parse();
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $trait_columns = $parsed->{optional_columns};

    my %data;
    for my $row (@$parsed_data) {
        my $observationunit_name = $row->{'observationunit_name'};

        for my $trait_name (@$trait_columns) {
            my $value_string = defined($row->{$trait_name}) ? $row->{$trait_name} : '';
            my $timestamp = '';
            my $trait_value = '';
            if ($timestamp_included){
                ($trait_value, $timestamp) = split /,/, $value_string;
            } else {
                $trait_value = $value_string;
            }
            if (!defined($timestamp)){
                $timestamp = '';
            }

            if ( defined($trait_value) && defined($timestamp) ) {
                if ($trait_value ne '.') {
                    push @{$data{$observationunit_name}->{$trait_name}}, [$trait_value, $timestamp];
                }
            }
        }
    }

    my @sorted_units = sort(@{$parsed_values->{'observationunit_name'}});
    my @sorted_variables = sort(@$trait_columns);

    my %parse_result;
    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@sorted_units;
    $parse_result{'variables'} = \@sorted_variables;

    return \%parse_result;
}

1;
