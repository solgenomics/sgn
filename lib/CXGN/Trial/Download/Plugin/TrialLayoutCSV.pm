
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

    my $header = join (",", "plot_name", "accession_name", "plot_number","block_number", "is_a_control", "rep_number");
    
    print $F $header."\n";

    my $line = 1;
    foreach my $n (sort { $a <=> $b } keys(%$design)) { 
     	print $F join ",", 
	$design->{$n}->{plot_name},
	$design->{$n}->{accession_name},
	$design->{$n}->{plot_number},
	$design->{$n}->{block_number},
	$design->{$n}->{is_a_control},
	$design->{$n}->{rep_number};
	print $F "\n";
    }
    close($F);
}

1;
