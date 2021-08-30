
package CXGN::Trial::TrialDesign::Plugin::RCBD;

use Moose::Role;

sub create_design {
  my $self = shift;
  my %rcbd_design;
  my $rbase = R::YapRI::Base->new();
  my @stock_list;
  my $number_of_blocks;
  my $stock_data_matrix;
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
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }
  if ($self->has_control_list_crbd()) {
    @control_list_crbd = @{$self->get_control_list_crbd()};
    %control_names_lookup = map { $_ => 1 } @control_list_crbd;
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
  $r_block->add_command('library(agricolae)');
  $r_block->add_command('trt <- stock_data_matrix[1,]');
  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
  if ($self->has_randomization_seed()){
    $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    $r_block->add_command('rcbd<-design.rcbd(trt,number_of_blocks,serie='.$serie.',kinds=randomization_method, seed=randomization_seed)');
  }
  else {
    $r_block->add_command('rcbd<-design.rcbd(trt,number_of_blocks,serie='.$serie.',kinds=randomization_method)');
  }
  $r_block->add_command('rcbd<-rcbd$book'); #added for agricolae 1.1-8 changes in output
  if($plot_start == 1){ #Use row numbers as plot names to avoid unwanted agricolae plot num pattern
    $r_block->add_command('rcbd$plots <- row.names(rcbd)');
  }
  $r_block->add_command('rcbd<-as.matrix(rcbd)');
  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','rcbd');
  #print STDERR Dumper $result_matrix;
  @plot_numbers = $result_matrix->get_column("plots");
  #print STDERR Dumper \@plot_numbers;
  @block_numbers = $result_matrix->get_column("block");
  @stock_names = $result_matrix->get_column("trt");
  # @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@block_numbers, $number_of_blocks)};

  #generate col_number

  if ($plot_layout_format eq "zigzag") {
    if (!$fieldmap_col_number){
      @col_number_fieldmaps = ((1..(scalar(@stock_list))) x $number_of_blocks);
    } else {
      @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
    }
  }
  elsif ($plot_layout_format eq "serpentine") {
    if (!$fieldmap_row_number)  {
      for my $rep (1 .. $number_of_blocks){
        if ($rep % 2){
          push @col_number_fieldmaps, (1..(scalar(@stock_list)));
        } else {
          push @col_number_fieldmaps, (reverse 1..(scalar(@stock_list)));
        }
      }
    } else {
      for my $rep (1 .. $fieldmap_row_number){
        if ($rep % 2){
          push @col_number_fieldmaps, (1..$fieldmap_col_number);
        } else {
          push @col_number_fieldmaps, (reverse 1..$fieldmap_col_number);
        }
      }
    }
  }

  if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
    @fieldmap_row_numbers = (@block_numbers);
  }
  elsif ($plot_layout_format && $fieldmap_row_number){
      @fieldmap_row_numbers = ((1..$fieldmap_row_number) x $fieldmap_col_number);
      @fieldmap_row_numbers = sort {$a <=> $b} @fieldmap_row_numbers;
    }

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
    $rcbd_design{$plot_numbers[$i]} = \%plot_info;
  }
  %rcbd_design = %{$self->_build_plot_names(\%rcbd_design)};
  return \%rcbd_design;
}

1;
