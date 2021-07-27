package CXGN::List::Validate::Plugin::AccessionsOrCrosses;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name {
    return "accessions_or_crosses";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my @missing = ();
    foreach my $l (@$list) {
        my $rs = $schema->resultset("Stock::Stock")->search({
            type_id=> [$accession_type_id, $cross_type_id],
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
