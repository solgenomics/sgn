package CXGN::Phenotypes::ParseUpload::Plugin::DataCollectorSpreadsheet;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;

sub name {
    return "datacollector spreadsheet";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;
    my @errors;
   
    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
      push @errors,  $parser->error();
      #$self->_set_parse_errors(\@errors);
      print STDERR "validate error: ".$parser->error()."\n";
      return;
    }

    $worksheet = ($excel_obj->worksheets())[7]; #support only one worksheet
    if (!$worksheet) {
	print STDERR "No 7th tab found in your Excel file.\n";
	return;
    }

   my  ( $row_min, $row_max ) = $worksheet->row_range();
   my  ( $col_min, $col_max ) = $worksheet->col_range();

    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of phenotypes
      push @errors, "Spreadsheet is missing header";
      #$self->_set_parse_errors(\@errors);
      print STDERR "Spreadsheet is missing header\n";
      return;
    }

    my $plot_name_head;
    if ($worksheet->get_cell(0,0)) {
      $plot_name_head  = $worksheet->get_cell(0,0)->value();
    }

    if (!$plot_name_head || $plot_name_head ne 'plot_name') {
      print STDERR "No plot name in header\n";
      return;
    }


    #if the rest of the header rows are not two caps followed by colon followed by text then return

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my %parse_result;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %plots_seen;
    my %traits_seen;
    my @plots;
    my @traits;
    my %data;
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;
    my @errors;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
      push @errors,  $parser->error();
      #$self->_set_parse_errors(\@errors);
      print STDERR "Could not open excel file";
      return;
    }

    $worksheet = ( $excel_obj->worksheets() )[7];
    if (!$worksheet) {
	print STDERR "No 7th tab found in your Excel file.\n";
	return;
    }

    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    #get trait names and column numbers;
    for my $col (6 .. $col_max) {
      my $cell_val;
      if ($worksheet->get_cell(0,$col)) {
	$cell_val = $worksheet->get_cell(0,$col)->value();
      }
      if ($cell_val) {
	$header_column_info{$cell_val} = $col;
	$traits_seen{$cell_val} = 1;
      }
    }

    for my $row ( 1 .. $row_max ) {
      my $plot_name;

      if ($worksheet->get_cell($row,0)) {
	$plot_name = $worksheet->get_cell($row,0)->value();
	$plots_seen{$plot_name} = 1;
      }

      foreach my $trait_key (sort keys %header_column_info) {
	my $trait_value;
	if ($worksheet->get_cell($row,$header_column_info{$trait_key})){
	  $trait_value = $worksheet->get_cell($row,$header_column_info{$trait_key})->value();
	}
	if ($trait_value || $trait_value eq '0') {
	  if ($trait_value ne '.'){
	    $data{$plot_name}->{$trait_key} = $trait_value;
	  }
	}
      }
    }

    foreach my $plot (sort keys %plots_seen) {
	push @plots, $plot;
    }
    foreach my $trait (sort keys %traits_seen) {
	push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    return \%parse_result;
}

1;
