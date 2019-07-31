
package CXGN::Trial::TrialDesign::Plugin::Lattice;

use Moose::Role;
use List::Util qw| max |;

sub create_design {
    my $self = shift;
    my %lattice_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $number_of_blocks;
    my $number_of_reps;
    my $stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @rep_numbers;
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
    
    my $block_number_calculated = sqrt(scalar(@stock_list));
    if ($block_number_calculated =~ /^\d+$/ ){
	$number_of_blocks = $block_number_calculated;
    } else {
	die "Square root of Number of stocks (".scalar(@stock_list).") for lattice design should give a whole number.\n";
    }
    
    if ($self->has_control_list_crbd()) {
	@control_list_crbd = @{$self->get_control_list_crbd()};
	%control_names_lookup = map { $_ => 1 } @control_list_crbd;
	$self->_check_controls_and_accessions_lists;
    }
    
    if ($self->has_number_of_reps()) {
	$number_of_reps = $self->get_number_of_reps();
	if ($number_of_reps == 2 || $number_of_reps == 3){
	} else {
	    die "Number of reps should be 2 for SIMPLE and 3 for TRIPLE lattice design.\n";
	}
    } else {
	die "Number of reps not specified\n";
    }
    
    if ($self->has_fieldmap_col_number()) {
	$fieldmap_col_number = $self->get_fieldmap_col_number();
    }
    
    if ($self->has_fieldmap_row_number()) {
	$fieldmap_row_number = $self->get_fieldmap_row_number();
	my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
	$fieldmap_col_number = _validate_field_colNumber($colNumber);
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
    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('library(agricolae)');
    $r_block->add_command('trt <- stock_data_matrix[1,]');
    #$r_block->add_command('block_size <- '.$block_size);
    $r_block->add_command('number_of_reps <- '.$number_of_reps);
    #$r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');
    if ($self->has_randomization_seed()){
	$r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
	$r_block->add_command('lattice<-design.lattice(trt,r=number_of_reps,serie=3,kinds="Super-Duper", seed=randomization_seed)');
    }
    else {
	$r_block->add_command('lattice<-design.lattice(trt,r=number_of_reps,serie=3,kinds="Super-Duper")');
    }
    $r_block->add_command('lattice_book<-lattice$book');
    $r_block->add_command('lattice_book<-as.matrix(lattice_book)');
    
    my @commands = $r_block->read_commands();
    print STDERR join "\n", @commands;
    print STDERR "\n";
    
    
    $r_block->run_block();
    
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','lattice_book');
    @plot_numbers = $result_matrix->get_column("plots");
    #print STDERR Dumper(@plot_numbers);
    @block_numbers = $result_matrix->get_column("block");
    my $max = max( @block_numbers );
    @rep_numbers = $result_matrix->get_column("r");
    @stock_names = $result_matrix->get_column("trt");
    @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@rep_numbers, $number_of_reps)};
    
    if ($plot_layout_format eq "zigzag") {
	if (!$fieldmap_col_number){
	    @col_number_fieldmaps = ((1..$number_of_blocks) x ($number_of_blocks * $number_of_reps));
	    #print STDERR Dumper(\@col_number_fieldmaps);
	} else {
	    @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
	}
    }
    elsif ($plot_layout_format eq "serpentine") {
	if (!$fieldmap_row_number)  {
	    for my $rep (1 .. ($number_of_blocks * $number_of_reps)){
		if ($rep % 2){
		    push @col_number_fieldmaps, (1..$number_of_blocks);
		} else {
		    push @col_number_fieldmaps, (reverse 1..$number_of_blocks);
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
    for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
	my %plot_info;
	$plot_info{'stock_name'} = $stock_names[$i];
	$plot_info{'seedlot_name'} = $seedlot_hash{$stock_names[$i]}->[0];
	if ($plot_info{'seedlot_name'}){
	    $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
	}
	$plot_info{'block_number'} = $block_numbers[$i];
	$plot_info{'plot_name'} = $converted_plot_numbers[$i];
	$plot_info{'rep_number'} = $rep_numbers[$i];
	$plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
	$plot_info{'plot_number'} = $converted_plot_numbers[$i];
	$plot_info{'plot_num_per_block'} = $converted_plot_numbers[$i];
	if ($fieldmap_row_numbers[$i]){
	    $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
	    $plot_info{'col_number'} = $col_number_fieldmaps[$i];
	}
	$lattice_design{$converted_plot_numbers[$i]} = \%plot_info;
    }
    %lattice_design = %{$self->_build_plot_names(\%lattice_design)};
    return \%lattice_design;   
}

1;
