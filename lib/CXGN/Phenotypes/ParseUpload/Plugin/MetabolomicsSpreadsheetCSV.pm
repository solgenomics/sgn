package CXGN::Phenotypes::ParseUpload::Plugin::MetabolomicsSpreadsheetCSV;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       tissue_samples1 => {
#           metabolomics => {
#              metabolites => [{
#                 "M1" => "0.939101707",
#                 "M2" => "0.93868202",
#              }],
#          }
#       }
#   },
#   units => [tissue_samples1],
#   variables => [varname1, varname2],
#   variables_desc => {
#       "M1" => {
#           "inchi_key" => "AAJHVVLGKCKBSH-UHFFFAOYNA-N",
#           "compound_name" => "Avenacoside A",
#       },
#       "M2" => {
#           "inchi_key" => "UHISGSDYAIIBMO-HZJYTTRNNA-N",
#           "compound_name" => "Gingerglycolipid B",
#       }
#   }
#)

use Moose;
use JSON;
use Data::Dumper;
use Text::CSV;
use CXGN::List::Validate;

sub name {
    return "highdimensionalphenotypes spreadsheet metabolomics";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift;
    my $nd_protocol_filename = shift;
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @columns;
    # print STDERR Dumper $csv->fields();
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        open $fh, "<", $filename;
        binmode $fh; # for Windows
        if ($csv->header($fh) && $csv->column_names) {
            @columns = $csv->column_names;
        }
        else {
            $parse_result{'error'} = "Could not parse header row.";
            print STDERR "Could not parse header.\n";
            return \%parse_result;
        }
    }

    my $header_col_1 = shift @columns;
    if ( $header_col_1 ne "sample_name" ) {
      $parse_result{'error'} = "First cell must be 'sample_name'. Please, check your file.";
      print STDERR "First cell must be 'sample_name'\n";
      return \%parse_result;
    }

    my $header_col_2 = shift @columns;
    if ($header_col_2 ne "device_id") {
        $parse_result{'error'} = "Second cell must be 'device_id'. Please, check your file.";
        print STDERR "Second cell must be 'device_id'\n";
        return \%parse_result;
    }

    my $header_col_3 = shift @columns;
    if ($header_col_3 ne "comments") {
        $parse_result{'error'} = "Third cell must be 'comments'. Please, check your file.";
        print STDERR "Third cell must be 'comments'\n";
        return \%parse_result;
    }

    my @metabolite = @columns;

    my @samples;
    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $sample_name = shift @fields;
        my $device_id = shift @fields;
        my $comments = shift @fields;
        push @samples, $sample_name;

        foreach (@fields) {
            if (not $_=~/^[-+]?\d+\.?\d*$/ && $_ ne 'NA'){
                $parse_result{'error'}= "It is not a real value for metabolite. Must be numeric: '$_'";
                return \%parse_result;
            }
        }
    }
    close $fh;

    open($fh, '<', $nd_protocol_filename)
        or die "Could not open file '$nd_protocol_filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    $header_row = <$fh>;
    # print STDERR Dumper $csv->fields();
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }

    if ( $columns[0] ne "metabolite_name" ||
        $columns[1] ne "inchi_key" ||
        $columns[2] ne "compound_name") {
      $parse_result{'error'} = "Header row must be 'metabolite_name', 'inchi_key', 'compound_name'. Please, check your file.";
      return \%parse_result;
    }
    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $metabolite_name = $fields[0];
        my $inchi_key = $fields[1];
        my $compound_name = $fields[2];

        if (!$metabolite_name){
            $parse_result{'error'}= "Metabolite name is required!";
            return \%parse_result;
        }
    }
    close $fh;

    my $samples_validator = CXGN::List::Validate->new();
    my @samples_missing = @{$samples_validator->validate($schema, $data_level, \@samples)->{'missing'}};
    if (scalar(@samples_missing) > 0) {
        my $samples_string = join ', ', @samples_missing;
        $parse_result{'error'}= "The following samples in your file are not valid in the database (".$samples_string."). Please add them in a sampling trial first!";
        return \%parse_result;
    }

    if ($nd_protocol_id) {
        my $metabolomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_metabolomics_protocol', 'protocol_type')->cvterm_id();
        my $protocol = CXGN::Phenotypes::HighDimensionalPhenotypeProtocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $nd_protocol_id,
            nd_protocol_type_id => $metabolomics_protocol_cvterm_id
        });
        my $metabolite_in_protocol = $protocol->header_column_names;
        my %metabolites_in_protocol_hash;
        foreach (@$metabolite_in_protocol) {
            $metabolites_in_protocol_hash{$_}++;
        }

        my @metabolites_not_in_protocol;
        foreach (@metabolite) {
            if (!exists($metabolites_in_protocol_hash{$_})) {
                push @metabolites_not_in_protocol, $_;
            }
        }

        #If there are markers in the uploaded file that are not saved in the protocol, they will be returned along in the error message
        if (scalar(@metabolites_not_in_protocol)>0){
            $parse_result{'error'} = "The following metabolites are not in the database for the selected protocol: ".join(',',@metabolites_not_in_protocol);
            return \%parse_result;
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
    my $nd_protocol_filename = shift;
    my $delimiter = ',';
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my %observation_units_seen;
    my %traits_seen;
    my @observation_units;
    my @traits;
    my %data;
    my %header_column_details;

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @header;
    if ($csv->parse($header_row)) {
        @header = $csv->fields();
    } else {
        open $fh, "<", $filename;
        binmode $fh; # for Windows
        if ($csv->header($fh) && $csv->column_names) {
            @header = $csv->column_names;
        }
        else {
            $parse_result{'error'} = "Could not parse header row.";
            print STDERR "Could not parse header.\n";
            return \%parse_result;
        }
    }
    my $num_cols = scalar(@header);

    while (my $line = <$fh>) {
        my @columns;
        if ($csv->parse($line)) {
            @columns = $csv->fields();
        }

        my $observationunit_name = $columns[0];
        my $device_id = $columns[1];
        my $comments = $columns[2];
        $observation_units_seen{$observationunit_name} = 1;
        # print "The plots are $observationunit_name\n";
        my %spectra;
        foreach my $col (3..$num_cols-1){
            my $column_name = $header[$col];
            if ($column_name ne ''){
                my $metabolite_name = $column_name;
                $traits_seen{$metabolite_name}++;
                my $metabolite_value = $columns[$col];
                $spectra{$metabolite_name} = $metabolite_value;
            }
        }
        $data{$observationunit_name}->{'metabolomics'}->{'device_id'} = $device_id;
        $data{$observationunit_name}->{'metabolomics'}->{'comments'} = $comments;
        push @{$data{$observationunit_name}->{'metabolomics'}->{'metabolites'}}, \%spectra;
    }
    close($fh);

    open($fh, '<', $nd_protocol_filename)
        or die "Could not open file '$nd_protocol_filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    $header_row = <$fh>;
    my @columns;
    # print STDERR Dumper $csv->fields();
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        open $fh, "<", $nd_protocol_filename;
        binmode $fh; # for Windows
        if ($csv->header($fh) && $csv->column_names) {
            @columns = $csv->column_names;
        }
        else {
            $parse_result{'error'} = "Could not parse header row of nd_protocol_file.";
            print STDERR "Could not parse header of nd_protocol_file.\n";
            return \%parse_result;
        }
    }

    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $metabolite_name = $fields[0];
        my $inchi_key = $fields[1];
        my $compound_name = $fields[2];

        $header_column_details{$metabolite_name} = {
            inchi_key => $inchi_key,
            compound_name => $compound_name,
        };
    }
    close $fh;

    foreach my $obs (sort keys %observation_units_seen) {
        push @observation_units, $obs;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@observation_units;
    $parse_result{'variables'} = \@traits;
    $parse_result{'variables_desc'} = \%header_column_details;
    return \%parse_result;
    # print STDERR Dumper \%parse_result;
}

1;
