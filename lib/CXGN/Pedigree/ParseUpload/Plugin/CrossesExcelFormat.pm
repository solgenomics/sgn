package CXGN::Pedigree::ParseUpload::Plugin::CrossesExcelFormat;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;

sub _validate_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my @errors;
  my %valid_cross_types;
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;

  #try to open the excel file and report any errors
  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    push @errors,  $parser->error();
    $self->_set_parse_errors(\@errors);
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
  print STDERR "Worksheet: $worksheet\n\n";
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();
  if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of crosses
    push @errors, "Spreadsheet is missing header";
    $self->_set_parse_errors(\@errors);
    return;
  }

  #get column headers
  my $cross_name_head;
  my $cross_type_head;
  my $maternal_parent_head;
  my $paternal_parent_head;
  my $number_of_progeny;
  my $number_of_flowers;
  my $number_of_seeds;
  if ($worksheet->get_cell(0,0)) {
    $cross_name_head  = $worksheet->get_cell(0,0)->value();
  }
  if ($worksheet->get_cell(0,1)) {
    $cross_type_head  = $worksheet->get_cell(0,1)->value();
  }
  if ($worksheet->get_cell(0,2)) {
    $maternal_parent_head  = $worksheet->get_cell(0,2)->value();
  }
  if ($worksheet->get_cell(0,3)) {
    $paternal_parent_head  = $worksheet->get_cell(0,3)->value();
  }
  if ($worksheet->get_cell(0,4)) {
    $number_of_progeny  = $worksheet->get_cell(0,4)->value();
  }
  if ($worksheet->get_cell(0,5)) {
    $number_of_flowers  = $worksheet->get_cell(0,5)->value();
  }
  if ($worksheet->get_cell(0,6)) {
    $number_of_seeds  = $worksheet->get_cell(0,6)->value();
  }

  if (!$cross_name_head || $cross_name_head ne 'cross_name' ) {
    push @errors, "Cell A1: cross_name is missing from the header";
  }
  if (!$cross_type_head || $cross_type_head ne 'cross_type') {
    push @errors, "Cell B1: cross_type is missing from the header";
  }
  if (!$maternal_parent_head || $maternal_parent_head ne 'maternal_parent') {
    push @errors, "Cell C1: maternal_parent is missing from the header";
  }
  if (!$paternal_parent_head || $paternal_parent_head ne 'paternal_parent') {
    push @errors, "Cell D1: paternal_parent is missing from the header";
  }
  if ($number_of_progeny && $number_of_progeny ne 'number_of_progeny') {
    push @errors, "Cell E1: wrong header for number_of_progeny column";
  }
  if ($number_of_progeny && $number_of_flowers ne 'number_of_flowers') {
    push @errors, "Cell F1: wrong header for number_of_flowers column";
  }
  if ($number_of_progeny && $number_of_seeds ne 'number_of_seeds') {
    push @errors, "Cell G1: wrong header for number_of_seeds column";
  }

  for my $row ( 1 .. $row_max ) {
    my $row_name = $row+1;
    my $cross_name;
    my $cross_type;
    my $maternal_parent;
    my $paternal_parent;
    my $number_of_progeny;
    my $number_of_flowers;
    my $number_of_seeds;
    my $cross_stock;

    if ($worksheet->get_cell($row,0)) {
      $cross_name = $worksheet->get_cell($row,0)->value();
    }
    if ($worksheet->get_cell($row,1)) {
      $cross_type = $worksheet->get_cell($row,1)->value();
    }
    if ($worksheet->get_cell($row,2)) {
      $maternal_parent =  $worksheet->get_cell($row,2)->value();
    }
    if ($worksheet->get_cell($row,3)) {
      $paternal_parent =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $number_of_progeny =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $number_of_flowers =  $worksheet->get_cell($row,5)->value();
    }
    if ($worksheet->get_cell($row,6)) {
      $number_of_seeds =  $worksheet->get_cell($row,6)->value();
    }

    #skip blank lines or lines with no name, type and parent
    if (!$cross_name && !$cross_type && !$maternal_parent) {
      next;
    }

    #cross name must not be blank
    if (!$cross_name || $cross_name eq '') {
      push @errors, "Cell A$row_name: cross name missing";
    } else {
      #cross must not already exist in the database
      if ($self->_get_cross($cross_name)) {
	push @errors, "Cell A$row_name: cross name already exists: $cross_name";
      }
    }

    #cross type must not be blank
    if (!$cross_type || $cross_type eq '') {
      push @errors, "Cell B$row_name: cross type missing";
    } else {
      #cross type must be supported
      if ($cross_type ne "biparental" && $cross_type ne "self" && $cross_type ne "open") {
	push @errors, "Cell B$row_name: cross type not supported: $cross_type";
      }
    }

    #maternal parent must not be blank
    if (!$maternal_parent || $maternal_parent eq '') {
      push @errors, "Cell C$row_name: maternal parent missing";
    } else {
      #maternal parent must exist in the database
      if (!$self->_get_accession($maternal_parent)) {
	push @errors, "Cell C$row_name: maternal parent does not exist: $maternal_parent";
      }
    }

    #paternal parent must not be blank if type is biparental
    if (!$paternal_parent || $paternal_parent eq '') {
      if ($cross_type eq 'biparental') {
	push @errors, "Cell D$row_name: paternal parent required for biparental cross";
      }
    } else {
      #paternal parent must exist in the database
      if (!$self->_get_accession($paternal_parent)) {
	push @errors, "Cell D$row_name: paternal parent does not exist: $paternal_parent";
      }
    }

    #numbers of progeny, flowers, and seeds must be positive integers
    if ($number_of_progeny && !($number_of_progeny =~ /^\d+?$/)) {
      push @errors, "Cell E$row_name: number of progeny is not an integer: $number_of_progeny";
    }
    if ($number_of_flowers && !($number_of_flowers =~ /^\d+?$/)) {
      push @errors, "Cell F$row_name: number of flowers is not an integer: $number_of_flowers";
    }
    if ($number_of_seeds && !($number_of_seeds =~ /^\d+?$/)) {
      push @errors, "Cell G$row_name: number of seeds is not an integer: $number_of_seeds";
    }

  }

  #store any errors found in the parsed file to parse_errors accessor
  if (scalar(@errors) >= 1) {
    $self->_set_parse_errors(\@errors);
    return;
  }

  return 1; #returns true if validation is passed

}


