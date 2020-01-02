package CXGN::List::Transform::Plugin::Plots2Accessions;

use Moose;
use List::MoreUtils qw / uniq /;

sub name { 
    return "plots_2_accessions";
}

sub display_name { 
    return "plots to accessions";
}

sub can_transform { 
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "plots") and ($type2 eq "accessions")) { 
	return 1;
    }
    else {  return 0; }
}
    

sub transform { 
    my $self = shift;
    my $schema = shift;
    my $plots = shift;

  
    my $acc_rs = $schema->resultset("Stock::Stock")
        ->search({'me.uniquename' =>{-in =>  $plots}})
        ->search_related('stock_relationship_subjects')
        ->search_related('object');

    my @accession_names;
    my @accession_ids;
    
    while (my $acc = $acc_rs->next) 
    {
	push @accession_names, $acc->uniquename;
	push @accession_ids, $acc->id;
    }

    @accession_names = uniq(@accession_names); 
    @accession_ids = uniq(@accession_ids);

    return {
	accession_ids => \@accession_ids,
	acccession_names => \@accession_names
    }
}

1;
