package CXGN::List::Validate::Plugin::FacilityIdentifiers;

use Moose;

sub name {
    return "facility_identifiers";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $facility_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'facility_identifier', 'stock_property')->cvterm_id();

    my @missing = ();
    foreach my $l (@$list){
        my $rs = $schema->resultset("Stock::Stockprop")->search({
            type_id=>$facility_identifier_type_id,
		    value => $l,
	    });
	    if ($rs->count() == 0){
            push @missing, $l;
        }
    }
    return { missing => \@missing };
}

1;
