#!/usr/bin/perl

use strict;
use warnings;
use Bio::Chado::Schema;
use Getopt::Std;
use CXGN::DB::InsertDBH;


our ($opt_H, $opt_D);
getopts("H:D:"); 
my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = shift;



my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				   dbname=>$dbname,
				   dbargs => {AutoCommit => 1,
					      RaiseError => 1,
				   }

				 } );


my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });


open (my $file_fh, "<", $file ) || die ("\nERROR: the file $file could not be found\n" );

my $header = <$file_fh>;
while (my $line = <$file_fh>) {
    chomp $line;
    my ($plot,$row,$col) = split("\t", $line);


    my $rs = $schema->resultset("Stock::Stock")->search({uniquename=> $plot });

    if ($rs->count()== 1) { 
	my $r =  $rs->first();	
	print STDERR "The plots $plot was found.\n Loading row $row col $col\n";
	$r->create_stockprops({row_number => $row, col_number => $col}, {autocreate => 1});
    }

    else {

	print STDERR "WARNING! $plot was not found in the database.\n";

    }

}




