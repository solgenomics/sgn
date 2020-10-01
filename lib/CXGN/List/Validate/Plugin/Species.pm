
package CXGN::List::Validate::Plugin::Species;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name { 
    return "species";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my %all_names;
    my $q = "SELECT species FROM organism;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($species_name) = $h->fetchrow_array()) {
        $all_names{$species_name}++;
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
