#!/usr/bin/perl

=head1

change_trait_ids.pl

=head1 SYNOPSIS

    change_trait_ids.pl -H [dbhost] -D [dbname] -i [tsv file with old and new ids] [-t]

		If an error caused by a duplicate key value is thrown, for example:

		DBD::Pg::st execute failed: ERROR:  duplicate key value violates unique constraint "dbxref_c1"
		DETAIL:  Key (db_id, accession, version)=(274, 1000004, ) already exists. at ./sgn/bin/change_trait_ids.pl line 69, <FILE> line 87.

		You can manually alter the dbxref accession value in the db to something non-conflicting, for example:
		"update dbxref set accession = '1444444' where accession = '1000004' and db_id = 274;"
		then re-run this script. This process may have to be repeated for multiple ids

=head1 COMMAND-LINE OPTIONS

 -H host name
 -D database name
 -i file with old and new ids
 -t Test run. Rolls back at the end.

=head1 DESCRIPTION

=head1 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu) - Sept 2016

=cut

use strict;
use warnings;

use Getopt::Std;
use Try::Tiny;
use CXGN::DB::InsertDBH;

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:i:D:t');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;
my $dbh;
my %seq;

# store database handle and schema

$dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 0,
						 RaiseError => 1}
				    }
    );

# prepare sql delete statements

my $update_query = "Update dbxref set accession = ? where accession = ? and db_id = ((SELECT dbxref_1.db_id FROM stock JOIN nd_experiment_stock USING (stock_id) JOIN nd_experiment_phenotype USING (nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm cvterm_1 ON phenotype.cvalue_id = cvterm_1.cvterm_id JOIN dbxref dbxref_1 ON cvterm_1.dbxref_id = dbxref_1.dbxref_id LIMIT 1 ));";
my $update_handle = $dbh->prepare($update_query);

try {
        # identify ids to be changed

	open (FILE, "<", $opt_i) || die "Can't open infile $opt_i \n";

	while (<FILE>) {
	    my ($new_id, $old_id) = split('\t', $_);
      chomp $old_id;
      $new_id =~ s/.*://;
      $old_id =~ s/.*://;
      print STDERR "Updating old id $old_id to new id $new_id\n";
      #chomp (my $ids = $_);
	    $update_handle->execute($new_id, $old_id);
			my $pattern = '%';
			$pattern .= $old_id;
			my $list_fix = "update sgn_people.list_item set content = regexp_replace(content, ':.*', ':$new_id') where content like '$pattern';";
			print STDERR "updating list elements with query: $list_fix\n";
			my $list_fix_handle = $dbh->prepare($list_fix);
			$list_fix_handle->execute();
	}
} catch {
   # Rollback if transaction failed

	$dbh->rollback();
	die "An error occured! Transaction rolled back!" . $_ . "\n";
};

if (!$opt_t) {
    # commit if this is not a test run

    $dbh->commit();
    print "Id update succeeded! Commiting new ids! \n\n";
} else {
    # Rolling back because test run

    print "No errors occurred. Rolling back test run. \n\n";
    $dbh->rollback();
}
