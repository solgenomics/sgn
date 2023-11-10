
package CXGN::List::Validate::Plugin::Seedlots;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name {
    return "seedlots";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my %all_names;
    my %all_discarded;
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $discarded_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'discarded_metadata', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.uniquename, stockprop_synonym.value, stockprop_discarded.value
        FROM stock LEFT JOIN stockprop AS stockprop_synonym ON (stock.stock_id = stockprop_synonym.stock_id) AND stockprop_synonym.type_id = ?
        LEFT JOIN stockprop AS stockprop_discarded ON (stock.stock_id = stockprop_discarded.stock_id) AND stockprop_discarded.type_id = ?
        WHERE stock.type_id = ? AND stock.is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($synonym_type_id, $discarded_type_id, $seedlot_type_id);
    my %result;
    while (my ($uniquename, $synonym, $discarded) = $h->fetchrow_array()) {
        if (defined $discarded) {
            $all_discarded{$uniquename}++;
        } else {
            $all_names{$uniquename}++;
            if (defined $synonym) {
                $all_names{$synonym}++;
            }
        }
    }

    #print STDERR Dumper \%all_names;
    my @missing;
    my @discarded;
    foreach my $item (@$list) {
        if (!exists($all_names{$item})) {
            push @missing, $item;
        }
        if (exists($all_discarded{$item})) {
            push @discarded, $item;
        }
    }

    return { missing => \@missing, discarded => \@discarded };
}

1;
