package CXGN::Pedigree::ParseUpload::Plugin::CrossesExcelFormat;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;

sub _validate_with_plugin {
  my $self = shift;
  my $filename = $self->get_filename();
  my $schema = $self->get_chado_schema();
  my @errors;
  my %supported_cross_types;
  my $parser   = Spreadsheet::ParseExcel->new();
  my $excel_obj;
  my $worksheet;
  my %seen_cross_names;

  #currently supported cross types
  $supported_cross_types{'biparental'} = 1; #both parents required
  $supported_cross_types{'self'} = 1; #only female parent required
  $supported_cross_types{'open'} = 1; #only female parent required
  $supported_cross_types{'bulk'} = 1; #both parents required
  $supported_cross_types{'bulk_self'} = 1; #only female parent required
  $supported_cross_types{'bulk_open'} = 1; #only female parent required
  $supported_cross_types{'doubled_haploid'} = 1; #only female parent required

  #try to open the excel file and report any errors
  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    push @errors,  $parser->error();
    $self->_set_parse_errors(\@errors);
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();
  if (($col_max - $col_min)  < 3 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of crosses
    push @errors, "Spreadsheet is missing header or required column";
    $self->_set_parse_errors(\@errors);
    return;
  }

  #get column headers
  my $cross_name_head;
  my $cross_type_head;
  my $female_parent_head;
  my $male_parent_head;
  my $female_plot_head;
  my $male_plot_head;

  if ($worksheet->get_cell(0,0)) {
    $cross_name_head  = $worksheet->get_cell(0,0)->value();
  }
  if ($worksheet->get_cell(0,1)) {
    $cross_type_head  = $worksheet->get_cell(0,1)->value();
  }
  if ($worksheet->get_cell(0,2)) {
    $female_parent_head  = $worksheet->get_cell(0,2)->value();
  }
  if ($worksheet->get_cell(0,3)) {
    $male_parent_head  = $worksheet->get_cell(0,3)->value();
  }
  if ($worksheet->get_cell(0,4)) {
    $female_plot_head  = $worksheet->get_cell(0,4)->value();
  }
  if ($worksheet->get_cell(0,5)) {
    $male_plot_head  = $worksheet->get_cell(0,5)->value();
  }

#  my $cv_id = $schema->resultset('Cv::Cv')->search({name => 'nd_experiment_property', })->first()->cv_id();
#  my $cross_property_rs = $schema->resultset('Cv::Cvterm')->search({ cv_id => $cv_id, });

  for my $column ( 6 .. $col_max ) {
    my $header_string = $worksheet->get_cell(0,$column)->value();
  }
#    my $matching_cross_property_row = $cross_property_rs->search({ name => $header_string, });
#    if ($matching_cross_property_row->first) {
#      my $matching_term = $matching_cross_property_row->first->name;
#      if (!$matching_term) {
#        push @errors, "Header property $header_string is not supported\n";
#      }
#    }
#  }

  if (!$cross_name_head || $cross_name_head ne 'cross_name' ) {
    push @errors, "Cell A1: cross_name is missing from the header";
  }
  if (!$cross_type_head || $cross_type_head ne 'cross_type') {
    push @errors, "Cell B1: cross_type is missing from the header";
  }
  if (!$female_parent_head || $female_parent_head ne 'female_parent') {
    push @errors, "Cell C1: female_parent is missing from the header";
  }
  if (!$male_parent_head || $male_parent_head ne 'male_parent') {
    push @errors, "Cell D1: male_parent is missing from the header";
  }

  for my $row ( 1 .. $row_max ) {
    my $row_name = $row+1;
    my $cross_name;
    my $cross_type;
    my $female_parent;
    my $male_parent;
    my $female_plot_name;
    my $male_plot_name;
    my $cross_stock;

    if ($worksheet->get_cell($row,0)) {
      $cross_name = $worksheet->get_cell($row,0)->value();
    }
    if ($worksheet->get_cell($row,1)) {
      $cross_type = $worksheet->get_cell($row,1)->value();
    }
    if ($worksheet->get_cell($row,2)) {
      $female_parent =  $worksheet->get_cell($row,2)->value();
    }
    #skip blank lines or lines with no name, type and parent
    if (!$cross_name && !$cross_type && !$female_parent) {
      next;
    }
    if ($worksheet->get_cell($row,3)) {
      $male_parent =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $female_plot_name =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $male_plot_name =  $worksheet->get_cell($row,5)->value();
    }

    for my $column ( 6 .. $col_max ) {
      if ($worksheet->get_cell($row,$column)) {
        my $info_value = $worksheet->get_cell($row,$column)->value();
        my $info_type = $worksheet->get_cell(0,$column)->value();
        if ( ($info_type =~ m/days/  || $info_type =~ m/number/) && !($info_value =~ /^\d+?$/) ) {
          push @errors, "Cell $info_type:$row_name: is not a positive integer: $info_value";
        }
        elsif ( $info_type =~ m/date/ && !($info_value =~ m/(\d{4})\/(\d{2})\/(\d{2})/) ) {
          push @errors, "Cell $info_type:$row_name: is not a valid date: $info_value. Dates need to be of form YYYY/MM/DD";
        }
      }
    }

    #cross name must not be blank
    if (!$cross_name || $cross_name eq '') {
      push @errors, "Cell A$row_name: cross name missing";
    } else {

    #cross must not already exist in the database
      if ($self->_get_cross($cross_name)) {
	push @errors, "Cell A$row_name: cross name already exists: $cross_name";
      }
      if ($seen_cross_names{$cross_name}) {
	push @errors, "Cell A$row_name: duplicate cross name at cell A".$seen_cross_names{$cross_name}.": $cross_name";
      }
      $seen_cross_names{$cross_name}=$row_name;
    }

    #cross type must not be blank
    if (!$cross_type || $cross_type eq '') {
      push @errors, "Cell B$row_name: cross type missing";
    } else {
      #cross type must be supported
      if (!$supported_cross_types{$cross_type}){
	push @errors, "Cell B$row_name: cross type not supported: $cross_type";
      }
    }

    #female parent must not be blank
    if (!$female_parent || $female_parent eq '') {
        push @errors, "Cell C$row_name: female parent missing";
    } else {
      #female parent must exist in the database
    if (!$self->_get_accession($female_parent)) {
	      push @errors, "Cell C$row_name: female parent does not exist: $female_parent";
        }
    }

    #male parent must not be blank if type is biparental or bulk
    if (!$male_parent || $male_parent eq '') {
        if ($cross_type eq ( 'biparental' || 'bulk' )) {
	          push @errors, "Cell D$row_name: male parent required for biparental and bulk crosses";
        }
    } else {
      #male parent must exist in the database
        if (!$self->_get_accession($male_parent)) {
	          push @errors, "Cell D$row_name: male parent does not exist: $male_parent";
      }
    }

      #female plot must exist in the database
      if (!$self->_get_plot($female_plot_name)){
          push @errors, "Cell E$row_name: female plot does not exist: $female_plot_name";
      }

      #female plot must exist in the database
      if (!$self->_get_plot($male_plot_name)){
          push @errors, "Cell F$row_name: male plot does not exist: $male_plot_name";
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
  my %additional_properties;
  my %properties_columns;
  my %parsed_result;

  $excel_obj = $parser->parse($filename);
  if ( !$excel_obj ) {
    return;
  }

  $worksheet = ( $excel_obj->worksheets() )[0];
  my ( $row_min, $row_max ) = $worksheet->row_range();
  my ( $col_min, $col_max ) = $worksheet->col_range();

#  my $cv_id = $schema->resultset('Cv::Cv')->search({name => 'nd_experiment_property', })->first()->cv_id();
#  my $cross_property_rs = $schema->resultset('Cv::Cvterm')->search({ cv_id => $cv_id, });

  for my $column ( 6 .. $col_max ) {
    my $header_string = $worksheet->get_cell(0,$column)->value();
#    my $matching_cross_property_row = $cross_property_rs->search({ name => $header_string, });
#    if ($matching_cross_property_row->first) {
      $properties_columns{$column} = $header_string;
      $additional_properties{$header_string} = ();
#    }
  }

  for my $row ( 1 .. $row_max ) {
    my $cross_name;
    my $cross_type;
    my $female_parent;
    my $male_parent;
    my $female_plot;
    my $male_plot;
    my $cross_stock;

    if ($worksheet->get_cell($row,0)) {
      $cross_name = $worksheet->get_cell($row,0)->value();
    }
    if ($worksheet->get_cell($row,1)) {
      $cross_type = $worksheet->get_cell($row,1)->value();
    }
    if ($worksheet->get_cell($row,2)) {
      $female_parent =  $worksheet->get_cell($row,2)->value();
    }

    #skip blank lines or lines with no name, type and parent
    if (!$cross_name && !$cross_type && !$female_parent) {
      next;
    }

    if ($worksheet->get_cell($row,3)) {
      $male_parent =  $worksheet->get_cell($row,3)->value();
    }
    if ($worksheet->get_cell($row,4)) {
      $female_plot =  $worksheet->get_cell($row,4)->value();
    }
    if ($worksheet->get_cell($row,5)) {
      $male_plot =  $worksheet->get_cell($row,5)->value();
    }

    for my $column ( 6 .. $col_max ) {
      if ($worksheet->get_cell($row,$column)) {
        my $column_property = $properties_columns{$column};
        $additional_properties{$column_property}{$cross_name} = $worksheet->get_cell($row,$column)->value();
        if ($row == $row_max) {
          my $info_type = $worksheet->get_cell(0,$column)->value();
          $parsed_result{$info_type} = $additional_properties{$column_property};
        }
      }
    }

    my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$cross_name, cross_type=>$cross_type);
    if ($female_parent) {
      my $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
      $pedigree->set_female_parent($female_parent_individual);
    }
    if ($male_parent) {
      my $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
      $pedigree->set_male_parent($male_parent_individual);
    }
    if ($female_plot) {
      my $female_plot_individual = Bio::GeneticRelationships::Individual->new(name => $female_plot);
      $pedigree->set_female_plot($female_plot_individual);
    }
    if ($male_plot) {
      my $male_plot_individual = Bio::GeneticRelationships::Individual->new(name => $male_plot);
      $pedigree->set_male_plot($male_plot_individual);
    }

    push @pedigrees, $pedigree;

  }

  $parsed_result{'crosses'} = \@pedigrees;

  $self->_set_parsed_data(\%parsed_result);

  return 1;

}


sub _get_accession {
  my $self = shift;
  my $accession_name = shift;
  my $chado_schema = $self->get_chado_schema();
  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
  my $stock;
  my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');

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

sub _get_plot {
  my $self = shift;
  my $plot_name = shift;
  my $chado_schema = $self->get_chado_schema();
  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
  my $stock;
  my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type');

  $stock_lookup->set_stock_name($plot_name);
  $stock = $stock_lookup->get_stock_exact();

  if (!$stock) {
    return;
  }

  if ($stock->type_id() != $plot_cvterm->cvterm_id()) {
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
