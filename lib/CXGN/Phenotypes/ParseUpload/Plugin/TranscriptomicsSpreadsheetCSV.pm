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

sub name {
    return "highdimensionalphenotypes spreadsheet transcriptomics";
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
    print STDERR Dumper $csv->fields();
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }
    if ( $columns[0] ne "observationunit_name" ) {
      $parse_result{'error'} = "First cell must be 'observationunit_name'. Please, check your file.";
      print STDERR "First cell must be 'observationunit_name'\n";
      return \%parse_result;
    }

    close $fh;

    my %headers = ( 
                    observationunit_name =>1,
                    observation_name     =>2,
                    sample_type          =>3,
                    sampling_condition   =>4,
                    sample_replication   =>5,
                    expression_unit =>6

                    );

    my %types = (
                  leaf =>1,
                  stem =>2,
                  flower  =>3,
                  fibrous_root  =>4,
                  storage_root =>5
                  );
                  
    my %units = (
                    RPKM =>1,
                    FPKM =>2,
                    TPM  =>3,
                    VST  =>4
                    );
                  
                                   
    open($fh, '<', $filename)
        or die "Could not open file '$filename' $!";
    
    my $size = 0;
    my $number = 0;
    my $count = 1;
    my @fields;
    while (my $line = <$fh>) {
      if ($csv->parse($line)) {
        @fields = $csv->fields(); 
        #print STDERR Dumper(\@fields);
        if ($count == 1) {
          $size = scalar @fields;
          while ($number < 6) {
              if (not exists $headers{$fields[$number]}){
                $parse_result{'error'} = "Wrong headers at '$fields[$number]'! Is this file matching with Spredsheet Format?";
                return \%parse_result;
              }else{
                $number++;
              }
            }
        #   while ($number < $size){
        #     if (not $fields[$number]=~/^\D+[+]?\d+\.?\d*$/){
        #       $parse_result{'error'}= "It is not a valid wavelength: '$fields[$number]'. Could you check the data format?";
        #       return \%parse_result;
        #     }else{
        #       $number++;
        #     }
        #   }
        }elsif($count>1){
          my $number2 = 8;
          while ($number2 < $size){
            # if (not exists $types{$fields[5]}){
              #print "$fields[5]\n";
              if (not grep {/$fields[2]/i} keys %types){
                $parse_result{'error'}= "Wrong sample type '$fields[2]'. Please, check names allowed in File Format Information.";
                return \%parse_result;
            }
            if (not $fields[$number2]=~/^[+]?\d+\.?\d*$/){
                $parse_result{'error'}= "It is not a real value for trancripts: '$fields[$number2]'";
                return \%parse_result;
            }
            if (not $fields[4] eq ''){
              if (not $fields[4] =~/\d+/) {
                  $parse_result{'error'} = "Sample replication needs to be an integer of the form 1, 2, or 3";
                  print STDERR "value: $fields[4]\n";
                  return \%parse_result;
              }
            }
            $number2++;
          }
        }
        $count++;
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
