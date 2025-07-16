
package CXGN::Trial::TrialDesign::Plugin::Analysis;

use Moose::Role;
use Data::Dumper;

sub create_design {
    my $self = shift;

    my %analysis;
    my @accession_list = sort @{ $self->get_stock_list() };
    my $analysis_name = $self->get_trial_name();
    my %num_accession_hash;

    my @plot_numbers = (1..scalar(@accession_list));
    for (my $i = 0; $i < scalar(@plot_numbers); $i++) {
        my %plot_info;
        $plot_info{stock_name} = $accession_list[$i];
        $plot_info{plot_name} = $analysis_name."_".$accession_list[$i];
        $analysis{$plot_numbers[$i]} = \%plot_info;
    }
    
    # foreach my $plot_num (keys %analysis) {
    #     my @plant_names;
    #     my $plot_name = $analysis{$plot_num}->{plot_name};
    #     my $stock_name = $analysis{$plot_num}->{stock_name};
    #     for my $n (1..$num_accession_hash{$stock_name}) {
    #         my $plant_name = $plot_name."_plant_$n";
    #         push @plant_names, $plant_name;
    #     }
    #     $analysis{$plot_num}->{plant_names} = \@plant_names;
    # }

    # print STDERR Dumper(\%analysis);
    
    return \%analysis;
}

1;
