package CXGN::List::Transform::Plugin::Stocks2StockIds;

use Moose;

sub name {
    return "stocks_2_stock_ids";
}

sub display_name {
    return "stocks to stock IDs";
}

sub can_transform {
    my $self = shift;
    my $type1 = shift;
    my $type2 = shift;

    if (($type1 eq "stocks") and ($type2 eq "stock_ids")) {
        return 1;
    }
    else {  return 0; }
}


sub transform {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my @transform = ();

    my @missing = ();

    if (ref($list) eq "ARRAY" ) {
        foreach my $l (@$list) {
            my $rs = $schema->resultset("Stock::Stock")->search( { uniquename => $l });

            if ($rs->count() == 0) {
                push @missing, $l;
            } elsif ($rs->count() > 1) {
                die "Found more than one id ".$rs->first()->stock_id()." for stock $l\n";
            } else {
                push @transform, $rs->first()->stock_id();
            }
        }
    }
    return {
        transform => \@transform,
        missing => \@missing,
    };
}

1;
