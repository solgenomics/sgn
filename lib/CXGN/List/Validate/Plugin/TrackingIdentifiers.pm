package CXGN::List::Validate::Plugin::TrackingIdentifiers;

use Moose;

sub name {
    return "tracking_identifiers";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $tracking_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();

    my @missing = ();
    foreach my $l (@$list){
        my $rs = $schema->resultset("Stock::Stock")->search({
            type_id=>$tracking_identifier_type_id,
		    uniquename => $l,
            is_obsolete => {'!=' => 't'},
	    });
	    if ($rs->count() == 0){
            push @missing, $l;
        }
    }
    return { missing => \@missing };
}

1;
