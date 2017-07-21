use strict;
use warnings;

use Data::Dumper;
use Getopt::Std;
use IO::Handle;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Stock;
use CXGN::Genotype;
use CXGN::Genotype::Search;

our ($opt_H, $opt_D, $opt_p, $opt_o, $opt_f); # host, database, genotyping protocol_id, out, in
getopts('H:D:p:o:f:');

if (!$opt_p) {
    print STDERR "Need -p with genotyping protocol id.\n";
    exit();
}

my $protocol_id = $opt_p;
my $filename = $opt_f;

my $dbh = CXGN::DB::InsertDBH->new({
    dbhost => $opt_H,
    dbname => $opt_D,
    dbuser => "postgres",
});
my $schema = Bio::Chado::Schema->connect(sub { $dbh });

open(my $OUT, '>>', $opt_o) || die "Can't open output file $opt_o! $!\n";
$OUT->autoflush(1);

open(IN, $filename) or die "Could not open file $filename $!";

while (my $row = <IN>){
  my @pedigreearray = split(/\s/ ,$row);
  my $childname = $pedigreearray[0];
  my $mothername = $pedigreearray[1];
  my $fathername = $pedigreearray[2];

  my $stock_rs = $schema->resultset("Stock::Stock")->find({uniquename => $childname});
  my $stock_id = $stock_rs->stock_id;
  my $mother_rs = $schema->resultset("Stock::Stock")->find({uniquename => $mothername});
  my $mother_id = $mother_rs->stock_id;
  my $father_rs = $schema->resultset("Stock::Stock")->find({uniquename => $fathername});
  my $father_id = $father_rs->stock_id;

  my $gts = CXGN::Genotype::Search->new( {
      bcs_schema => $schema,
      accession_list => [$stock_id],
      protocol_id => $protocol_id,
  });
  my @self_gts = $gts->get_genotype_info_as_genotype_objects();

  if (!@self_gts) {
	    print STDERR "Genotype of accession ".$row->uniquename()." not available. Skipping...\n";
	    next;
	}
  my $mom_gts = CXGN::Genotype::Search->new( {
	  bcs_schema => $schema,
	  accession_list => [$mother_id],
	  protocol_id => $protocol_id,
  });
	my @mom_gts = $mom_gts->get_genotype_info_as_genotype_objects();
  if (!@mom_gts) {
	    print STDERR "Genotype of female parent missing. Skipping.\n";
	    next;
	}
  my $dad_gts;
  my @dad_gts;

  if ($mother_id == $father_id){
      @dad_gts = @mom_gts;
  }
	else{
  $dad_gts = CXGN::Genotype::Search->new({
	    bcs_schema => $schema,
	    accession_list => [$father_id],
	    protocol_id => $protocol_id,
	});
	@dad_gts = $dad_gts->get_genotype_info_as_genotype_objects();
	}

  if (!@dad_gts) {
	    print STDERR "Genotype of male parent missing. Skipping.\n";
	    next;
  }

  my $s = shift @self_gts;
  my $m = shift @mom_gts;
  my $d = shift @dad_gts;
  my ($concordant, $discordant, $non_informative) = $s->compare_parental_genotypes($m, $d);
  my $score = 1- ($concordant / ($concordant + $discordant));

  print STDERR "scores are". $score. "\n";
  print $OUT join "\t", map { ($_->name(), $_->id()) } ($s, $m, $d);
  print $OUT "\t$score\n";
}


$dbh->disconnect();

print STDERR "Done.\n";
