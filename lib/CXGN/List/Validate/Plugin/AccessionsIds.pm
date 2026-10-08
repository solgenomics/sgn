
package CXGN::List::Validate::Plugin::AccessionsIds;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name { 
    return "accessions_ids";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my %all_names;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $q = "SELECT stock_id FROM stock WHERE type_id=$type_id AND is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($accession_id) = $h->fetchrow_array()) {
        $all_names{$accession_id}++;
    }

    #print STDERR Dumper \%all_names;
    my @missing;
    foreach my $item (@$list) {
        if (!exists($all_names{$item})) {
            push @missing, $item;
        }
    }

    return { missing => \@missing };
}

1;
