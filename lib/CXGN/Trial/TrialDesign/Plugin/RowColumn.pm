
package CXGN::Trial::TrialDesign::Plugin::RCD;

use Moose::Role;

sub create_design {
  my $self = shift;
  my %rcd_design;
  my $rbase = R::YapRI::Base->new();
  my $stock_list;
  my $control_list;
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
  my @control_list_crbd;
  my %control_names_lookup;
  my $fieldmap_row_number;
  my @fieldmap_row_numbers;
  my $fieldmap_col_number;
  my $plot_layout_format;
  my @col_number_fieldmaps;

  if ($self->has_stock_list()) {
    @stock_list = '"'.join('","',@{$self->get_stock_list()}).'"';
    # @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list_crbd()) {
    $control_list = '"'.join('","',@{$self->get_control_list_crbd()}).'"';
    %control_names_lookup = map { $_ => 1 } @{$self->get_control_list_crbd()};
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

  my $plot_start = $self->get_plot_start_number();
  my $serie;
  if($plot_start == 1){
      $serie = 1;
  }elsif($plot_start == 101){
      $serie = 2;
  }elsif($plot_start == 1001){
      $serie = 3;
  }

  my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"trialdesigns/rc_XXXXX");

  my $people_schema = $c->dbic_schema("CXGN::People::Schema");
  my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
  my $temppath = $c->config->{basepath}."/".$tempfile;

  my $param_file = $temppath.".params";
  open(my $F, ">", $param_file) || die "Can't open $param_file for writing.";
  print $F "treatments <- c($stock_list)\n";
  print $F "controls <- c($control_list)\n";
  print $F "nRep <- ".$number_of_blocks."\n";
  print $F "nRow <- ".$fieldmap_row_number."\n";
  print $F "nCol <- ".$fieldmap_row_number."\n";
  print $F "serie <- ".$serie."\n";
  close($F);
  #
  # print $F "dependent_variables <- c($dependent_variables)\n";
  # print $F "random_factors <- c($random_factors)\n";
  # print $F "fixed_factors <- c($fixed_factors)\n";
  #
  # print $F "model <- \"$model\"\n";
  # close($F);

  my $cmd = "R CMD BATCH  '--args paramfile=\"".$temppath.".params\"' " .  " R/row_column_design.R ".$temppath.".out";
  print STDERR "running R command $cmd...\n";

  my $design_file = $temppath.".design";
  open my $deisgn, $design_file or die "Could not open $design_file: $!";

  # $stock_data_matrix =  R::YapRI::Data::Matrix->new(
  #                             {
  #                          name => 'stock_data_matrix',
  #                          rown => 1,
  #                          coln => scalar(@stock_list),
  #                          data => \@stock_list,
  #                             }
  #                            );
  #
  # $control_data_matrix =  R::YapRI::Data::Matrix->new(
	# 					       {
	# 						name => 'control_data_matrix',
	# 						rown => 1,
	# 						coln => scalar(@control_list),
	# 						data => \@control_list,
	# 					       }
	# 					      );
  #
  # $r_block = $rbase->create_block('r_block');
  # $stock_data_matrix->send_rbase($rbase, 'r_block');
  # $control_data_matrix->send_rbase($rbase, 'r_block');
  # $r_block->add_command('library(agricolae)');
  # $r_block->add_command('library(blocksdesign)');
  # $r_block->add_command('treatments <- stock_data_matrix[1,]');
  # $r_block->add_command('controls <- control_data_matrix[1,]');
  # $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  # $r_block->add_command('number_of_rows <- '.$fieldmap_row_number);
  # $r_block->add_command('number_of_cols <- '.$fieldmap_col_number);
  #
  # $r_block->add_command('RCDblocks <- data.frame(
  #   block = gl(number_of_blocks,length(treatments)),
  #   row = gl(number_of_rows,1),
  #   col = gl(number_of_cols,number_of_rows)
  # )');
  # $r_block->add_command('RCD <- design(treatments, RCDblocks)$Design');
  # # $r_block->add_command('RCD <- transform(RCD, is_a_control = ifelse(RCD$treatments %in% controls, TRUE, FALSE))');
  #
  # $r_block->run_block();
  # $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','RCD');
  # print STDERR Dumper $result_matrix;
  @block_numbers = split('\t', $design);
  @fieldmap_row_numbers = split('\t', $design);
  @col_number_fieldmaps = split('\t', $design);
  @plot_numbers = split('\t', $design);
  @stock_names = split('\t', $design);
  @is_a_control = split('\t', $design);

  # @plot_numbers = split('\t', $design);

  # alter plot numbers for serpentine or custom start number

  # my $plot_start = $self->get_plot_start_number();
  #
  # if ($plot_layout_format eq "zigzag") {
  #
  # } elsif ($plot_layout_format eq "serpentine") {
  #
  # }
  #
  # if ($plot_start == 1){
  #
  # } elsif($plot_start == 101){
  #
  # } elsif($plot_start == 1001){
  #
  # }

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
    $plot_info{'is_a_control'} = $is_a_control[$i];
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
