
package CXGN::Trial::Download::Plugin::TrialLayoutExcel;

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;

sub verify { 
    return 1;
}

sub download { 
    my $self = shift;

    print STDERR "DATALEVEL ".$self->data_level."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my $trial_layout = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $design = $trial_layout->get_design();
    #print STDERR Dumper $design;

    my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $treatments = $trial->get_treatments();

    if ($self->data_level eq 'plots') {
        $ws->write(0,0,"plot_name");
        $ws->write(0,1,"accession_name");
        $ws->write(0,2,"plot_number");
        $ws->write(0,3,"block_number");
        $ws->write(0,4,"is_a_control");
        $ws->write(0,5,"rep_number");
        $ws->write(0,6,"row_number");
        $ws->write(0,7,"col_number");
        $ws->write(0,8,"seedlot_name");
        $ws->write(0,9,"operator");
        $ws->write(0,10,"num_seed_per_plot");

        my $col = 11;
        my @treatment_lookup;
        foreach (@$treatments){
            $ws->write(0,$col,$_->[1]);
            $col++;
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plots = $treatment->get_plots();
            my %treatment_hash;
            foreach (@$treatment_plots){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }
        
        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            $ws->write($line, 0, $design->{$n}->{plot_name});
            $ws->write($line, 1, $design->{$n}->{accession_name});
            $ws->write($line, 2, $design->{$n}->{plot_number});
            $ws->write($line, 3, $design->{$n}->{block_number});
            $ws->write($line, 4, $design->{$n}->{is_a_control});
            $ws->write($line, 5, $design->{$n}->{rep_number});
            $ws->write($line, 6, $design->{$n}->{row_number});
            $ws->write($line, 7, $design->{$n}->{col_number});
            $ws->write($line, 8, $design->{$n}->{seedlot_name});
            $ws->write($line, 9, $design->{$n}->{seed_transaction_operator});
            $ws->write($line, 10, $design->{$n}->{num_seed_per_plot});

            my $col = 11;
            for (0..scalar(@$treatments)-1){
                my $treatment_hash = $treatment_lookup[$_];
                if (exists($treatment_hash->{$design->{$n}->{plot_name}})){
                    $ws->write($line, $col, 1);
                }
                $col++;
            }
            $line++;
        }    
        $ss->close();
        
    } elsif ($self->data_level eq 'plants') {
        $ws->write(0,0,"plant_name");
        $ws->write(0,1,"plot_name");
        $ws->write(0,2,"accession_name");
        $ws->write(0,3,"plot_number");
        $ws->write(0,4,"block_number");
        $ws->write(0,5,"is_a_control");
        $ws->write(0,6,"rep_number");
        $ws->write(0,7,"row_number");
        $ws->write(0,8,"col_number");
        $ws->write(0,9,"seedlot_name");
        $ws->write(0,10,"operator");
        $ws->write(0,11,"num_seed_per_plot");

        my $col = 12;
        my @treatment_lookup;
        foreach (@$treatments){
            $ws->write(0,$col,$_->[1]);
            $col++;
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plants = $treatment->get_plants();
            my %treatment_hash;
            foreach (@$treatment_plants){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $plant_names = $design->{$n}->{plant_names};
            foreach my $p (@$plant_names) {
                $ws->write($line, 0, $p);
                $ws->write($line, 1, $design->{$n}->{plot_name});
                $ws->write($line, 2, $design->{$n}->{accession_name});
                $ws->write($line, 3, $design->{$n}->{plot_number});
                $ws->write($line, 4, $design->{$n}->{block_number});
                $ws->write($line, 5, $design->{$n}->{is_a_control});
                $ws->write($line, 6, $design->{$n}->{rep_number});
                $ws->write($line, 7, $design->{$n}->{row_number});
                $ws->write($line, 8, $design->{$n}->{col_number});
                $ws->write($line, 9, $design->{$n}->{seedlot_name});
                $ws->write($line, 10, $design->{$n}->{seed_transaction_operator});
                $ws->write($line, 11, $design->{$n}->{num_seed_per_plot});

                my $col = 12;
                for (0..scalar(@$treatments)-1){
                    my $treatment_hash = $treatment_lookup[$_];
                    if (exists($treatment_hash->{$p})){
                        $ws->write($line, $col, 1);
                    }
                    $col++;
                }
                $line++;
            }
        }    
        $ss->close();
    } elsif ($self->data_level eq 'plants_subplots') {
        $ws->write(0,0,"plant_name");
        $ws->write(0,1,"subplot_name");
        $ws->write(0,2,"plot_name");
        $ws->write(0,3,"accession_name");
        $ws->write(0,4,"plot_number");
        $ws->write(0,5,"block_number");
        $ws->write(0,6,"is_a_control");
        $ws->write(0,7,"rep_number");
        $ws->write(0,8,"row_number");
        $ws->write(0,9,"col_number");
        $ws->write(0,10,"seedlot_name");
        $ws->write(0,11,"operator");
        $ws->write(0,12,"num_seed_per_plot");

        my $col = 13;
        my @treatment_lookup;
        foreach (@$treatments){
            $ws->write(0,$col,$_->[1]);
            $col++;
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_plants = $treatment->get_plants();
            my %treatment_hash;
            foreach (@$treatment_plants){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $subplots_plant_names = $design->{$n}->{subplots_plant_names};
            foreach my $s (sort keys %$subplots_plant_names){
                my $plant_names = $subplots_plant_names->{$s};
                foreach my $p (sort @$plant_names) {
                    $ws->write($line, 0, $p);
                    $ws->write($line, 1, $s);
                    $ws->write($line, 2, $design->{$n}->{plot_name});
                    $ws->write($line, 3, $design->{$n}->{accession_name});
                    $ws->write($line, 4, $design->{$n}->{plot_number});
                    $ws->write($line, 5, $design->{$n}->{block_number});
                    $ws->write($line, 6, $design->{$n}->{is_a_control});
                    $ws->write($line, 7, $design->{$n}->{rep_number});
                    $ws->write($line, 8, $design->{$n}->{row_number});
                    $ws->write($line, 9, $design->{$n}->{col_number});
                    $ws->write($line, 10, $design->{$n}->{seedlot_name});
                    $ws->write($line, 11, $design->{$n}->{seed_transaction_operator});
                    $ws->write($line, 12, $design->{$n}->{num_seed_per_plot});

                    my $col = 13;
                    for (0..scalar(@$treatments)-1){
                        my $treatment_hash = $treatment_lookup[$_];
                        if (exists($treatment_hash->{$p})){
                            $ws->write($line, $col, 1);
                        }
                        $col++;
                    }
                    $line++;
                }
            }
        }
        $ss->close();
    } elsif ($self->data_level eq 'subplots') {
        $ws->write(0,0,"subplot_name");
        $ws->write(0,1,"plot_name");
        $ws->write(0,2,"accession_name");
        $ws->write(0,3,"plot_number");
        $ws->write(0,4,"block_number");
        $ws->write(0,5,"is_a_control");
        $ws->write(0,6,"rep_number");
        $ws->write(0,7,"row_number");
        $ws->write(0,8,"col_number");
        $ws->write(0,9,"seedlot_name");
        $ws->write(0,10,"operator");
        $ws->write(0,11,"num_seed_per_plot");

        my $col = 12;
        my @treatment_lookup;
        foreach (@$treatments){
            $ws->write(0,$col,$_->[1]);
            $col++;
            my $treatment = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_->[0] });
            my $treatment_subplots = $treatment->get_subplots();
            my %treatment_hash;
            foreach (@$treatment_subplots){
                $treatment_hash{$_->[1]}++;
            }
            push @treatment_lookup, \%treatment_hash;
        }

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $subplot_names = $design->{$n}->{subplot_names};
            foreach my $s (@$subplot_names){
                $ws->write($line, 0, $s);
                $ws->write($line, 1, $design->{$n}->{plot_name});
                $ws->write($line, 2, $design->{$n}->{accession_name});
                $ws->write($line, 3, $design->{$n}->{plot_number});
                $ws->write($line, 4, $design->{$n}->{block_number});
                $ws->write($line, 5, $design->{$n}->{is_a_control});
                $ws->write($line, 6, $design->{$n}->{rep_number});
                $ws->write($line, 7, $design->{$n}->{row_number});
                $ws->write($line, 8, $design->{$n}->{col_number});
                $ws->write($line, 9, $design->{$n}->{seedlot_name});
                $ws->write($line, 10, $design->{$n}->{seed_transaction_operator});
                $ws->write($line, 11, $design->{$n}->{num_seed_per_plot});

                my $col = 12;
                for (0..scalar(@$treatments)-1){
                    my $treatment_hash = $treatment_lookup[$_];
                    if (exists($treatment_hash->{$s})){
                        $ws->write($line, $col, 1);
                    }
                    $col++;
                }
                $line++;
            }
        }
        $ss->close();
    }
    
}

1;
