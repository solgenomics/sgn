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

open(my $OUT, '>>', $opt_o) || die "Can't open output file $opt_o! $!\n";
$OUT->autoflush(1);
print $OUT "Child\tChild Id\tMother\tMother Id\tFather\tFather Id\tPedigree Conflict Score\n";

my %pedigreehash;
my $childname;
my @pedigreearray;

open(IN, $filename) or die "Could not open file $filename $!";

while (my $row = <IN>){
@pedigreearray = split(/\s/ ,$row);
$childname = $pedigreearray[0];
$pedigreehash{$childname} = "1";
}

my $schema = Bio::Chado::Schema->connect(sub { $dbh });

my $accession_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name=> "accession" })->cvterm_id();

my $stock_rs = $schema->resultset("Stock::Stock")->search( { type_id => $accession_cvterm_id });

my @scores;

while (my $row = $stock_rs->next()) {
    print STDERR "working on accession ".$row->uniquename()."\n";
    unless($pedigreehash{$row->uniquename()}){next;}
    my $stock = CXGN::Stock->new(schema => $schema, stock_id => $row->stock_id());
    my $parents = $stock->get_parents();

    if ($parents->{'mother'} && $parents->{'father'}) {

        my $gts = CXGN::Genotype::Search->new( {
            bcs_schema => $schema,
            accession_list => [ $row->stock_id ],
            protocol_id => $protocol_id,
        });
        my @self_gts = $gts->get_genotype_info_as_genotype_objects();

        if (!@self_gts) {
    	    print STDERR "Genotype of accession ".$row->uniquename()." not available. Skipping...\n";
    	    next;
    	}

        my $mom_gts = CXGN::Genotype::Search->new( {
    	    bcs_schema => $schema,
    	    accession_list => [$parents->{'mother_id'}],
    	    protocol_id => $protocol_id,
        });
    	my @mom_gts = $mom_gts->get_genotype_info_as_genotype_objects();

      if (!@mom_gts) {
    	    print STDERR "Genotype of female parent missing. Skipping.\n";
    	    next;
    	}
      my $dad_gts;
      my @dad_gts;

      if ($parents->{'father_id'} ==  $parents->{'mother_id'}){
          @dad_gts = @mom_gts;
      }
    	else{
      $dad_gts = CXGN::Genotype::Search->new({
    	    bcs_schema => $schema,
    	    accession_list => [$parents->{'father_id'}],
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
}

$dbh->disconnect();

print STDERR "Done.\n";
