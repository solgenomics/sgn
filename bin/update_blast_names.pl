#!/usr/bin/perl

use Getopt::Std;
use CXGN::DB::InsertDBH;
use Data::Dumper;
use File::Slurp qw | read_file |;

use vars qw | $opt_H $opt_D $opt_f |;

getopts('H:D:f:');

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    } );

my $file = $opt_f;
my @lines = read_file($file);

my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );

eval { 
    foreach my $l (@lines) {
	
	my ($old_name, $transcript_name, $species, $abbr) = split /\t/, $l;
	
	my $q = "SELECT blast_db_id FROM sgn.blast_db WHERE title=?";
	
	my $h = $dbh->prepare($q);
	$h->execute($old_name);
	
	while (my ($blast_db_id) = $h->fetchrow_array()) {
	    print STDERR "Found $old_name.\n";
	    my $q2 = "UPDATE sgn.blast_db set (title=?) where blast_db_id=?";
	    my $new_name = "$species ($abbr)";
	    $q2->execute($new_name, $blast_db_id);
	    print STDERR "Stored new name $new_name\n";
	}
    }
};

if ($@) {
    print STDERR "An error occurred. Rolling everything back\n";
    $dbh->rollback();
}

else {
    print STDERR "Done. Committing...\n";
    $dbh->commit();

}
