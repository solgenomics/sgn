package CXGN::File::Parse::Plugin::Plain;

use strict;

use Data::Dumper;
use CXGN::File::Parse;
use Text::CSV;
use List::MoreUtils qw|uniq|;

sub type {
  return "plain";
}

sub parse {
  my $self = shift;
  my $super = shift;
  my $file = $super->file();
  my $type = $super->type();
  my $column_arrays = $super->column_arrays();

  # Parsed data to return
  my %rtn = (
    errors => [],   # an array of error messages encountered during parsing
    columns => [],  # an array of column headers
    data => [],     # an array of row information
    values => {}    # a hash of unique values for each column
  );

  # Set the field separator to use
  my $sep;
  if ( $type eq 'csv' ) {
    $sep = ',';
  }
  elsif ( $type eq 'tsv' ) {
    $sep = "\t";
  }
  elsif ( $type eq 'txt' ) {
    $sep = "\t";
  }
  elsif ( $type eq 'ssv' ) {
    $sep = ';';
  }
  else {
    push @{$rtn{errors}}, "Invalid type $type for plain parse plugin";
    return \%rtn;
  }

  # Read the file row by row
  my @rows;
  my $csv = Text::CSV->new({
    sep_char => $sep,
    strict => 0,
    binary => 1,
    decode_utf8 => 1,
    skip_empty_rows => 0,
    blank_is_undef => 1,
    empty_is_undef => 1,
    allow_whitespace => 1,
    auto_diag => 2
  });
  open my $fh, "<:encoding(utf8)", $file or die "Could not read file: $!";
  while ( my $row = $csv->getline($fh) ) {
    push @rows, $row;
  }
  close $fh;

  my $row_max = scalar(@rows);
  my $col_max = scalar(@{$rows[0]})-1;

  my %values_map;     # map of values by column
  my @col_indices;    # array of column indices to process

  # Set data columns
  my %seen_column_headers;
  my $skips_in_a_row = 0;
  foreach my $col ( 0 .. $col_max ) {
    my $c = $rows[0]->[$col];
    my $v = $super->clean_header($c);

    if ( $v && $v ne '' ) {
      # check for duplicated column header
      if ( exists $seen_column_headers{$v} && !exists $column_arrays->{$v} ) {
        push @{$rtn{errors}}, "The column header $v was duplicated in column " . ($col+1) . " of your file and should only be included once.";
      }
      $seen_column_headers{$v}++;

      push @{$rtn{columns}}, $v;
      push @col_indices, $col;
      $values_map{$v} = {};
      $skips_in_a_row = 0;
    }
    else {
      $skips_in_a_row++;
    }

    last if $skips_in_a_row >= 5;
  }

  # Set data values
  $skips_in_a_row = 0;
  for my $r ( 1..$row_max ) {
    my $row = $rows[$r];
    my %row_info = (
      _row => $r+1
    );
    my $skip_row = 1;
    for my $c (@col_indices) {
      my $h = $rows[0]->[$c];
      $h = $super->clean_header($h);
      my $v = $rows[$r]->[$c];
      $v = $super->clean_value($v, $h);

      if ( defined($v) && $v ne '' ) {
        if ( ref($v) eq 'ARRAY' ) {
          if ( scalar(@$v) > 0 ) {
            push @{$row_info{$h}}, @$v;
            foreach (@$v) {
              $values_map{$h}->{$_} = 1;
            }
            $skip_row = 0;
          }
        }
        else {
          $row_info{$h} = $v;
          $values_map{$h}->{$v} = 1;
          $skip_row = 0;
        }
      }
      else {
        $row_info{$h} = $row_info{$h} || undef;
      }
    }
    $skips_in_a_row = $skip_row ? $skips_in_a_row+1 : 0;
    last if $skips_in_a_row > 5;
    push @{$rtn{data}}, \%row_info if !$skip_row;
  }

  # Parse the unique values
  foreach my $v (keys %values_map) {
    my $vs = $values_map{$v};
    $rtn{values}->{$v} = [keys %$vs];
  }

  return \%rtn;
}

1;
