
package CXGN::Trial::TrialDesign::Plugin::MAD;

use Moose::Role;

sub create_design {
    my $self = shift;
    my %madii_design;

    my $rbase = R::YapRI::Base->new();

    my @stock_list;
    my @control_list;
    my $control_list;
    my $maximum_block_size;
    my $number_of_blocks;

    my $number_of_rows;
    my $number_of_rows_per_block;
    my $number_of_cols_per_block;
    my $number_of_cols;


    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my %control_names_lookup;
    my @row_numbers;
    my @check_names;

    my @col_numbers;
    my @block_row_numbers;
    my @block_col_numbers;
    my $plot_layout_format;


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list_crbd()) {
    @control_list = @{$self->get_control_list_crbd()};
    $control_list = '"'.join('","',@{$self->get_control_list_crbd()}).'"';
    %control_names_lookup = map { $_ => 1 } @{$self->get_control_list_crbd()};
    $self->_check_controls_and_accessions_lists;
  } else {
    die "The list of checks is missing.\n";
    }


  if ($self->has_number_of_blocks()) {
      $number_of_blocks = $self->get_number_of_blocks();
    } else {
      die "Number of blocks not specified\n";
  }

  if ($self->has_number_of_rows()) {
      $number_of_rows = $self->get_number_of_rows();
    } else {
      die "Number of rows not specified\n";
  }

  if ($self->has_number_of_cols()) {
      $number_of_cols = $self->get_number_of_cols();
    } else {
      die "Number of columns not specified\n";
  }

  if ($self->has_plot_layout_format()) {
    $plot_layout_format = $self->get_plot_layout_format();
  }

  
  my $plot_start = $self->get_plot_start_number();

  print "The number of treatments: ". scalar(@stock_list)."\nThe number of checks: ".scalar(@control_list)."\nThe number of blocks: ".$number_of_blocks."\nThe plot layout is: ".$plot_layout_format."\n";


  $stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'stock_data_matrix',
							rown => 1,
							coln => scalar(@stock_list),
							data => \@stock_list,
						       }
						      );
  $control_stock_data_matrix =  R::YapRI::Data::Matrix->new(
						       {
							name => 'control_stock_data_matrix',
							rown => 1,
							coln => scalar(@control_list),
							data => \@control_list,
						       }
						      );


  $r_block = $rbase->create_block('r_block');
  $stock_data_matrix->send_rbase($rbase, 'r_block');
  $control_stock_data_matrix->send_rbase($rbase, 'r_block');

  $r_block->add_command('library(FielDHub)');

  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');

  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);
  $r_block->add_command('number_of_rows <- '.$number_of_rows);
  $r_block->add_command('number_of_cols <- '.$number_of_cols);
  $r_block->add_command('plot_start <- '.$plot_start);

  # Converting name to FielDHub package format
  if ($plot_layout_format eq "serpentine") {
    $r_block->add_command('plot_layout <-"serpentine"');
  } else {
    $r_block->add_command('plot_layout <- "cartesian"');
  }

  $r_block->add_command('treatment_list <- data.frame(list(ENTRY = 1:length(append(control_trt, trt)), NAME = c(control_trt, trt)))');
  $r_block->add_command('design.mad<-RCBD_augmented(lines = length(trt),
                                                    checks = length(control_trt),
                                                    b = number_of_blocks,
                                                    plotNumber = plot_start, 
                                                    l = 1,
                                                    planter = plot_layout,
                                                    nrows = number_of_rows,
                                                    ncols = number_of_cols,
                                                    data = treatment_list)');
  $r_block->add_command('augmented<-design.mad$fieldBook[design.mad$fieldBook$PLOT != 0,]');
  $r_block->add_command('augmented <- as.matrix(augmented)');

   my @commands = $r_block->read_commands();
   print STDERR join "\n", @commands;
   print STDERR "\n";

  $r_block->run_block();
  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("PLOT");
  @row_numbers = $result_matrix->get_column("ROW");
  @col_numbers = $result_matrix->get_column("COLUMN");
  # @block_row_numbers=$result_matrix->get_column("Row.Blk");
  # @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("BLOCK");
  @stock_names = $result_matrix->get_column("TREATMENT");
  @check_names=$result_matrix->get_column("CHECKS");

  # @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@block_numbers, $number_of_blocks)};

  # if ($plot_layout_format eq "serpentine") {
  #   my @serpentine_plot_numbers = ();
  #   my @plot_numbers_to_be_reversed = ();

  #   for my $index (0 .. $#plot_numbers) {
  #       if ($col_numbers[$index] %2 == 0) {
  #           # save plot numbers from even numbered columns for reversal
  #           push @plot_numbers_to_be_reversed, $plot_numbers[$index];
  #       } else {
  #           # use plot numbers from odd numbered as is
  #           if ($row_numbers[$index] == 1) {
  #               # if in first row of new odd column, push last even column reversal
  #               @serpentine_plot_numbers = (@serpentine_plot_numbers, reverse @plot_numbers_to_be_reversed);
  #               @plot_numbers_to_be_reversed = ();
  #               push @serpentine_plot_numbers, $plot_numbers[$index];
  #           } else {
  #               push @serpentine_plot_numbers, $plot_numbers[$index];
  #           }
  #       }
  #   }
  #   @serpentine_plot_numbers = (@serpentine_plot_numbers, reverse @plot_numbers_to_be_reversed);
  #   @plot_numbers = @serpentine_plot_numbers;
  # }

  my %seedlot_hash;
  if($self->get_seedlot_hash){
      %seedlot_hash = %{$self->get_seedlot_hash};
  }

  for (my $i = 0; $i < scalar(@plot_numbers); $i++) {

    my %plot_info;
    $plot_info{'row_number'} =$row_numbers[$i];
    $plot_info{'col_number'} =$col_numbers[$i];
    $plot_info{'check_name'} =$check_names[$i];
    $plot_info{'stock_name'} = $stock_names[$i];
    $plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
    if ($plot_info{'seedlot_name'}){
        $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
    }
    $plot_info{'block_number'} = $block_numbers[$i];
    # $plot_info{'rep_number'} = $block_numbers[$i];
    # $plot_info{'block_row_number'}=$block_row_numbers[$i];
    # $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $plot_numbers[$i];
    $plot_info{'plot_number'} = $plot_numbers[$i];
    $plot_info{'plot_num_per_block'} = $plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madii_design{$plot_numbers[$i]} = \%plot_info;
  }

  %madii_design = %{$self->_build_plot_names(\%madii_design)};

 return \%madii_design;

#=cut

}


1;
