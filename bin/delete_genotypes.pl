
=head1 NAME

delete_genotypes.pl - delete genotypes from a cxgn database

=head1 DESCRIPTION

 perl delete_genotypes.pl -H [host] -D [dbname] -t (for testing) file

 -p protocol_id

If the -t flag is provided, the changes will be rolled back in the database.




=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use Getopt::Std;
use DBI;
use Bio::Chado::Schema;
use CXGN::Phenome::Schema;

our ($opt_H, $opt_D, $opt_t, $opt_p);
getopts('H:D:tp:');

my $file = shift;

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
my $bcs_schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);
my $phenome_schema = CXGN::Phenome::Schema->connect($dsn, "postgres", $pw,  { on_connect_do => ['set search_path to public,phenome;'] });

my $q0 = "SELECT count(*) FROM genotypeprop WHERE genotype_id in (SELECT nd_genotype_id FROM nd_experiment_protocol join nd_experiment_genotype using(nd_protocol_id) JOIN genotypeprop USING(genotype_id) WHERE nd_protocol_id=?)";

    
my $q1 = "DELETE FROM genotype WHERE genotype_id in (SELECT nd_genotype_id FROM nd_experiment_protocol join nd_experiment_genotype using(nd_protocol_id) JOIN genotype USING(genotype_id) WHERE nd_protocol_id=?)";

my $h1 = $dbh->prepare($q1);
$h1->execute($opt_p);

my $q2 = "DELETE FROM nd_experiment WHERE nd_experiment_id in (SELECT nd_experiment_id FROM nd_experiment_protocol join nd_experiment using(nd_protocol_id) WHERE nd_protocol_id=?)";

my $h2 = $dbh->prepare($q2);
$h2 ->execute($opt_p);

my $q3 = "DELETE FROM nd_experiment WHERE nd_experiment_id=?";
my $h3 = $dbh->prepare($q3);
$h3->execute($opt_p);

	
    

