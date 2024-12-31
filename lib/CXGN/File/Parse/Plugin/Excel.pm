package CXGN::File::Parse::Plugin::Excel;

use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;

sub type {
  return "excel";
}

sub parse {
  my $self = shift;
  my $super = shift;
  my $file = $super->file();
  my $type = $super->type();

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
  else {
    push @{$rtn{errors}}, "Invalid type $type for excel parse plugin";
    return \%rtn;
  }

  # read the first worksheet in the Excel
  my $workbook = $parser->parse($file);
  if ( !$workbook ) {
    push @{$rtn{errors}}, $parser->error();
    return \%rtn;
  }
  my $worksheet = ( $workbook->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();
  my %values_map;

  # Get column / header information
  for my $col ( 0 .. $col_max ) {
    my $c = $worksheet->get_cell(0, $col);
    my $v = $c->value() if $c;
    $v = $super->clean_header($v);

    if ( $v && $v ne '' ) {
      push @{$rtn{columns}}, $v;
      $values_map{$v} = {};
    }
  }

  # Parse each row
  my $skips_in_a_row = 0;
  for my $row ( 1 .. $row_max ) {
    my %row_info = (
      _row => $row+1
    );
    my $skip_row = 1;
    for my $col ( 0 .. $col_max ) {
      my $hv = $rtn{columns}->[$col];
      my $c = $worksheet->get_cell($row, $col);
      my $v = $c ? $c->value() : undef;
      $v = $super->clean_value($v, $hv);
      $row_info{$hv} = $v;

      if ( $v && $v ne '' ) {
        if ( ref($v) eq 'ARRAY' ) {
          if ( scalar(@$v) > 0 ) {
            foreach (@$v) {
              $values_map{$hv}->{$_} = 1;
            }
            $skip_row = 0;
          }
        }
        else {
          $values_map{$hv}->{$v} = 1;
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
