
package CXGN::Trial::TrialDesign::Plugin::Westcott;

use Moose::Role;
use List::Util qw | max |;

sub create_design {
    my $self = shift;
    my %westcott_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $stock_data_matrix;
    my @control_list;
    my %control_names_lookup;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my $westcott_col;
    my $westcott_check_2;
    my $westcott_check_1;
    my $westcott_col_between_check;

    if ($self->has_stock_list()) {
      @stock_list = @{$self->get_stock_list()};
    } else {
      die "No stock list specified\n";
    }
    if ($self->has_control_list_crbd()) {
      @control_list = @{$self->get_control_list_crbd()};
      %control_names_lookup = map { $_ => 1 } @control_list;
      $self->_check_controls_and_accessions_lists;
    }
    if ($self->has_westcott_col()) {
      $westcott_col = $self->get_westcott_col();
    }
    if ($self->has_westcott_check_2()) {
      $westcott_check_2 = $self->get_westcott_check_2();
    }
    if ($self->has_westcott_check_1()) {
      $westcott_check_1 = $self->get_westcott_check_1();
    }
    if ($self->has_westcott_col_between_check()) {
      $westcott_col_between_check = $self->get_westcott_col_between_check();
    }

    $stock_data_matrix =  R::YapRI::Data::Matrix->new({
        name => 'stock_data_matrix',
        rown => 1,
        coln => scalar(@stock_list),
        data => \@stock_list,
    });

    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('library(st4gi)');
    $r_block->add_command('geno <-  stock_data_matrix[1,]');
    $r_block->add_command('ch1 <- "'.$westcott_check_1.'"');
    $r_block->add_command('ch2 <- "'.$westcott_check_2.'"');
    $r_block->add_command('nc <- '.$westcott_col);
    if ($westcott_col_between_check){
        $r_block->add_command('ncb <- '.$westcott_col_between_check);
        $r_block->add_command('westcott<-cr.w(geno, ch1, ch2, nc, ncb=ncb)');
    }
    else{
        $r_block->add_command('westcott<-cr.w(geno, ch1, ch2, nc)');
    }
    $r_block->add_command('westcott<-westcott$book');
    $r_block->add_command('westcott<-as.matrix(westcott)');
    $r_block->run_block();
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','westcott');
    @plot_numbers = $result_matrix->get_column("plot.num");
    @stock_names = $result_matrix->get_column("geno");

    my @vector_trt = (1..scalar(@stock_list));
    my %accName;
    for (my $i=0; $i< scalar(@stock_list); $i++){
        $accName{$vector_trt[$i]} = $stock_list[$i];
    }
    for (my $i=0; $i<scalar(@stock_names); $i++){
        for my $trt (keys %accName){
            if ($stock_names[$i] eq $trt){
                $stock_names[$i] = $accName{$trt};
            }
        }
    }

    my @row_numbers = $result_matrix->get_column("row");
    my @col_numbers = $result_matrix->get_column("col");
    @block_numbers = $result_matrix->get_column("row");
    my $max_block = max( @block_numbers );
    @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@block_numbers, $max_block)};

    for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
      my %plot_info;
      $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
      $plot_info{'stock_name'} = $stock_names[$i];
      $plot_info{'block_number'} = $block_numbers[$i];
      $plot_info{'plot_name'} = $converted_plot_numbers[$i];
      $plot_info{'row_number'} = $row_numbers[$i];
      $plot_info{'col_number'} = $col_numbers[$i];
      $plot_info{'plot_number'} = $converted_plot_numbers[$i];
      $plot_info{'plot_num_per_block'} = $converted_plot_numbers[$i];

      $westcott_design{$converted_plot_numbers[$i]} = \%plot_info;
    }
    %westcott_design = %{$self->_build_plot_names(\%westcott_design)};
    return \%westcott_design;
}

1;
