
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
    	my $rs = $schema->resultset("Phenotype::Phenotype")->search({ phenotype_id=>$l });
    	if ($rs->count() == 0) {
            # print STDERR "Couldn't find $l\n";
    	    push @missing, $l;
    	}
    }
    return { missing => \@missing };
}

1;
