
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

$dbh->{AutoCommit} = 0;

eval { 
    my $q0 = "SELECT count(*) FROM genotypeprop WHERE genotypeprop_id in (SELECT genotypeprop_id FROM nd_experiment_protocol join nd_experiment_genotype using(nd_experiment_id) JOIN genotypeprop USING(genotype_id) WHERE nd_protocol_id=?)";
    
    my $h0 = $dbh->prepare($q0);
    $h0->execute($opt_p);
    
    my ($count) = $h0->fetchrow_array();
    print "You are about to delete $count genotyping entries. Proceed? Y/n :";
    my $answer = (<>);
    chomp;
    if ($answer !~ m/y|Y/) {
	die "Aborted due to user request.";
    }
    
    print STDERR "Deleteing genotype entries... ";
    my $q1 = "DELETE FROM genotype WHERE genotype_id in (SELECT genotype_id FROM nd_experiment_protocol join nd_experiment_genotype using(nd_experiment_id) JOIN genotype USING(genotype_id) WHERE nd_protocol_id=?)";
    my $h1 = $dbh->prepare($q1);
    $h1->execute($opt_p);
    print STDERR "Done.\n";

    print STDERR "Delete nd_experiment_md_files entries... ";
    my $q8 = "DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id in (SELECT nd_experiment_id FROM nd_experiment_protocol join nd_experiment using(nd_experiment_id) WHERE nd_protocol_id=?)";
    my $h8 = $dbh->prepare($q8);
    $h8->execute($opt_p);
    
    print STDERR "Deleting nd_experiment entries... ";
    my $q2 = "DELETE FROM nd_experiment WHERE nd_experiment_id in (SELECT nd_experiment_id FROM nd_experiment_protocol join nd_experiment using(nd_experiment_id) WHERE nd_protocol_id=?)";
    
    my $h2 = $dbh->prepare($q2);
    $h2 ->execute($opt_p);
    print STDERR "Done.\n";
    
    print STDERR "Deleting protocol entry... ";
    my $q3 = "DELETE FROM nd_protocol WHERE nd_protocol_id=?";
    my $h3 = $dbh->prepare($q3);
    $h3->execute($opt_p);
    print STDERR "Done.\n";
};

if ($@) {
    print STDERR "An error occurred $@... Not deleting.\n";
    $dbh->rollback();
}
else {
    print STDERR "Deletion successful. Commit? Y/N : ";
    my $answer = <>;
    if ($answer =~ m/Y|y/) {
	print STDERR "Deleting... ";
	$dbh->commit();
	print STDERR "Done.\n";
    }
}
	
    

