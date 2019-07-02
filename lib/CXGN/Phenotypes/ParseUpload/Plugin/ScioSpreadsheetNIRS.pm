package CXGN::Phenotypes::ParseUpload::Plugin::ScioSpreadsheetNIRS;

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

sub name {
    return "scio spreadsheet nirs";
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

    if ( $columns[0] ne "name" ) {
      $parse_result{'error'} = "First cell must be 'name'. Is this a NIRS spreadhseet formatted by SCiO?";
      print STDERR "First cell must be 'name'\n";
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

    my %metadata_hash;
    my $row_number = 0;
    my $observation_column_index;

    while (my $row = $csv->getline ($fh)) {
        if ( $row_number < 10 ) {
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            } else {
                $parse_result{'error'} = "Could not parse row $row.";
                print STDERR "Could not parse row $row.\n";
                return \%parse_result;
            }

            my $key = $columns[0];
            my $value = $columns[1];
            $metadata_hash{$key} = $value;
        }
        elsif ( $row_number = 10 ) {
            if ($csv->parse($row)) {
                @header_columns = $csv->fields();
            } else {
                $parse_result{'error'} = "Could not parse row $row.";
                print STDERR "Could not parse row $row.\n";
                return \%parse_result;
            }
            for my $i ( 0 .. scalar(@header_columns) ) {
                if ($header_columns[$i] eq 'User_input_id') {
                    $observation_column_index = $i;
                    last;
                }
            }
        }
        elsif ( $row_number >= 12 )   {# get data
          my @columns;
          if ($csv->parse($row)) {
              @columns = $csv->fields();
          } else {
              $parse_result{'error'} = "Could not parse row $row.";
              print STDERR "Could not parse row $row.\n";
              return \%parse_result;
          }
          my $num_cols = scalar(@columns);

          my $observationunit_name = $columns[$observation_column_index]
            if (defined($observationunit_name)){
                if ($observationunit_name ne ''){
                    $observationunits_seen{$observationunit_name} = 1;

                          #store metadata at protocol level instead
                          #$data{$observationunit_name}->{'nirs'} = %metadata_hash;

                          for my $col (0 .. $num_cols-1) {
                              my $seen_spectra;
                              my $column_name = $header_columns[$col];
                              if (defined($column_name)) {
                                  print STDERR "Column name is $column_name\n";
                                  if ($column_name ne '' && $column_name !~ /spectrum/){ #check if not spectra, if not spectra add to {'nirs'} not nested. if have already seen spectra, last
                                      if ($seen_spectra) {
                                          last;
                                      }

                                      my $metadata_value = '';
                                      if ($columns[$col]){
                                          $metadata_value = $columns[$col];
                                      }
                                      $data{$observationunit_name}->{'nirs'}->{$column_name} = $metadata_value;
                                  }
                                  elsif ($column_name ne '' && $column_name =~ /spectrum/){
                                      #if spectra, strip tex, do sum, and add to {'nirs'} nested, and set flag that have seen spectra
                                      print STDERR "Processing $column_name\n";
                                      my @parts = split /[_+]+/, $column_name;
                                      my $wavelength = $parts[2] + $parts[1];
                                      my $nir_value = '';

                                      if ($columns[$col]){
                                          $nir_value = $columns[$col]
                                      }

                                      if ( defined($nir_value) && $nir_value ne '.') {
                                          $data{$observationunit_name}->{'nirs'}->{'spectra'}->{$wavelength} = $nir_value;
                                      }

                                  }
                              }
                          }
                      }
                  }
              }

        $row_number++;
    }

    foreach my $obs (sort keys %observationunits_seen) {
        push @observation_units, $obs;
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
