
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
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $q = "SELECT uniquename FROM stock WHERE type_id=$type_id AND is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($uniquename) = $h->fetchrow_array()) {
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
