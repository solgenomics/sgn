package CXGN::Phenotypes::ParseUpload::Plugin::TranscriptomicsSpreadsheetCSV;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       tissue_samples1 => {
#           varname1 => [RNAseqUG150-rep1-UG15F118P001_100_plant_1_leaf1, '2015-06-16T00:53:26Z']
#           transcript => {
#              observationunit_name => 'RNAseqUG150-rep1-UG15F118P001_100_plant_1_leaf1',
#              observation_name => 'UG15F118P001',
#              sample_type => 'leaf',
#              sampling_condition => 'day',
#              sample_replication => '1',
#              expression_unit => 'RPKM',
#              transcripts => {
#                 "Manes.01G000100" => "0.939101707",
#                 "Manes.01G000200" => "0.93868202",
#              },
#          }
#       }
#   },
#   units => [tissue_samples1],
#   variables => [varname1, varname2]
#)

use Moose;
use JSON;
use Data::Dumper;
use Text::CSV;
use CXGN::List::Validate;

sub name {
    return "highdimensionalphenotypes spreadsheet transcriptomics";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift;
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
    print STDERR Dumper $csv->fields();
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }
    
    my $header_col_1 = shift @columns;
    if ( $header_col_1 ne "sample_name" ) {
      $parse_result{'error'} = "First cell must be 'sample_name'. Please, check your file.";
      print STDERR "First cell must be 'sample_name'\n";
      return \%parse_result;
    }

    my @samples;
    my @transcripts;
    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $sample_name = shift @fields;
        push @samples, $sample_name;
        @transcripts = @fields;

        foreach (@fields) {
            if (not $_=~/^[+]?\d+\.?\d*$/){
                $parse_result{'error'}= "It is not a real value for trancripts: '$_'";
                return \%parse_result;
            }
        }
    }
    close $fh;

    my $samples_validator = CXGN::List::Validate->new();
    my @samples_missing = @{$samples_validator->validate($schema,'tissue_samples',\@samples)->{'missing'}};
    if (scalar(@samples_missing) > 0) {
        my $samples_string = join ', ', @samples_missing;
        $parse_result{'error'}= "The following samples in your file are not valid in the database (".$samples_string."). Please add them in a sampling trial first!";
        return \%parse_result;
    }

    if ($nd_protocol_id) {
        my $transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
        my $protocol = CXGN::Phenotypes::HighDimensionalPhenotypeProtocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $nd_protocol_id,
            nd_protocol_type_id => $transcriptomics_protocol_cvterm_id
        });
        my $transcripts_in_protocol = $protocol->header_column_names;
        my %transcripts_in_protocol_hash;
        foreach (@$transcripts_in_protocol) {
            $transcripts_in_protocol_hash{$_}++;
        }

        my @transcripts_not_in_protocol;
        foreach (@transcripts) {
            if (!exists($transcripts_in_protocol_hash{$_})) {
                push @transcripts_not_in_protocol, $_;
            }
        }

        #If there are markers in the uploaded file that are not saved in the protocol, they will be returned along in the error message
        if (scalar(@transcripts_not_in_protocol)>0){
            $errors{'missing_transcripts'} = \@transcripts_not_in_protocol;
            push @error_messages, "The following transcripts are not in the database for the selected protocol: ".join(',',@transcripts_not_in_protocol);
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
    my $nd_protocol_id = shift;
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
        # print STDERR "Row is ".Dumper($row)."\n";
        if ( $row_number == 0 ) {
            @header = @{$row};
            $num_cols = scalar(@header);
        } elsif ( $row_number > 0 ) {# get data
            my @columns = @{$row};
            my $observationunit_name = $columns[0];
            $observation_units_seen{$observationunit_name} = 1;
            # print "The plots are $observationunit_name\n";
            my %spectra;
            foreach my $col (0..$num_cols-1){
                my $column_name = $header[$col];
                if ($column_name ne '' && $column_name =~ /^Manes/){
                    my $wavelength = $column_name;
                    $traits_seen{$wavelength}++;
                    my $nir_value = $columns[$col];
                    $spectra{$wavelength} = $nir_value;
                }
            }
            push @{$data{$observationunit_name}->{'transcriptomics'}->{'transcripts'}}, \%spectra;
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
    return \%parse_result;
    # print STDERR Dumper \%parse_result;
}

1;
