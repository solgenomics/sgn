use strict;
use warnings;

use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Chado::Stock;
use CXGN::Genotype;
use CXGN::Genotype::Search;

our ($opt_H, $opt_D, $opt_p, $opt_o); # host, database, genotyping protocol_id, ouput file
getopts('H:D:p:o:');

my $protocol_id = $opt_p;

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    dbuser => "postgres",
	  }
);
