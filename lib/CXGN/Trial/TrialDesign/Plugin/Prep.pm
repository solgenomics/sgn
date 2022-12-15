
package CXGN::Trial::TrialDesign::Plugin::Prep;

use Moose::Role;

use MooseX::FollowPBP;


sub create_design {
    my $self = shift;
    my %prep_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @stock_names;
    my @block_numbers;
    my @converted_plot_numbers;
    my $number_of_replicated_accession;
    my $number_of_unreplicated_accession;
    my $num_of_replicated_times;
    my $sub_block_sequence;
    my $block_sequence;
    my $col_in_design_number;
    my $row_in_design_number;
    
    if ($self->has_stock_list()) {
      @stock_list = @{$self->get_stock_list()};
    } else {
      die "No stock list specified\n";
    }
    if ($self->has_replicated_stock_no()) {
      $number_of_replicated_accession = $self->get_replicated_stock_no();
    } 
    if ($self->has_unreplicated_stock_no()) {
      $number_of_unreplicated_accession = $self->get_unreplicated_stock_no();
    } 
    if ($self->has_num_of_replicated_times()) {
      $num_of_replicated_times = $self->get_num_of_replicated_times();
    } 
    if ($self->has_sub_block_sequence()) {
      $sub_block_sequence = $self->get_sub_block_sequence();
    }
    if ($self->has_block_sequence()) {
      $block_sequence = $self->get_block_sequence();
    }
    my ($rep_size,$number_of_reps) = split(',', $block_sequence);
    if ($self->has_col_in_design_number()) {
      $col_in_design_number = $self->get_col_in_design_number();
    }   
    if ($self->has_row_in_design_number()) {
      $row_in_design_number = $self->get_row_in_design_number();
    }
    
    $stock_data_matrix =  R::YapRI::Data::Matrix->new(
  						       {
  							name => 'stock_data_matrix',
  							rown => 1,
  							coln => scalar(@stock_list),
  							data => \@stock_list,
  						       }
  						      );
                              
    my %stock_data_hash;
    my $count = 0;
    my @counts;
    foreach my $x (@stock_list){
        $count ++;
        push @counts, $count;
    }
    for (my $n=0; $n<scalar(@stock_list); $n++) {
        $stock_data_hash{$counts[$n]} = $stock_list[$n];
    }
    my ($no_row_in_block,$no_block_in_design) = split(',', $block_sequence);
    $no_row_in_block = $no_row_in_block * $col_in_design_number;
    
    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block'); 
    $r_block->add_command('library(DiGGer)');
    $r_block->add_command('library(R.methodsS3)'); 
    $r_block->add_command('library(reshape)');
    $r_block->add_command('library(R.oo)');
    $r_block->add_command('numberOfTreatments <- ' .$stock_data_matrix->{coln}); 
    $r_block->add_command('rowsInDesign <- '.$row_in_design_number); 
    $r_block->add_command('columnsInDesign <- '.$col_in_design_number);
    $r_block->add_command('blockSequence <- list(c('.$block_sequence.'), c('.$sub_block_sequence.'))'); 
    $r_block->add_command('treatRepPerRep <- rep(c(1,'.$num_of_replicated_times.'), c('.$number_of_unreplicated_accession.', '.$number_of_replicated_accession.'))');
    $r_block->add_command('treatGroup <- rep(c(1, 2), c('.$number_of_unreplicated_accession.', '.$number_of_replicated_accession.'))');
    $r_block->add_command('rngSeeds <- c(156, 444)');
    $r_block->add_command('runSearch <- TRUE');
    $r_block->add_command('pRepDesign <- prDiGGer(numberOfTreatments = numberOfTreatments,
                                                rowsInDesign = rowsInDesign,
                                                columnsInDesign = columnsInDesign,
                                                blockSequence = blockSequence,
                                                treatRepPerRep = treatRepPerRep, 
                                                treatGroup = treatGroup, 
                                                rngSeeds = rngSeeds, 
                                                runSearch = runSearch )');
    #$r_block->add_command('pRepDesign <- run(pRepDesign)');                                            
    #$r_block->add_command('designBlock <- desTab(getDesign(pRepDesign), '.$block_sequence.')');  print "PARAMETER: 13\n";
    $r_block->add_command('field_map <- getDesign(pRepDesign)');
    $r_block->add_command('field_map_t <- t(field_map)');
    $r_block->add_command('field_map_melt <- melt(field_map_t)');
    $r_block->add_command('colnames(field_map_melt) <- c("col_number","row_number","trt")');
    $r_block->add_command('rownames(field_map_melt) <- rownames(field_map_melt, do.NULL = FALSE, prefix = "Obs.")');
    $r_block->add_command('dim_trt <- dim(field_map_melt)[1]');
    $r_block->add_command('blockNo <- rep(1:'.$no_block_in_design.', each='.$no_row_in_block.')');
    $r_block->add_command('blockNo <- melt(blockNo)');
    $r_block->add_command('colnames(blockNo) <- c("block")');
    $r_block->add_command('rownames(blockNo) <- rownames(blockNo, do.NULL = FALSE, prefix = "Obs.")');
    $r_block->add_command('blockNo_merge <- match(rownames(field_map_melt), rownames(blockNo) )');
    $r_block->add_command('blockNo_merge <- cbind( field_map_melt, blockNo[blockNo_merge,] )');
    $r_block->add_command('colnames(blockNo_merge) <- c("col_number","row_number","trt","block")');
    $r_block->add_command('rownames(blockNo_merge) <- rownames(blockNo_merge, do.NULL = FALSE, prefix = "Obs.")');
    $r_block->add_command('plot_num <- c(1:dim_trt)');
    $r_block->add_command('plot_num <- t(plot_num)');
    $r_block->add_command('plot_num <- melt(plot_num)');
    $r_block->add_command('colnames(plot_num) <- c("p2","p1","plots")');
    $r_block->add_command('rownames(plot_num) <- rownames(plot_num, do.NULL = FALSE, prefix = "Obs.")');
    #$r_block->add_command('layout_merge <- match(rownames(field_map_melt), rownames(plot_num) )');
    #$r_block->add_command('layout_merge <- cbind( field_map_melt, plot_num[layout_merge,] )');
    $r_block->add_command('layout_merge <- match(rownames(blockNo_merge), rownames(plot_num) )');
    $r_block->add_command('layout_merge <- cbind( blockNo_merge, plot_num[layout_merge,] )');
    $r_block->add_command('layout <- subset(layout_merge, select = c(plots, block, row_number, col_number, trt))');
    $r_block->add_command('pRepDesign <- as.matrix(layout)');
    #$r_block->run_block();
    
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','pRepDesign');
     @plot_numbers = $result_matrix->get_column("plots");
     @stock_names = $result_matrix->get_column("trt");
     my @row_numbers = $result_matrix->get_column("row_number");
     my @col_numbers = $result_matrix->get_column("col_number");
     @block_numbers = $result_matrix->get_column("block");
     @converted_plot_numbers=@{$self->_convert_plot_numbers(\@plot_numbers, \@block_numbers, $number_of_reps)};
     
     my $counting = 0;
     my %seedlot_hash;
     if($self->get_seedlot_hash){
         %seedlot_hash = %{$self->get_seedlot_hash};
     }
     for (my $i = 0; $i < scalar(@converted_plot_numbers); $i++) {
       my %plot_info;
       $counting++;
       foreach my $key (keys %stock_data_hash){
           if ($stock_names[$i] == $key && $plot_numbers[$i] eq $counting){
               $plot_info{'stock_name'} = $stock_data_hash{$key};
           }
       }
       $plot_info{'seedlot_name'} = $seedlot_hash{$plot_info{'stock_name'}}->[0];
       if ($plot_info{'seedlot_name'}){
           $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
       }
       $plot_info{'block_number'} = $block_numbers[$i];
       $plot_info{'plot_name'} = $converted_plot_numbers[$i];
       $plot_info{'row_number'} = $row_numbers[$i];
       $plot_info{'col_number'} = $col_numbers[$i];
       $plot_info{'plot_number'} = $converted_plot_numbers[$i];
       $plot_info{'plot_num_per_block'} = $converted_plot_numbers[$i];

       $prep_design{$converted_plot_numbers[$i]} = \%plot_info;
     }
     %prep_design = %{$self->_build_plot_names(\%prep_design)};
    return \%prep_design;
}

1;
