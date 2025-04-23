
package CXGN::List::Validate::Plugin::ObsoletedStocks;

use Moose;

sub name {
    return "obsoleted_stocks";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @missing = ();
    foreach my $l (@$list) {
        my $rs = $schema->resultset("Stock::Stock")->search({
            uniquename => $l,
            is_obsolete => 't',
	    });
        if ($rs->count() == 0) {
            push @missing, $l;
        }
    }
    return { missing => \@missing };
}

1;
