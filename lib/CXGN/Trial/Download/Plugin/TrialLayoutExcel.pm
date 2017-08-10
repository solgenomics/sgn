
package CXGN::Trial::Download::Plugin::TrialLayoutExcel;

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use CXGN::Trial::TrialLayout;

sub verify { 
    return 1;
}

sub download { 
    my $self = shift;

    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();
    
    my $trial = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema, trial_id => $self->trial_id() });
    my $design = $trial->get_design();
    #print STDERR Dumper $design;

    if ($self->data_level eq 'plots') {
        $ws->write(0,0,"plot_name");
        $ws->write(0,1,"accession_name");
        $ws->write(0,2,"plot_number");
        $ws->write(0,3,"block_number");
        $ws->write(0,4,"is_a_control");
        $ws->write(0,5,"rep_number");
        $ws->write(0,6,"row_number");
        $ws->write(0,7,"col_number");
        
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
        
        my $line = 1;
        foreach my $n (sort { $a <=> $b } keys(%$design)) { 
            my $plant_names = $design->{$n}->{plant_names};
            foreach (@$plant_names) {
                $ws->write($line, 0, $_);
                $ws->write($line, 1, $design->{$n}->{plot_name});
                $ws->write($line, 2, $design->{$n}->{accession_name});
                $ws->write($line, 3, $design->{$n}->{plot_number});
                $ws->write($line, 4, $design->{$n}->{block_number});
                $ws->write($line, 5, $design->{$n}->{is_a_control});
                $ws->write($line, 6, $design->{$n}->{rep_number});
                $ws->write($line, 7, $design->{$n}->{row_number});
                $ws->write($line, 8, $design->{$n}->{col_number});
                $line++;
            }
        }    
        $ss->close();
    }
    
}

1;
