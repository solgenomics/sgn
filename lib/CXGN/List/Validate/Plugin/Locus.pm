
package CXGN::List::Validate::Plugin::Locus;

use strict;
use warnings;
use Moose;

sub name { 
    return "locus";
}

sub validate { 
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $str;
    my $key;
    my $data;
    my $locus;
    my $term;
    my $count;
    my $protocol_id;
    my $found;
    my @row;
    my @missing = ();

    my $q = "select cvterm_id from public.cvterm where name = 'vcf_map_details'";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array();

    $q = "SELECT locus_id from phenome.locus where locus_name = ?";
    $h = $schema->storage->dbh()->prepare($q);

    foreach my $term (@$list) {
        foreach my $locus ( $term ) {
	   $h->execute($locus);
	    if (@row = $h->fetchrow_array()) {
	    } else {
	        push @missing, $term;
	    }
        }
        #$schema->storage->debug(1);
    }
    return { missing => \@missing };

}

1;
