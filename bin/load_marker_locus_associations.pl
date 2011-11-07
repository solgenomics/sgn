
=head1 NAME

load_marker_locus_associations.pl - load associations between markers and loci.

=head1 DESCRIPTION

takes a file with two columns: locus names and marker names. Connects the two in the phenome.locus_marker table.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Std;
use File::Slurp;
use CXGN::DB::InsertDBH;
use CXGN::Marker;
use CXGN::Phenome::Locus;

our %args;

getopts('H:D:f:', \%args);

foreach (values %args) { 
    print STDERR "param:  $_\n";
}

my $dbh = CXGN::DB::InsertDBH->new( { dbname=> $args{D},
				      dbhost=> $args{H}
				    });
	
print STDERR "Reading file $args{f}\n";		    
my @lmas = read_file($args{f});

foreach my $line (@lmas) { 
    chomp($line);
    my ($locus_symbol, $marker_name)  = split /\t/, $line;

    my $m = CXGN::Marker->new_with_name($dbh, $marker_name);
    if (!$m) { print STDERR "Marker not found: $marker_name. Skipping\n"; next; }
    my $marker_id = $m->marker_id();

    my $h = $dbh -> prepare("SELECT locus_id FROM phenome.locus JOIN phenome.locus_alias using(locus_id) WHERE locus_name ilike ? OR locus_alias.alias ilike ? OR locus_symbol ilike ?");
    
    $h->execute($locus_symbol, $locus_symbol, $locus_symbol);

    my @ids = ();
    while (my ($locus_id) = $h->fetchrow_array()) { 
	push @ids, $locus_id;
    }
    if (@ids > 1) { 
	warn "There are more than 1 loci associated with SNP $marker_name\n";
    }
    
    if (@ids == 0) { 
	warn "Locus $locus_symbol not found.\n";
    }
    foreach my $locus_id (@ids) { 
	my $l = CXGN::Phenome::Locus->new($dbh, $locus_id);
	
	my $q = $dbh->prepare("INSERT INTO phenome.locus_marker (locus_id, marker_id) VALUES (?, ?)");
	$q -> execute($locus_id, $marker_id);
	print STDERR "Associated locus $locus_symbol ($locus_id) with marker $marker_name ($marker_id)\n";
    }
}
   
$dbh->commit();



						
