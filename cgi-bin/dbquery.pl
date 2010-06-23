# ---- Connect to database ---- #

use DBI;
use strict;
use warnings;

my $dbh = DBI->connect("dbi:Pg:dbname='cxgn'; host='localhost'",'postgres', 'c0d3r!!', {AutoCommit => 0, RaiseError =>1});

#my @all_species = $schema->


# ---- This code works, it prints the species from the table organism ---- #
my $sth = $dbh->prepare("SELECT species FROM Public.organism");
$sth->execute();

while (my @r = $sth->fetchrow_array()){
    print $r[0]."\n";
}

$dbh->rollback;
