
package CXGN::Trial::Download::Plugin::TrialLayoutExcel;

use Moose::Role;

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

    $ws->write(0,0,"plot_name");
    $ws->write(0,1,"accession_name");
    $ws->write(0,2,"plot_number");
    $ws->write(0,3,"block_number");
    $ws->write(0,4,"is_a_control");
    $ws->write(0,5,"rep_number");
    
    my $line = 1;
    foreach my $n (sort { $a <=> $b } keys(%$design)) { 
     	print STDERR "plot name ".$ws->write($line, 0, $design->{$n}->{plot_name});
	print STDERR " accession name ".$ws->write($line, 1, $design->{$n}->{accession_name});
     	print STDERR " plot number ".$ws->write($line, 2, $design->{$n}->{plot_number});
     	print STDERR " block number ".$ws->write($line, 3, $design->{$n}->{block_number});
     	print STDERR " is a control ".$ws->write($line, 4, $design->{$n}->{is_a_control});
     	print STDERR " rep number ".$ws->write($line, 5, $design->{$n}->{rep_number});
     	$line++;
    }    
    $ss->close();
}

1;
