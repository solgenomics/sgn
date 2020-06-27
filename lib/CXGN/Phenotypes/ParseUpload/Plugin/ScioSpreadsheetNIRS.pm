package CXGN::Phenotypes::ParseUpload::Plugin::ScioSpreadsheetNIRS;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '2015-06-16T00:53:26Z']
#           nirs => {
#              sampling_time => '2/11/19',
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
    my $number = 0;
    my $count=1;
    my $size;
    my @wave = ();
    my @header =();
    my %headers = (id=>1,sample_id=>2,sampling_date=>3,observationunit_name=>4,device_id=>5,device_type=>6,temperature=>7,location=>8,outlier=>9);
    my %types = (SCIO =>1,ASC=>2,FOSS=>3,LINKSQUARE=>4);


    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }


    # my $header_row = <$fh>;
    my @fields;
    while (my $line = <$fh>) {
      if ($csv->parse($line)) {
        @fields = $csv->fields();
        if ($count == 1) {
          $size = scalar @fields;
          while ($number < 9) {
              if (not exists $headers{$fields[$number]}){
                $parse_result{'error'} = "Wrong headers at '$fields[$number]'! Is this file matching with Spredsheet Format?";
                return \%parse_result;
              }else{
                push @header, $fields[$number];
                $number++
              }
          }
          while ($number < $size){
            if (not $fields[$number]=~/^[+]?\d+\.?\d*$/){
              $parse_result{'error'}= "It is not a valid wavelength: $fields[$number]";
              return \%parse_result;
            }else{
              push @wave, $fields[$number];
              $number++;
            }
          }
        }elsif($count>1){
          my $number2 = 9;
          while ($number2 < $size){
            if (not exists $types{$fields[5]}){
                $parse_result{'error'}= "Wrong device type $fields[5]. Please, check names allowed in File Format Information.";
                return \%parse_result;
            }
            if (not $fields[$number2]=~/^[+]?\d+\.?\d*$/){
                $parse_result{'error'}= "It is not a real value for wavelength: $fields[$number2]";
                return \%parse_result;
            }
            if (not $fields[2] eq ''){
              if (not $fields[2] =~ m/(\d{4})-(\d{2})-(\d{2})/) {
                  $parse_result{'error'} = "Sampling date needs to be of form YYYY-MM-DD";
                  print STDERR "value: $fields[2]\n";
                  return \%parse_result;
              }
            }
            $number2++;
          }
        }
        $count++;
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
    

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my %metadata_hash;
    my $row_number = 0;
    my $col_number=0;
    my @header;
    my $observation_column_index;
    my $seen_spectra = 0;
    my $number=0;
    my $size;
    my $count;

    

    while (my $line = <$fh>) {
      if ($csv->parse($line)) {
          @fields = $csv->fields();
          if ($count == 0) {
            $size = scalar @fields;
            while ($number < 9) {
                  push @header, $fields[$number];
                  $number++
                }
            while ($number < $size){
              push @wave, $fields[$number];
              $number++;
            }
          }elsif($count > 0){
              my $observationunit_name = $fields[3];
              my $i = 0;
              for my $col (0..$size-1){
                  if ($col<9){
                      my $mt_name = $header[$i];
                      my $mt_value = '';
                      $mt_value = $fields[$i];
                      $data{$observationunit_name}->{'nirs'}->{$mt_name} = $mt_value;
                  }elsif($col>=9){
                        my $j=0;
                        my $z=9;
                        while ($z<$size){
                          my $nir_name = '';
                          my $nir_value = '';
                          $nir_name = $wave[$j];
                          $nir_value = $fields[$z];
                          $data{$observationunit_name}->{'nirs'}->{'spectra'}->{$nir_name} = $nir_value;
                          $j++;
                          $z++;
                        }
                                      
                  }
                      $i++;
                      $col++;
                }
          }
        $count++;
      }else{
          warn "Line could not be parsed.\n";
          die;
            }
    }
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
  







#     my %metadata_hash;
#     my $row_number = 0;
#     my @header;
#     my $observation_column_index;
#     my $seen_spectra = 0;

#     while (my $row = $csv->getline ($fh)) {
#         #print STDERR "Row is ".Dumper($row)."\n";

#         if ( $row_number == 0 ) {
#             my @columns = @{$row};
#             my $key = $columns[0];
#             my $value = $columns[1];
#             $metadata_hash{$key} = $value;
#         }
#         elsif ( $row_number > 0 ) {
#             @header = @{$row};
#             for my $i ( 0 .. scalar(@header)-1 ) {
#                 if ($header[$i] eq 'User_input_id') {
#                     $observation_column_index = $i;
#                     last;
#                 }
#             }
#         }
#         elsif ( $row_number >= 12 )   {# get data
#           my @columns = @{$row};
#           my $num_cols = scalar(@columns);
#           my $observationunit_name = $columns[$observation_column_index];
#             if (defined($observationunit_name)){
#                 if ($observationunit_name ne ''){
#                     $observation_units_seen{$observationunit_name} = 1;
#                           #store metadata at protocol level instead
#                           #$data{$observationunit_name}->{'nirs'} = %metadata_hash;

#                           foreach my $col (0..$num_cols-1){
#                               my $column_name = $header[$col];
#                               if ($column_name ne '' && $column_name !~ /spectrum/){
#                                 if ($seen_spectra) {
#                                    last;
#                                 }
#                                 my $metadata_value = '';
#                                 $metadata_value = $columns[$col];
#                                 $data{$observationunit_name}->{'nirs'}->{$column_name} = $metadata_value;
#                                 # print "The pot is $observationunit_name and data is $metadata_value\n";
#                               }

#                               if ($column_name ne '' && $column_name =~ /spectrum/){

#                                 # $seen_spectra = 1;
#                                 my @parts = split /[_+]+/, $column_name;
#                                 my $wavelength = $parts[2] + $parts[1];
#                                 my $nir_value = '';
#                                 $nir_value = $columns[$col];
#                                 print "The plot is $observationunit_name and the wave is $wavelength\n";
#                                 $data{$observationunit_name}->{'nirs'}->{'spectra'}->{$wavelength} = $nir_value;
#                               }

#                           }

#                           # foreach my $col (0 .. $num_cols-1) {
#                           #     my $column_name = $header[$col];
#                           #     if (defined($column_name)) {
#                           #         if ($column_name ne '' && $column_name !~ /spectrum/){ #check if not spectra, if not spectra add to {'nirs'} not nested. if have already seen spectra, last
#                           #             if ($seen_spectra) {
#                           #                 last;
#                           #             }
#                           #             my $metadata_value = '';
#                           #             if ($columns[$col]){
#                           #                 $metadata_value = $columns[$col];
#                           #             }
#                           #             print "***************$observationunit_name $num_cols\n";
#                           #             $data{$observationunit_name}->{'nirs'}->{$column_name} = $metadata_value;
#                           #         }
#                           #         if ($column_name ne '' && $column_name =~ /spectrum/){

#                           #             #if spectra, strip tex, do sum, and add to {'nirs'} nested, and set flag that have seen spectra
#                           #             $seen_spectra = 1;
#                           #             my @parts = split /[_+]+/, $column_name;
#                           #             my $wavelength = $parts[2] + $parts[1];
#                           #             my $nir_value = '';

#                           #             if ($columns[$col]){
#                           #                 $nir_value = $columns[$col]
#                           #             }

#                           #             if ( defined($nir_value) && $nir_value ne '.') {
#                           #                 $data{$observationunit_name}->{'nirs'}->{'spectra'}->{$wavelength} = $nir_value;
#                           #             }

#                           #         }
#                           #     }
#                           # }
#                       }
#                   }
#               }

#         $row_number++;
#     }

#     foreach my $obs (sort keys %observation_units_seen) {
#         push @observation_units, $obs;
#     }
#     foreach my $trait (sort keys %traits_seen) {
#         push @traits, $trait;
#     }

#     $parse_result{'data'} = \%data;
#     $parse_result{'units'} = \@observation_units;
#     $parse_result{'variables'} = \@traits;
#     return \%parse_result;
#     # print STDERR Dumper \%parse_result;
    

# }


# 1;
