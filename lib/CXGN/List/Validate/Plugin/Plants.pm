
package CXGN::List::Validate::Plugin::Plants;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name { 
    return "plants";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my %all_names;
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $q = "SELECT stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id=$plant_type_id AND stock.is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($uniquename, $synonym, $type_id) = $h->fetchrow_array()) {
        $all_names{$uniquename}++;
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
