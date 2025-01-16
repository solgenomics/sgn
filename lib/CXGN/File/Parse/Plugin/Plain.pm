package CXGN::File::Parse::Plugin::Plain;

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

  # Set data columns
  foreach my $c (@{$rows[0]}) {
    $c = $super->clean_header($c);
    push @{$rtn{columns}}, $c;
  }
  my $row_max = scalar(@rows);
  my $col_max = scalar(@{$rows[0]})-1;

  # Setup values map for unique values per column
  my %values_map;
  for my $c ( 1..$col_max ) {
    $values_map{$rows[0]->[$c]} = {};
  }

  # Set data values
  my $skips_in_a_row = 0;
  for my $r ( 1..$row_max ) {
    my $row = $rows[$r];
    my %row_info = (
      _row => $r+1
    );
    my $skip_row = 1;
    for my $c ( 0..$col_max ) {
      my $h = $rows[0]->[$c];
      my $v = $rows[$r]->[$c];
      $v = $super->clean_value($v, $h);

      # Merge with existing data if column occurs more than once and allowed to be an array
      if ( exists $row_info{$h} && exists $column_arrays->{$h} ) {
        my @merged = uniq(@{$row_info{$h}}, @$v);
        $row_info{$h} = \@merged;
      }
      else {
        $row_info{$h} = $v;
      }

      if ( $v && $v ne '' ) {
        if ( ref($v) eq 'ARRAY' ) {
          if ( scalar(@$v) > 0 ) {
            foreach (@$v) {
              $values_map{$h}->{$_} = 1;
            }
            $skip_row = 0;
          }
        }
        else {
          $values_map{$h}->{$v} = 1;
          $skip_row = 0;
        }
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
