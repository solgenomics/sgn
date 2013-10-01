
package CXGN::List::Validate::Plugin::Traits;

use Moose;
use Data::Dumper;

sub name { 
    return "traits";
}

sub validate { 
    my $self = shift;
    my $c = shift;
    my $list = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
        
    print STDERR "LIST: ".Data::Dumper::Dumper($list);

    my @missing = ();
    foreach my $term (@$list) { 

	my ($db_name, $accession) = split ":", $term;
	
	print STDERR "Checking $term...\n";
	my $rs = $schema->resultset("General::Dbxref")->search( { 'db.name'=>$db_name, 'accession'=>$accession }, { join => 'db' });

	print STDERR "COUNT: ".$rs->count."\n";
	
	if ($rs->count == 0) { 
	    push @missing, $term;
	}
    }
    return { missing => \@missing };

   }

1;