sub _parse_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;
  my @pedigrees;
  my %progeny;
  my %flowers;
  my %seeds;
  my %parsed_result;

  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();

  for my $row ( 1 .. $row_max ) {
    my $cross_name;
    my $cross_type;
    my $maternal_parent;
    my $paternal_parent;
    my $number_of_progeny;
    my $number_of_flowers;
    my $number_of_seeds;
    my $cross_stock;

    if ($worksheet->get_cell($row,0)) {
      $cross_name = $worksheet->get_cell($row,0)->value();
    }
    if ($worksheet->get_cell($row,1)) {
      $cross_type = $worksheet->get_cell($row,1)->value();
    }
    if ($worksheet->get_cell($row,2)) {
      $maternal_parent =  $worksheet->get_cell($row,2)->value();
    }
    if ($worksheet->get_cell($row,3)) {
      $paternal_parent =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $number_of_progeny =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $number_of_flowers =  $worksheet->get_cell($row,5)->value();
    }
    if ($worksheet->get_cell($row,6)) {
      $number_of_seeds =  $worksheet->get_cell($row,6)->value();
    }

    #skip blank lines or lines with no name, type and parent
    if (!$cross_name && !$cross_type && !$maternal_parent) {
      next;
    }

    my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_name, cross_type=>$cross_type);
    if ($maternal_parent) {
      my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $maternal_parent);
      $pedigree->set_female_parent($female_parent_individual);
    }
    if ($paternal_parent) {
      my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $paternal_parent);
      $pedigree->set_male_parent($male_parent_individual);
    }

    push @pedigrees, $pedigree;

    if ($number_of_progeny) {
      $progeny{$cross_name} = $number_of_progeny;
    }
    if ($number_of_flowers) {
      $flowers{$cross_name} = $number_of_flowers;
    }
    if ($number_of_seeds) {
      $seeds{$cross_name} = $number_of_seeds;
    }

  }

  $parsed_result{'pedigrees'} = \@pedigrees;
  $parsed_result{'progeny'} = \%progeny;
  $parsed_result{'flowers'} = \%flowers;
  $parsed_result{'seeds'} = \%seeds;

  $self->_set_parsed_data(\%parsed_result);

  return 1;

}


sub _get_accession {
  my $self = shift;
  my $accession_name = shift;
  my $chado_schema = $self->get_chado_schema();
  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
  my $stock;
  my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
    ->create_with({
 		   name   => 'accession',
 		   cv     => 'stock type',
 		   db     => 'null',
 		   dbxref => 'accession',
 		  });
  $stock_lookup->set_stock_name($accession_name);
  $stock = $stock_lookup->get_stock_exact();

  if (!$stock) {
    return;
  }

  if ($stock->type_id() != $accession_cvterm->cvterm_id()) {
    return;
   }

  return $stock;

}


sub _get_cross {
  my $self = shift;
  my $cross_name = shift;
  my $chado_schema = $self->get_chado_schema();
  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
  my $stock;

  $stock_lookup->set_stock_name($cross_name);
  $stock = $stock_lookup->get_stock_exact();

  if (!$stock) {
    return;
  }

  return $stock;
}


1;

