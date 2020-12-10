package CXGN::Phenotypes::ParseUpload::Plugin::SpreadsheetNIRS;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           nirs => {
#              spectra => {
#                 "740" => "0.939101707",
#                 "741" => "0.93868202",
#              },
#          }
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
use JSON;
use Data::Dumper;
use Text::CSV;

sub name {
    return "spreadsheet nirs";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
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

    my $header_col_1 = shift @columns;
    if ($header_col_1 ne "sample_name") {
        $parse_result{'error'} = "First cell must be 'sample_name'. Please, check your file.";
        print STDERR "First cell must be 'sample_name'\n";
        return \%parse_result;
    }

    foreach (@columns) {
        if (not $_=~/^[+]?\d+\.?\d*$/){
            $parse_result{'error'}= "It is not a valid wavelength in the header: '$_'. Could you check the data format?";
            return \%parse_result;
        }
    }

    my %types = (
                  SCIO        =>1,
                  QST         =>2,
                  Foss6500    =>3,
                  BunchiN500  =>4,
                  LinkSquare  =>5
                  );

    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $sample_name = shift @fields;

        foreach (@fields) {
            if (not $_=~/^[+]?\d+\.?\d*$/){
                $parse_result{'error'}= "It is not a real value for wavelength: '$_'";
                return \%parse_result;
            }
        }
    }
    close $fh;

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my @header;
    my @fields;
    my @wave;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %observation_units_seen;
    my %traits_seen;
    my @observation_units;
    my @traits;
    my %data;
    my %metadata_hash;
    my $row_number = 0;
    my $col_number=0;
    my $number=0;
    my $size;
    my $count;
    my $num_cols;

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    while (my $row = $csv->getline ($fh)) {
        if ( $row_number == 0 ) {
            @header = @{$row};
            $num_cols = scalar(@header);
        } elsif ( $row_number > 0 ) {# get data
            my @columns = @{$row};
            my $observationunit_name = $columns[0];
            $observation_units_seen{$observationunit_name} = 1;
            # print "The plots are $observationunit_name\n";
            my %spectra;
            foreach my $col (1..$num_cols-1){
                my $column_name = $header[$col];
                my $wavelength = "X".$column_name;
                my $nir_value = $columns[$col];
                $spectra{$wavelength} = $nir_value;
            }
            push @{$data{$observationunit_name}->{'nirs'}->{'spectra'}}, \%spectra;
        }
        $row_number++;
    }
    close($fh);

    foreach my $obs (sort keys %observation_units_seen) {
        push @observation_units, $obs;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@observation_units;
    $parse_result{'variables'} = \@traits;
    # print STDERR Dumper \%parse_result;
    return \%parse_result;
}

1;
