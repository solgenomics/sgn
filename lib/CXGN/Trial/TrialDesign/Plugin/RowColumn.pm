
package CXGN::Trial::TrialDesign::Plugin::RCD;

use Moose::Role;

sub create_design {
  my $self = shift;
  my %rcd_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $number_of_blocks;
  my $stock_data_matrix;
  my $control_data_matrix;
  my $r_block;
  my $result_matrix;
  my @plot_numbers;
  my @stock_names;
  my @control_names_crbd;
  my @block_numbers;
  my @converted_plot_numbers;
  my @control_list;
  my %control_names_lookup;
  my $fieldmap_row_number;
  my @fieldmap_row_numbers;
  my $fieldmap_col_number;
  my $plot_layout_format;
  my @col_number_fieldmaps;

  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    $self->_check_controls_and_accessions_lists;
  }
  if ($self->has_number_of_blocks()) {
    $number_of_blocks = $self->get_number_of_blocks();
  } else {
    die "Number of blocks not specified\n";
  }

  if ($self->has_fieldmap_col_number()) {
    $fieldmap_col_number = $self->get_fieldmap_col_number();
  }
  if ($self->has_fieldmap_row_number()) {
    $fieldmap_row_number = $self->get_fieldmap_row_number();
    my $colNumber = ((scalar(@stock_list) * $number_of_blocks)/$fieldmap_row_number);
    $fieldmap_col_number = CXGN::Trial::TrialDesign::validate_field_colNumber($colNumber);
  }
  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
                              {
                           name => 'stock_data_matrix',
                           rown => 1,
                           coln => scalar(@stock_list),
                           data => \@stock_list,
                              }
                             );

  $control_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  my $plot_start = $self->get_plot_start_number();
  my $serie;
  if($plot_start == 1){
      $serie = 1;
  }elsif($plot_start == 101){
      $serie = 2;
  }elsif($plot_start == 1001){
      $serie = 3;
  }

  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_data_matrix->send_rbase($rbase, 'r_block');
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('library(blocksdesign)');
  $r_block->add_command('treatments <- stock_data_matrix[1,]');
  $r_block->add_command('controls <- control_data_matrix[1,]');
  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('number_of_rows <- '.$fieldmap_row_number);
  $r_block->add_command('number_of_cols <- '.$fieldmap_col_number);

  $r_block->add_command('RCDblocks <- data.frame(
    block = gl(number_of_blocks,length(treatments)),
    row = gl(number_of_rows,1),
    col = gl(number_of_cols,number_of_rows)
  )');
  $r_block->add_command('RCD <- design(treatments, RCDblocks)$Design');
  # $r_block->add_command('RCD <- transform(RCD, is_a_control = ifelse(RCD$treatments %in% controls, TRUE, FALSE))');

  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','RCD');
  print STDERR Dumper $result_matrix;
  @plot_numbers = $result_matrix->get_column("plots");
  print STDERR Dumper \@plot_numbers;
  @block_numbers = $result_matrix->get_column("block");
  @stock_names = $result_matrix->get_column("treatments");
  @fieldmap_row_numbers = $result_matrix->get_column("row");
  @col_number_fieldmaps = $result_matrix->get_column("col");

  # alter plot numbers for serpentine or custom start number

    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
  for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
    my %plot_info;
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    $plot_info{'plot_name'} = $plot_numbers[$i];
    $plot_info{'rep_number'} = $block_numbers[$i];
    #$plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'plot_number'} = $plot_numbers[$i];
    $plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    #$plot_info_per_block{}
      if ($fieldmap_row_numbers[$i]){
      $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
      $plot_info{'col_number'} = $col_number_fieldmaps[$i];
    }
    $rcd_design{$plot_numbers[$i]} = \%plot_info;
  }
  %rcd_design = %{$self->_build_plot_names(\%rcd_design)};
  return \%rcd_design;
}

1;
