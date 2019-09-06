package CXGN::List::Validate::Plugin::Uniquenames;

use Moose;

sub name {
    return "uniquenames";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my @missing = ();
    foreach my $l (@$list){
        my $rs = $schema->resultset("Stock::Stock")->search({
            type_id=>$accession_type_id,
		    uniquename => $l,
	    });
	    if ($rs->count() == 0){
            push @missing, $l;
        }
    }
    return { missing => \@missing };
}

1;
