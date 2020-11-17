
package CXGN::Trial::TrialDesign::Plugin::MAD;

use Moose::Role;

sub create_design {
      my $self = shift;
    my %madiii_design;

    my $rbase = R::YapRI::Base->new();

    my @stock_list;
    my @control_list;
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


  if ($self->has_stock_list()) {
    @stock_list = @{$self->get_stock_list()};
  } else {
    die "No stock list specified\n";
  }

  if ($self->has_control_list()) {
    @control_list = @{$self->get_control_list()};
    %control_names_lookup = map { $_ => 1 } @control_list;
    $self->_check_controls_and_accessions_lists;
  } else {
    die "No list of control stocks specified.  Required for augmented design.\n";
  }


    if ($self->has_number_of_rows()) {
    $number_of_rows = $self->get_number_of_rows();
    } else {
    die "Number of rows not specified\n";
    }

    if ($self->has_block_row_numbers()) {
    $number_of_rows_per_block = $self->get_block_row_numbers();
    } else {
    die "Number of block row not specified\n";
    }

    if ($self->has_block_col_numbers()) {
    $number_of_cols_per_block = $self->get_block_col_numbers();
    } else {
    die "Number of block col not specified\n";
    }

    if ($self->has_number_of_cols()) {
    $number_of_cols = $self->get_number_of_cols();
    } else {
    die "Number of blocks not specified\n";
    }

    #system("R --slave --args $tempfile $tempfile_out < R/MADII_layout_function.R");
#     system("R --slave < R/MADII_layout_function.R");


#    if ($self->has_maximum_row_number()) {
#    $maximum_row_number = $self->get_maximum_row_number();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#
#  } else {
#    die "No block size specified\n";
#  }


#  if ($self->has_maximum_block_size()) {
#    $maximum_block_size = $self->get_maximum_block_size();
#    if ($maximum_block_size <= scalar(@control_list)) {
#      die "Maximum block size must be greater the number of control stocks for augmented design\n";
#    }
#    if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
#      die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
#    }
#    $number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
#  } else {
#    die "No block size specified\n";
#  }

#=comment

  print "@stock_list\n";


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

 #$r_block->add_command('library(agricolae)');

  $r_block->add_command('library(MAD)');

  $r_block->add_command('trt <- as.array(stock_data_matrix[1,])');
  $r_block->add_command('control_trt <- as.array(control_stock_data_matrix[1,])');

#  $r_block->add_command('acc<-c(seq(1,330,1))');
#  $r_block<-add_command('chk<-c(seq(1,4,1))');

#  $r_block->add_command('trt <- acc');
#  $r_block->add_command('control_trt <- chk');
#  $r_block->add_command('number_of_blocks <- '.$number_of_blocks);

# $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

 # if ($self->has_randomization_seed()){
 #   $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method, seed=randomization_seed)');
 # }
 # else {
 #   $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');
 # }

 #$r_block->add_command('test.ma<-design.dma(entries=c(seq(1,330,1)),chk.names=c(seq(1,4,1)),num.rows=9, num.cols=NULL, num.sec.chk=3)');

  $r_block->add_command('number_of_rows <- '.$number_of_rows);
  $r_block->add_command('number_of_cols <- '.$number_of_cols);
  $r_block->add_command('number_of_rows_per_block <- '.$number_of_rows_per_block);
  $r_block->add_command('number_of_cols_per_block <- '.$number_of_cols_per_block);

  $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,nFieldRow=number_of_rows,nFieldCols=number_of_cols,nRowsPerBlk=number_of_rows_per_block, nColsPerBlk=number_of_cols_per_block)');


 # $r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

  #$r_block->add_command('test.ma<-design.dma(entries=trt,chk.names=control_trt,num.rows=9, num.cols=NULL, num.sec.chk=3)');

# $r_block->add_command('augmented<-design.dau(control_trt,trt,number_of_blocks,serie=1,kinds=randomization_method)');

# $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output

  $r_block->add_command('augmented<-test.ma[[2]]'); #added for agricolae 1.1-8 changes in output
  $r_block->add_command('augmented<-as.matrix(augmented)');

#  $r_block<-add_command('colnames(augmented)[2]<-"plots"');
#  $r_block<-add_command('colnames(augmented)[3]<-"trt"');
#  $r_block<-add_command('colnames(augmented)[7]<-"block"');


   my @commands = $r_block->read_commands();
   print STDERR join "\n", @commands;
   print STDERR "\n";


  $r_block->run_block();

  $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');

  @plot_numbers = $result_matrix->get_column("Plot");
  @row_numbers = $result_matrix->get_column("Row");
  @col_numbers = $result_matrix->get_column("Col");
  @block_row_numbers=$result_matrix->get_column("Row.Blk");
  @block_col_numbers=$result_matrix->get_column("Col.Blk");
  @block_numbers = $result_matrix->get_column("Blk");
  @stock_names = $result_matrix->get_column("Entry");
  @check_names=$result_matrix->get_column("Check");

my $max = max( @block_numbers );
#Row.Blk Col.Blk



  @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@block_numbers, $max)};

  my %seedlot_hash;
  if($self->get_seedlot_hash){
      %seedlot_hash = %{$self->get_seedlot_hash};
  }
  for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
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
    $plot_info{'block_row_number'}=$block_row_numbers[$i];
    $plot_info{'block_col_number'}=$block_col_numbers[$i];
    $plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'plot_number'} = $converted_plot_numbers[$i];
    $plot_info{'plot_num_per_block'} = $converted_plot_numbers[$i];
    $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
    $madiii_design{$converted_plot_numbers[$i]} = \%plot_info;
  }

  %madiii_design = %{$self->_build_plot_names(\%madiii_design)};

#  return \%augmented_design;

 #call R code and create design data structure

 return \%madiii_design;

#=cut

}


1;
