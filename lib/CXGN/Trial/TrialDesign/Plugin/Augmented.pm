
package CXGN::Trial::TrialDesign::Plugin::Augmented;

use Moose::Role;
use POSIX; # for ceil function
use List::Util qw| max |;
use Data::Dumper;
use POSIX;

sub create_design {
    my $self = shift;
    my %augmented_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my @control_list;
    my $maximum_block_size;
    my $number_of_blocks;
    my $stock_data_matrix;
    my $control_stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
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
    } else {
	die "No list of control stocks specified.  Required for augmented design.\n";
    }

    if ($self->has_maximum_block_size()) {
	$maximum_block_size = $self->get_maximum_block_size();
	# if ($maximum_block_size <= scalar(@control_list)) {
	#     die "Maximum block size must be greater the number of control stocks for augmented design\n";
	# }
	if ($maximum_block_size >= scalar(@control_list)+scalar(@stock_list)) {
	    die "Maximum block size must be less than the number of stocks plus the number of controls for augmented design\n";
	}
	$number_of_blocks = ceil(scalar(@stock_list)/($maximum_block_size-scalar(@control_list)));
    } else {
	die "No block size specified\n";
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
    $r_block->add_command('library(agricolae)');
    $r_block->add_command('trt <- stock_data_matrix[1,]');
    $r_block->add_command('control_trt <- control_stock_data_matrix[1,]');
    $r_block->add_command('number_of_blocks <- '.$maximum_block_size);

    $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
    if ($self->has_randomization_seed()){
	$r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
    my $cmd = "augmented<-design.dau(control_trt,trt,number_of_blocks,serie=".$serie.",kinds=randomization_method, seed=randomization_seed)";
	$r_block->add_command($cmd);
    }
    else {
    my $cmd = "augmented<-design.dau(control_trt,trt,number_of_blocks,serie=".$serie.",kinds=randomization_method)";
	$r_block->add_command($cmd);
    }
    $r_block->add_command('augmented<-augmented$book'); #added for agricolae 1.1-8 changes in output
    if($plot_start == 1){ #Use row numbers as plot names to avoid unwanted agricolae plot num pattern
      $r_block->add_command('augmented$plots <- row.names(augmented)');
    }
    $r_block->add_command('augmented<-as.matrix(augmented)');
    $r_block->run_block();
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','augmented');
    @plot_numbers = $result_matrix->get_column("plots");
    @block_numbers = $result_matrix->get_column("block");
    @stock_names = $result_matrix->get_column("trt");

    my $max = max( @block_numbers );
    # @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@block_numbers, $max)};

    @fieldmap_row_numbers = @block_numbers;
    my $max_cols = ceil((scalar(@stock_list)+($maximum_block_size*scalar(@control_list)))/$maximum_block_size);

    if ($plot_layout_format eq "zigzag") {
        my $i = 1;
        my $count = 0;
        foreach my $blck (@block_numbers){
            if ($blck == $i){
                $count++;
            }else{
                push @col_number_fieldmaps, (1..$count);
                $count=1;
                $i++;
            }
        }
        push @col_number_fieldmaps, (1..$count);
    } elsif ($plot_layout_format eq "serpentine") {
        if (!$fieldmap_row_number)  {
            my $i = 1;
            my $count = 0;
            foreach my $blck (@block_numbers){
                if ($blck == $i){
                    $count++;
                }else{
                    if($blck % 2 == 0){
                       push @col_number_fieldmaps, (1..$count);
                       $count = 1;
                       $i++;
                    }else{
                        push @col_number_fieldmaps, (reverse 1..$count);
                        $count = 1;
                        $i++ ;
                    }
                }
            }
            if($i % 2 == 0){
                push @col_number_fieldmaps, (reverse 1..$count);
            } else {
                push @col_number_fieldmaps, (1..$count);
            }
        } else {
        for my $rep (1 .. $max){
          if ($rep % 2){
            push @col_number_fieldmaps, (1..$fieldmap_col_number);
          } else {
            push @col_number_fieldmaps, (reverse 1..$fieldmap_col_number);
          }
        }
      }
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
	$plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
	$plot_info{'plot_number'} = $plot_numbers[$i];
	$plot_info{'plot_num_per_block'} = $plot_numbers[$i];

    if ($fieldmap_row_numbers[$i]){
        $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
        $plot_info{'col_number'} = $col_number_fieldmaps[$i];
    }
	$augmented_design{$plot_numbers[$i]} = \%plot_info;
    #print Dumper(\%plot_info);
    }

    %augmented_design = %{$self->_build_plot_names(\%augmented_design)};
    return \%augmented_design;
}

1;
