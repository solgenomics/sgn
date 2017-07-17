use strict;
use warnings;

use CXGN::Stock::StockLookup;
use CXGN::DB::InsertDBH;
use Bio::GeneticRelationships::Pedigree;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::Stock;

our ($opt_H, $opt_D, $opt_o, $opt_f); # host, database, out, in
getopts('H:D:p:o:f:');

my $filename = $opt_f;
open(IN, $filename) or die "Could not open file $filename $!";

open(my $OUT, '>', $opt_o) || die "Can't open output file $opt_o! $!\n";
print $OUT "Child\tFather\tFather Id\n";

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    dbuser => "postgres",
		  }
    );
my %pedigreehash;
my $schema = Bio::Chado::Schema->connect(sub { $dbh });
my $accession_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name=> "accession" })->cvterm_id();
my $stock_rs = $schema->resultset("Stock::Stock")->search( { type_id => $accession_cvterm_id });

while (my $row = <IN>){
    my @pedigreearray = split(/\s/ ,$row);
    my $childname = $pedigreearray[0];
    $pedigreehash{$childname} = "1";
}

while(my $row = $stock_rs->next()){
  unless($pedigreehash{$row->uniquename()}){
    next;
  }
  my $child_name = $row->uniquename();
  print STDERR "Working on accession $child_name... \n";

  my $stock = CXGN::Stock->new(schema=>$schema, stock_id=>$row->stock_id());

  my $parents = $stock->get_parents();
  my $father_name = $parents->{"father"};
  my $father_id = $parents->{"father_id"};
  print $OUT "\t$child_name\t$father_name\t$father_id\n";
}
$dbh->disconnect();

print STDERR "Done.\n";
