
package CXGN::Trial::Download::Plugin::TrialLayoutCSV;

use Moose::Role;
use CXGN::Trial::TrialLayout;

sub validate { 
    return 1;
}

sub download { 
    my $self = shift;
    
    my $trial = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->trial_id() });
    
    my $design = $trial->get_design();

    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();

    if ($self->data_level eq 'plots') {
        my $header = join (",", "plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number", "row_number", "col_number");
        
        print $F $header."\n";

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            print $F join ",", 
            $design->{$n}->{plot_name},
            $design->{$n}->{accession_name},
            $design->{$n}->{plot_number},
            $design->{$n}->{block_number},
            $design->{$n}->{is_a_control} || '',
            $design->{$n}->{rep_number},
            $design->{$n}->{row_number},
            $design->{$n}->{col_number};
            print $F "\n";
        }
        close($F);
        
    } elsif ($self->data_level eq 'plants') {
        my $header = join (",", "plant_name", "plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number", "row_number", "col_number");
        
        print $F $header."\n";

        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $plant_names = $design->{$n}->{plant_names};
            foreach (@$plant_names) {
                print $F join ",", 
                $_,
                $design->{$n}->{plot_name},
                $design->{$n}->{accession_name},
                $design->{$n}->{plot_number},
                $design->{$n}->{block_number},
                $design->{$n}->{is_a_control} || '',
                $design->{$n}->{rep_number},
                $design->{$n}->{row_number},
                $design->{$n}->{col_number};
                print $F "\n";
            }
        }
        close($F);
    }
}

1;
