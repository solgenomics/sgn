package CXGN::File::Parse::Plugin::XLSX;

use Moose;
use Spreadsheet::ParseXLSX;

sub type {
  return "xlsx";
}

sub parse {
  my $self = shift;
  my $file = shift;

  # Parsed data to return
  my %rtn = (
    errors => [],   # an array of error messages encountered during parsing
    columns => [],  # an array of column headers
    data => [],     # an array of row information
    values => {}    # a hash of unique values for each column
  );

  # read the first worksheet in the XLSX file
  my $parser = Spreadsheet::ParseXLSX->new();
  my $workbook = $parser->parse($file);
  if ( !$workbook ) {
    print STDERR "PARSE XLSX ERROR: " . $parser->error() . "\n";
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
    if ( $v && $v ne '' ) {
      push @{$rtn{columns}}, $v;
      $values_map{$v} = {};
    }
  }

  # Parse each row
  for my $row ( 1 .. $row_max ) {
    my %row_info;
    my $skip_row = 1;
    for my $col ( 0 .. $col_max ) {
      my $hc = $worksheet->get_cell(0, $col);
      my $hv = $hc->value() if $hc;
      my $c = $worksheet->get_cell($row, $col);
      my $v = $c->value() if $c;

      if ( $v && $v ne '' ) {
        $row_info{$hv} = $v;
        $values_map{$hv}->{$v} = 1;
        $skip_row = 0;
      }
    }
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
