
package CXGN::List::Validate::Plugin::PropagationIdentifiers;

use Moose;

sub name {
    return "propagation";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"propagation" })->first->cvterm_id();

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
