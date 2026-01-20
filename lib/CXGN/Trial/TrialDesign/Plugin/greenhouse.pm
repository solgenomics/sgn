
package CXGN::Trial::TrialDesign::Plugin::greenhouse;

use Moose::Role;

sub create_design { 
    my $self = shift;
    my $order = 1;
    my %greenhouse_design;
    my @num_plants = @{ $self->get_greenhouse_num_plants() };
    my @accession_list = @{ $self->get_stock_list() };
    my $trial_name = $self->get_trial_name;
    my %num_accession_hash;
    @num_accession_hash{@accession_list} = @num_plants;

    my @plot_numbers = (1..scalar(@accession_list));
    my %seedlot_hash;
    if($self->get_seedlot_hash){
        %seedlot_hash = %{$self->get_seedlot_hash};
    }
    for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
        my %plot_info;
        $plot_info{'stock_name'} = $accession_list[$i];
        $plot_info{'seedlot_name'} = $seedlot_hash{$accession_list[$i]}->[0];
        if ($plot_info{'seedlot_name'}){
            $plot_info{'num_seed_per_plot'} = $self->get_num_seed_per_plot;
        }
        $plot_info{'block_number'} = 1;
        $plot_info{'rep_number'} = 1;
        $plot_info{'plot_name'} = $plot_numbers[$i];
        $greenhouse_design{$plot_numbers[$i]} = \%plot_info;
    }
    %greenhouse_design = %{$self->_build_plot_names(\%greenhouse_design)};

    foreach my $plot_num (keys %greenhouse_design) {
        my @plant_coords = ();
        if ($self->get_num_rows_per_plot && $self->get_num_cols_per_plot){
            foreach my $row (1..$self->get_num_rows_per_plot) {
                foreach my $col (1..$self->get_num_cols_per_plot) {
                    push @plant_coords, "$row,$col";
                }
            }
        }
        my @plant_names;
        my $plot_name = $greenhouse_design{$plot_num}->{'plot_name'};
        my $stock_name = $greenhouse_design{$plot_num}->{'stock_name'};
        for my $n (1..$num_accession_hash{$stock_name}) {
            my $coord_pair = "";
            if (@plant_coords) {
                $coord_pair = shift(@plant_coords);
            }
            my $plant_name = $plot_name."_plant_$n";
            push @plant_names, $plant_name."_COORDS{$coord_pair}";
        }
        $greenhouse_design{$plot_num}->{'plant_names'} = \@plant_names;
    }

    #print STDERR Dumper \%greenhouse_design;
    return \%greenhouse_design;
}

1;
