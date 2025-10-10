package CXGN::File::Parse::Plugin::Spreadsheet;

use strict;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Spreadsheet::ParseODS;
use List::MoreUtils qw|uniq|;

sub type {
  return "excel";
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

  my $parser;
  if ( $type eq 'xlsx' ) {
    $parser = Spreadsheet::ParseXLSX->new();
  }
  elsif ( $type eq 'xls' ) {
    $parser = Spreadsheet::ParseExcel->new();
  }
  elsif ( $type eq 'ods' ) {
    $parser = Spreadsheet::ParseODS->new();
  }
  else {
    push @{$rtn{errors}}, "Invalid type $type for spreadsheet parse plugin";
    return \%rtn;
  }

  # read the first worksheet in the Spreadsheet
  my $workbook = $parser->parse($file);
  if ( !$workbook ) {
    push @{$rtn{errors}}, $parser->error();
    return \%rtn;
  }
  my $worksheet = ( $workbook->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();

  my %values_map;     # map of values by column
  my @col_indices;    # array of column indices to process

  # Get column / header information
  my %seen_column_headers;
  my $skips_in_a_row = 0;
  for my $col ( 0 .. $col_max ) {
    my $c = $worksheet->get_cell(0, $col);
    my $v = $c ? $c->value() : undef;
    $v = $super->clean_header($v);

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

  # Parse each row
  $skips_in_a_row = 0;
  for my $row ( 1 .. $row_max ) {
    my %row_info = (
      _row => $row+1
    );
    my $skip_row = 1;
    for my $col (@col_indices) {
      my $h = $worksheet->get_cell(0, $col)->value();
      my $hv = $super->clean_header($h);
      my $c = $worksheet->get_cell($row, $col);
      my $v = $c ? $c->value() : undef;
      $v = $super->clean_value($v, $hv);

      if ( defined($v) && $v ne '' ) {
        if ( ref($v) eq 'ARRAY' ) {
          if ( scalar(@$v) > 0 ) {
            push @{$row_info{$hv}}, @$v;
            foreach (@$v) {
              $values_map{$hv}->{$_} = 1;
            }
            $skip_row = 0;
          }
        }
        else {
          $row_info{$hv} = $v;
          $values_map{$hv}->{$v} = 1;
          $skip_row = 0;
        }
      }
      else {
        $row_info{$hv} = $row_info{$hv} || undef;
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
