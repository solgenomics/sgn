
package CXGN::List::Validate::Plugin::Observations;

use Moose;

sub name {
    return "observations";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @missing = ();
    foreach my $l (@$list) {
        print STDERR "Searching using phenotype_id $l\n";
    	my $rs = $schema->resultset("Phenotype::Phenotype")->search(
    	    {
    		phenotype_id=>$l
    	    });
    	if ($rs->count() == 0) {
            print STDERR "Couldn't find $l\n";
    	    push @missing, $l;
    	} else {
            # print STDERR "Found $l with uniquename ".$rs->uniquename()."\n";
        }
    }
    return { missing => \@missing };
}

1;
