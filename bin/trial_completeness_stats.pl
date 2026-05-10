
use strict;

use Getopt::Std;
use Bio::Chado::Schema;
use DBI;
use CXGN::DB::InsertDBH;
use CXGN::DbStats;


our ($opt_H, $opt_D, $opt_s, $opt_e);

getopts('H:i:tD:p:y:g:axsm:');

my $dbhost = $opt_H;
my $dbname = $opt_D;

if (!$opt_H || !$opt_D) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), optionally -s start_date and -e end_date");
}

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );

my $start_date = $opt_s || '1900-01-01';
my $end_date = $opt_e || '2100-01-01';

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my $db_stats = CXGN::DbStats->new( { dbh=> $dbh, start_date => $start_date, end_date => $end_date, include_dateless_items => 1 });


$db_stats->phenotype_completeness_by_breeding_program_and_trial();
