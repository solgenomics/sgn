
package CXGN::Trial::TrialDesign::Plugin::CRD;

use Moose::Role;

sub create_design {
    my $self = shift;
    my %crd_design;
    #$self->set_number_of_blocks(1);
    #%crd_design=%{_get_rcbd_design($self)};
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
    my $number_of_stocks;
    my @control_list_crbd;
    my %control_names_lookup;
    my $fieldmap_row_number;
    my @fieldmap_row_numbers;
    my $fieldmap_col_number;
    my $plot_layout_format;
    my @col_number_fieldmaps;
    if ($self->has_stock_list()) {
        @stock_list = @{$self->get_stock_list()};
        $number_of_stocks = scalar(@stock_list);
    } else {
        die "No stock list specified\n";
    }
    if ($self->has_control_list_crbd()) {
      @control_list_crbd = @{$self->get_control_list_crbd()};
      %control_names_lookup = map { $_ => 1 } @control_list_crbd;
      $self->_check_controls_and_accessions_lists;
    }
    if ($self->has_number_of_reps()) {
        $number_of_reps = $self->get_number_of_reps();
    } else {
        die "Number of reps not specified\n";
    }

    if ($self->has_fieldmap_col_number()) {
      $fieldmap_col_number = $self->get_fieldmap_col_number();
    }
    if ($self->has_fieldmap_row_number()) {
      $fieldmap_row_number = $self->get_fieldmap_row_number();
      my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
      $fieldmap_col_number = $self->CXGN::Trial::TrialDesign::validate_field_colNumber($colNumber);

      #if (isint($colNumber)){
        #$fieldmap_col_number = $colNumber;
      #} else {
      #    die "Choose a different row number for field map generation. The product of number of accessions and rep when divided by row number should give an integer\n";
      #}
    }

    if ($self->has_plot_layout_format()) {
      $plot_layout_format = $self->get_plot_layout_format();
    }

    if (scalar(@stock_list)>1) {

        $stock_data_matrix =  R::YapRI::Data::Matrix->new({
            name => 'stock_data_matrix',
            rown => 1,
            coln => scalar(@stock_list),
            data => \@stock_list,
        });
        #print STDERR Dumper $stock_data_matrix;

        $r_block = $rbase->create_block('r_block');
        $stock_data_matrix->send_rbase($rbase, 'r_block');

        $r_block->add_command('library(agricolae)');
        $r_block->add_command('trt <- stock_data_matrix[1,]');
        $r_block->add_command('rep_vector <- rep('.$number_of_reps.',each='.$number_of_stocks.')');
        $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

        if ($self->has_randomization_seed()){
            $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
            $r_block->add_command('crd<-design.crd(trt,rep_vector,serie=3,kinds=randomization_method, seed=randomization_seed)');
        }
        else {
            $r_block->add_command('crd<-design.crd(trt,rep_vector,serie=3,kinds=randomization_method)');
        }
        $r_block->add_command('crd<-crd$book'); #added for agricolae 1.1-8 changes in output
        $r_block->add_command('crd<-as.matrix(crd)');
        $r_block->run_block();
        $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','crd');
        #print STDERR Dumper $result_matrix;

        @plot_numbers = $result_matrix->get_column("plots");
        #print STDERR Dumper \@plot_numbers;

        @rep_numbers = $result_matrix->get_column("r");
        @stock_names = $result_matrix->get_column("trt");
        @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@rep_numbers, $number_of_reps)};
        #print STDERR Dumper \@converted_plot_numbers;

        #generate col_number
        if ($plot_layout_format eq "zigzag") {
          if (!$fieldmap_col_number){
            @col_number_fieldmaps = ((1..(scalar(@stock_list))) x $number_of_reps);
          } else {
            @col_number_fieldmaps = ((1..$fieldmap_col_number) x $fieldmap_row_number);
          }
          #print STDERR Dumper(\@col_number_fieldmaps);
        }
        elsif ($plot_layout_format eq "serpentine") {
          if (!$fieldmap_row_number)  {
            for my $rep (1 .. $number_of_reps){
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
          #@col_number_fieldmaps = (my @cols, (1..(scalar(@stock_list))) x $number_of_reps);
        }

    } else { #only a single stock was given, so no randomization can occur.
        @converted_plot_numbers = (1...$number_of_reps);
        @rep_numbers = (1...$number_of_reps);
        @stock_names = ($stock_list[0]) x $number_of_reps;
    }

    if ($plot_layout_format && !$fieldmap_col_number && !$fieldmap_row_number){
      @fieldmap_row_numbers = sort(@rep_numbers);
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
        $plot_info{'block_number'} = 1;
        $plot_info{'rep_number'} = $rep_numbers[$i];
        $plot_info{'plot_name'} = $converted_plot_numbers[$i];
        $plot_info{'is_a_control'} = exists($control_names_lookup{$stock_names[$i]});
        $plot_info{'plot_number'} = $converted_plot_numbers[$i];
        $plot_info{'plot_num_per_block'} = $converted_plot_numbers[$i];
        if ($fieldmap_row_numbers[$i]){
          $plot_info{'row_number'} = $fieldmap_row_numbers[$i];
          $plot_info{'col_number'} = $col_number_fieldmaps[$i];
        }
        $crd_design{$converted_plot_numbers[$i]} = \%plot_info;
    }

    #print STDERR Dumper \%crd_design;

    %crd_design = %{$self->_build_plot_names(\%crd_design)};
    return \%crd_design;
}

1;
