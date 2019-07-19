
package CXGN::List::Validate::Plugin::FamilyNames;

use Moose;

sub name {
    return "family_names";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"family_name" })->first->cvterm_id();

    #print STDERR "FAMILY NAME TYPE ID $type_id\n";

    my @missing = ();
    foreach my $l (@$list) {
	my $rs = $schema->resultset("Stock::Stock")->search(
	    {
		type_id=>$type_id,
		uniquename => $l,
	    });
	if ($rs->count() == 0) {
	    push @missing, $l;
	}
    }
    return { missing => \@missing };
}

1;
