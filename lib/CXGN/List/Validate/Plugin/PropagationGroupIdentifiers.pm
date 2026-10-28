
package CXGN::List::Validate::Plugin::PropagationGroupIdentifiers;

use Moose;

sub name {
    return "propagation_groups";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"propagation_group" })->first->cvterm_id();

#    print STDERR "PROPAGATION GROUP IDENTIFIER TYPE ID $type_id\n";

    my @missing = ();
    foreach my $l (@$list) {
        my $rs = $schema->resultset("Stock::Stock")->search({
            type_id=>$type_id,
            uniquename => $l,
            is_obsolete => {'!=' => 't'},
	    });
        if ($rs->count() == 0) {
            push @missing, $l;
        }
    }
    return { missing => \@missing };
}

1;
