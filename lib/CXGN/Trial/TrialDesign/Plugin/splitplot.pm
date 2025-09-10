
package CXGN::Trial::TrialDesign::Plugin::splitplot;

use Moose::Role;
use Data::Dumper;

sub create_design { 
    my $self = shift;
    my %splitplot_design;
    my $rbase = R::YapRI::Base->new();
    my @stock_list;
    my $number_of_blocks;
    my $number_of_reps;
    my $stock_data_matrix;
    my $r_block;
    my $result_matrix;
    my @plot_numbers;
    my @subplots_numbers;
    my @stock_names;
    my @block_numbers;
    my @rep_numbers;
    my @converted_plot_numbers;
    my $number_of_stocks;
    my $fieldmap_row_number;
    my @fieldmap_row_numbers;
    my $fieldmap_col_number;
    my $plot_layout_format;
    my @col_number_fieldmaps;
    my $treatments;
    my @unique_treatments = ();
    my $num_plants_per_plot;
    if ($self->has_stock_list()) {
        @stock_list = @{$self->get_stock_list()};
        $number_of_stocks = scalar(@stock_list);
    } else {
        die "No stock list specified\n";
    }
    if ($self->has_treatments()) {
        $treatments = $self->get_treatments(); #at this point this is a hashref of arrayrefs. Each hash key is a treatment name, and the arrays are the values of that treatment to be applied.
        my @treatment_names = keys(%{$treatments});
        
        my @aggregator = ();
        foreach my $treatment (@treatment_names) {
            my @formatted_values = map {"{$treatment,$_}"} @{$treatments->{$treatment}};
            if (scalar(@aggregator) == 0) { #aggregator is empty
                @aggregator = @formatted_values;
            } else { #aggregator is not empty
                my @new_aggregator = ();
                foreach my $val (@aggregator) {
                    foreach my $new_val (@formatted_values) {
                        push @new_aggregator, $val.$new_val
                    }
                }
                @aggregator = @new_aggregator;
            }
        }

        @unique_treatments = @aggregator;

    } else {
        die "treatments not specified\n";
    }
    if ($self->has_number_of_blocks()) {
        $number_of_blocks = $self->get_number_of_blocks();
        $number_of_reps = $number_of_blocks;
    } else {
        die "Number of blocks not specified\n";
    }

    if ($self->has_fieldmap_col_number()) {
        $fieldmap_col_number = $self->get_fieldmap_col_number();
    }
    if ($self->has_fieldmap_row_number()) {
        $fieldmap_row_number = $self->get_fieldmap_row_number();
        my $colNumber = ((scalar(@stock_list) * $number_of_reps)/$fieldmap_row_number);
        $fieldmap_col_number = CXGN::Trial::TrialDesign::validate_field_colNumber($colNumber);
    }

    if ($self->has_plot_layout_format()) {
        $plot_layout_format = $self->get_plot_layout_format();
    }
    if($self->has_num_plants_per_plot()){
        $num_plants_per_plot = $self->get_num_plants_per_plot();
    }

    $stock_data_matrix =  R::YapRI::Data::Matrix->new({
        name => 'stock_data_matrix',
        rown => 1,
        coln => scalar(@stock_list),
        data => \@stock_list,
    });
    #print STDERR Dumper $stock_data_matrix;
    my $treatment_data_matrix =  R::YapRI::Data::Matrix->new({ #TODO figure out if this is right
        name => 'treatment_data_matrix',
        rown => 1,
        coln => scalar(@unique_treatments),
        data => \@unique_treatments,
    });

    $r_block = $rbase->create_block('r_block');
    $stock_data_matrix->send_rbase($rbase, 'r_block');
    $treatment_data_matrix->send_rbase($rbase, 'r_block');

    $r_block->add_command('library(agricolae)');
    $r_block->add_command('accessions <- stock_data_matrix[1,]');
    $r_block->add_command('treatments <- treatment_data_matrix[1,]');
    $r_block->add_command('r <- '.$number_of_reps);
    $r_block->add_command('randomization_method <- "'.$self->get_randomization_method().'"');

    if ($self->has_randomization_seed()){
        $r_block->add_command('randomization_seed <- '.$self->get_randomization_seed());
        $r_block->add_command('splitplot<-design.split(accessions,treatments,r=r,serie=3,kinds=randomization_method, seed=randomization_seed)');
    }
    else {
        $r_block->add_command('splitplot<-design.split(accessions,treatments,r=r,serie=3,kinds=randomization_method)');
    }
    $r_block->add_command('split<-splitplot$book'); #added for agricolae 1.1-8 changes in output
    $r_block->add_command('split<-as.matrix(split)');
    $r_block->run_block();
    $result_matrix = R::YapRI::Data::Matrix->read_rbase( $rbase,'r_block','split');
    #print STDERR Dumper $result_matrix;

    @plot_numbers = $result_matrix->get_column("plots");
    @subplots_numbers = $result_matrix->get_column("splots");
    @rep_numbers = $result_matrix->get_column("block");
    @stock_names = $result_matrix->get_column("accessions");
    my @treatments = $result_matrix->get_column("treatments");

    @converted_plot_numbers = @plot_numbers;

    my %subplot_plots;
    my %treatment_plots;
    my %treatment_subplot_hash;
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
        $plot_info{'plot_number'} = $converted_plot_numbers[$i];
        push @{$subplot_plots{$converted_plot_numbers[$i]}}, $subplots_numbers[$i];
        $plot_info{'subplots_names'} = $subplot_plots{$converted_plot_numbers[$i]};
        $splitplot_design{$converted_plot_numbers[$i]} = \%plot_info;
    }
    %splitplot_design = %{$self->_build_plot_names(\%splitplot_design)};

    my $subplot_plant_dictionary;
    while(my($plot,$val) = each(%splitplot_design)){
        my $subplots = $val->{'subplots_names'};
        my $num_plants_per_subplot = $num_plants_per_plot/scalar(@$subplots);
        my %subplot_plants_hash;
        my @plant_names;
        my $plant_index = 1;
        for(my $i=0; $i<scalar(@$subplots); $i++){
            push @{$treatment_subplot_hash{$treatments[$i]}}, $subplots->[$i];
            my @subplot_plant_names;
            for(my $j=0; $j<$num_plants_per_subplot; $j++){
                my $plant_name = $subplots->[$i]."_plant_$plant_index";
                push @{$subplot_plants_hash{$subplots->[$i]}}, $plant_name;
                push @plant_names, $plant_name;
                push @subplot_plant_names, $plant_name;
                $plant_index++;
            }
            $subplot_plant_dictionary->{$subplots->[$i]} = [@subplot_plant_names];
        }
        $val->{plant_names} = \@plant_names;
        $val->{subplots_plant_names} = \%subplot_plants_hash;
    }
    $splitplot_design{'treatments'} = {
        plants => $subplot_plant_dictionary,
        treatments => \%treatment_subplot_hash
    };
    return \%splitplot_design;
}

1;
