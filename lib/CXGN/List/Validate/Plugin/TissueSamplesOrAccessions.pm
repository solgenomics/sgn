package CXGN::List::Validate::Plugin::TissueSamplesOrAccessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name {
    return "tissue_samples_or_accessions";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();

    my @missing = ();
    foreach my $l (@$list) {
        my $rs = $schema->resultset("Stock::Stock")->search({
            type_id=> [$accession_type_id, $tissue_sample_type_id],
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
