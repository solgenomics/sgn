
package CXGN::Trial::Download::Plugin::TrialLayoutCSV;

use Moose::Role;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use Data::Dumper;

sub validate { 
    return 1;
}

sub download { 
    my $self = shift;
    
    my $trial_layout = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $design = $trial_layout->get_design();

    my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $treatments = $trial->get_treatments();

    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();

    if ($self->data_level eq 'plots') {
        my @header_cols = ("plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number", "row_number", "col_number", "seedlot_name", "operator", "num_seed_per_plot");
        my @treatment_lookup;
        foreach (@$treatments){
            push @header_cols, "Treatment:".$_->[1];
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plots = $treatment->get_plots();
            my %treatment_hash;
            foreach (@$treatment_plots){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }
        my $header = join (",", @header_cols);
        print $F $header."\n";

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) {
            my @line_col = (
                $design->{$n}->{plot_name},
                $design->{$n}->{accession_name},
                $design->{$n}->{plot_number},
                $design->{$n}->{block_number},
                $design->{$n}->{is_a_control} || '',
                $design->{$n}->{rep_number},
                $design->{$n}->{row_number},
                $design->{$n}->{col_number},
                $design->{$n}->{seedlot_name},
                $design->{$n}->{seed_transaction_operator},
                $design->{$n}->{num_seed_per_plot},
            );
            for (0..scalar(@$treatments)-1){
                my $treatment_hash = $treatment_lookup[$_];
                if (exists($treatment_hash->{$design->{$n}->{plot_name}})){
                    push @line_col, 1;
                } else {
                    push @line_col, '';
                }
            }
            print $F join ",", @line_col;
            print $F "\n";
        }
        close($F);
        
    } elsif ($self->data_level eq 'plants') {
        my @header_cols = ("plant_name", "plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number", "row_number", "col_number", "seedlot_name", "operator", "num_seed_per_plot");
        my @treatment_lookup;
        foreach (@$treatments){
            push @header_cols, "Treatment:".$_->[1];
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plots = $treatment->get_plants();
            my %treatment_hash;
            foreach (@$treatment_plots){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }
        my $header = join (",", @header_cols);
        
        print $F $header."\n";

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $plant_names = $design->{$n}->{plant_names};
            foreach my $p (@$plant_names) {
                my @line_col = (
                    $p,
                    $design->{$n}->{plot_name},
                    $design->{$n}->{accession_name},
                    $design->{$n}->{plot_number},
                    $design->{$n}->{block_number},
                    $design->{$n}->{is_a_control} || '',
                    $design->{$n}->{rep_number},
                    $design->{$n}->{row_number},
                    $design->{$n}->{col_number},
                    $design->{$n}->{seedlot_name},
                    $design->{$n}->{seed_transaction_operator},
                    $design->{$n}->{num_seed_per_plot},
                );
                for (0..scalar(@$treatments)-1){
                    my $treatment_hash = $treatment_lookup[$_];
                    if (exists($treatment_hash->{$p})){
                        push @line_col, 1;
                    } else {
                        push @line_col, '';
                    }
                }
                print $F join ",", @line_col;
                print $F "\n";
            }
        }
        close($F);
    } elsif ($self->data_level eq 'subplots') {
        my @header_cols = ("subplot_name", "plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number", "row_number", "col_number", "seedlot_name", "operator", "num_seed_per_plot");
        my @treatment_lookup;
        foreach (@$treatments){
            push @header_cols, "Treatment:".$_->[1];
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plots = $treatment->get_subplots();
            my %treatment_hash;
            foreach (@$treatment_plots){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }
        my $header = join (",", @header_cols);
        
        print $F $header."\n";

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $subplot_names = $design->{$n}->{subplot_names};
            foreach my $p (@$subplot_names) {
                my @line_col = (
                    $p,
                    $design->{$n}->{plot_name},
                    $design->{$n}->{accession_name},
                    $design->{$n}->{plot_number},
                    $design->{$n}->{block_number},
                    $design->{$n}->{is_a_control} || '',
                    $design->{$n}->{rep_number},
                    $design->{$n}->{row_number},
                    $design->{$n}->{col_number},
                    $design->{$n}->{seedlot_name},
                    $design->{$n}->{seed_transaction_operator},
                    $design->{$n}->{num_seed_per_plot},
                );
                for (0..scalar(@$treatments)-1){
                    my $treatment_hash = $treatment_lookup[$_];
                    if (exists($treatment_hash->{$p})){
                        push @line_col, 1;
                    } else {
                        push @line_col, '';
                    }
                }
                print $F join ",", @line_col;
                print $F "\n";
            }
        }
        close($F);
    } elsif ($self->data_level eq 'plants_subplots') {
        my @header_cols = ("plant_name", "subplot_name", "plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number", "row_number", "col_number", "seedlot_name", "operator", "num_seed_per_plot");
        my @treatment_lookup;
        foreach (@$treatments){
            push @header_cols, "Treatment:".$_->[1];
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plots = $treatment->get_plants();
            my %treatment_hash;
            foreach (@$treatment_plots){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }
        my $header = join (",", @header_cols);
        
        print $F $header."\n";

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) {
            my $subplots_plant_names = $design->{$n}->{subplots_plant_names};
            foreach my $s (sort keys %$subplots_plant_names){
                my $plant_names = $subplots_plant_names->{$s};
                foreach my $p (sort @$plant_names) {
                    my @line_col = (
                        $p,
                        $s,
                        $design->{$n}->{plot_name},
                        $design->{$n}->{accession_name},
                        $design->{$n}->{plot_number},
                        $design->{$n}->{block_number},
                        $design->{$n}->{is_a_control} || '',
                        $design->{$n}->{rep_number},
                        $design->{$n}->{row_number},
                        $design->{$n}->{col_number},
                        $design->{$n}->{seedlot_name},
                        $design->{$n}->{seed_transaction_operator},
                        $design->{$n}->{num_seed_per_plot},
                    );
                    for (0..scalar(@$treatments)-1){
                        my $treatment_hash = $treatment_lookup[$_];
                        if (exists($treatment_hash->{$p})){
                            push @line_col, 1;
                        } else {
                            push @line_col, '';
                        }
                    }
                    print $F join ",", @line_col;
                    print $F "\n";
                }
            }
        }
        close($F);
    }
}

1;
