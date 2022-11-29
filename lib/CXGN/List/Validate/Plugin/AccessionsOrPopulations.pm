
package CXGN::List::Validate::Plugin::AccessionsOrPopulations;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;

sub name { 
    return "accessions_or_populations";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my %all_names;
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $population_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $q = "SELECT stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE (stock.type_id=$accession_type_id OR stock.type_id=$population_type_id) AND stock.is_obsolete = 'F';";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($uniquename, $synonym, $type_id) = $h->fetchrow_array()) {
        $all_names{$uniquename}++;
        if ($type_id) {
            if ($type_id == $synonym_type_id) {
                $all_names{$synonym}++;
            }
        }
    }

    #print STDERR Dumper \%all_names;
    my @missing;
    my @valid;
    
    foreach my $item (@$list) {
        if (!exists($all_names{$item})) {
            push @missing, $item;
        }
	else {
	    push @valid, $item;
	}
    }

    return {
	missing => \@missing,
	valid => \@valid,
    };
}

1;
