package CXGN::Phenotypes::ParseUpload::Plugin::TranscriptomicsSpreadsheetCSV;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       tissue_samples1 => {
#           transcriptomics => {
#              transcripts => [{
#                 "Manes.01G000100" => "0.939101707",
#                 "Manes.01G000200" => "0.93868202",
#              }],
#          }
#       }
#   },
#   units => [tissue_samples1],
#   variables => [varname1, varname2],
#   variables_desc => {
#       "Manes.01G000100" => {
#           "chr" => "1",
#           "start" => "100",
#           "end" => "101",
#           "gene_desc" => "gene1",
#           "notes" => ""
#       },
#       "Manes.01G000200" => {
#           "chr" => "1",
#           "start" => "200",
#           "end" => "201",
#           "gene_desc" => "gene2",
#           "notes" => ""
#       }
#   }
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
    $header_col_1 =~ s/^\s+|\s+$//g;
    if ( $header_col_1 ne "sample_name" ) {
      $parse_result{'error'} = "First cell must be 'sample_name'. Please, check your file.";
      print STDERR "First cell must be 'sample_name'\n";
      return \%parse_result;
    }

    my $header_col_2 = shift @columns;
    $header_col_2 =~ s/^\s+|\s+$//g;
    if ($header_col_2 ne "device_id") {
        $parse_result{'error'} = "Second cell must be 'device_id'. Please, check your file.";
        print STDERR "Second cell must be 'device_id'\n";
        return \%parse_result;
    }

    my $header_col_3 = shift @columns;
    $header_col_3 =~ s/^\s+|\s+$//g;
    if ($header_col_3 ne "comments") {
        $parse_result{'error'} = "Third cell must be 'comments'. Please, check your file.";
        print STDERR "Third cell must be 'comments'\n";
        return \%parse_result;
    }

    my @transcripts = @columns;

    my @samples;
    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $sample_name = shift @fields;
        $sample_name =~ s/^\s+|\s+$//g;
        my $device_id = shift @fields;
        my $comments = shift @fields;
        push @samples, $sample_name;

        foreach (@fields) {
            if (not $_=~/^[-+]?\d+\.?\d*$/ && $_ ne 'NA'){
                $parse_result{'error'}= "It is not a real value for trancripts. Must be numeric or NA: '$_'";
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

    my $gene_id_head = $columns[0];
    $gene_id_head =~ s/^\s+|\s+$//g;

    my $chromosome_head = $columns[1];
    $chromosome_head =~ s/^\s+|\s+$//g;

    my $pos_left_head = $columns[2];
    $pos_left_head =~ s/^\s+|\s+$//g;

    my $pos_right_head = $columns[3];
    $pos_right_head =~ s/^\s+|\s+$//g;

    my $functional_annotation_head = $columns[4];
    $functional_annotation_head =~ s/^\s+|\s+$//g;

    my $notes_head = $columns[5];
    $notes_head =~ s/^\s+|\s+$//g; 
    #print STDERR "gene_id_head: $gene_id_head, chromosome_head: $chromosome_head, pos_lef_head: $pos_left_head, pos_right_head: $pos_right_head, functional_anotation_head: $functional_annotation_head \n";

    if ($gene_id_head  ne "gene_id" ||
        $chromosome_head ne "chromosome" ||
        $pos_left_head ne "pos_left" ||
        $pos_right_head ne "pos_right" ||
        $functional_annotation_head ne "functional_annotation" ||
        $notes_head ne "notes") {
      $parse_result{'error'} = "Header row must be 'gene_id', 'chromosome', 'pos_left', 'pos_right', 'functional_annotation', 'notes'. Please, check your file.";
      return \%parse_result;
    }
    while (my $line = <$fh>) {
        my @fields;
        if ($csv->parse($line)) {
            @fields = $csv->fields();
        }
        my $gene_id = $fields[0];
        my $chromosome = $fields[1];
        my $pos_left = $fields[2];
        my $pos_right = $fields[3];
        my $functional_annotation = $fields[4];
        my $notes = $fields[5];

        if (!$gene_id){
            $parse_result{'error'}= "Transcript name is required!";
            return \%parse_result;
        }
        if (!defined($chromosome) && !length($chromosome)) {
            $parse_result{'error'}= "Chromosome is required!";
            return \%parse_result;
        }
        if (!defined($pos_left) && !length($pos_left)){
            $parse_result{'error'}= "Start position is required!";
            return \%parse_result;
        }
        if (!defined($pos_right) && !length($pos_right)){
            $parse_result{'error'}= "End position is required!";
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
            $parse_result{'error'} = "The following transcripts are not in the database for the selected protocol: ".join(',',@transcripts_not_in_protocol);
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
                my $gene_id = $column_name;
                $traits_seen{$gene_id}++;
                my $transcipt_value = $columns[$col];
                $spectra{$gene_id} = $transcipt_value;
            }
        }
        $data{$observationunit_name}->{'transcriptomics'}->{'device_id'} = $device_id;
        $data{$observationunit_name}->{'transcriptomics'}->{'comments'} = $comments;
        push @{$data{$observationunit_name}->{'transcriptomics'}->{'transcripts'}}, \%spectra;
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
        my $gene_id = $fields[0];
        my $chromosome = $fields[1];
        my $pos_left = $fields[2];
        my $pos_right = $fields[3];
        my $functional_annotation = $fields[4];
        my $notes = $fields[5];

        $header_column_details{$gene_id} = {
            chr => $chromosome,
            start => $pos_left,
            end => $pos_right,
            gene_desc => $functional_annotation,
            notes => $notes
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
