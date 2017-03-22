
use strict;
use warnings;

use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Chado::Stock;
use CXGN::Genotype;
use CXGN::Genotype::Search;

our ($opt_H, $opt_D, $opt_p); # host, database, genotyping protocol_id
getopts('H:D:p:');

if (!$opt_p) { 
    print STDERR "Need -p with genotyping protocol id.\n";
    exit();
}

my $protocol_id = $opt_p;

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    dbuser => "postgres",
				    }
    );


my $schema = Bio::Chado::Schema->connect(sub { $dbh });

my $accession_cvterm_id = $schema->resultset("Cv::Cvterm")->find({ name=> "accession" })->cvterm_id();

my $stock_rs = $schema->resultset("Stock::Stock")->search( { type_id => $accession_cvterm_id });

my @scores;

while (my $row = $stock_rs->next()) { 
    my $stock = CXGN::Chado::Stock->new($schema, $row->stock_id());
    my @parents = $stock->get_direct_parents();
    
    if (@parents == 2) { 
	
	my $gts = CXGN::Genotype::Search->new( { 
	    bcs_schema => $schema,
	    accession_list => [ $row->stock_id, $parents[0]->[0],
				$parents[1]->[0] ],
	    protocol_id => $protocol_id,
							    });
	
	my @genotypes = $gts->get_genotype_info_as_genotype_objects();
	
	if (@genotypes != 3) { 
	    print $row->uniquename()."\thas".scalar(@genotypes).". Need 3.\n";
	    next;
	}

	my ($concordant, $discordant, $non_informative) = 
	    $genotypes[0]->compare_parental_genotypes($genotypes[1], $genotypes[2]);
	my $score = $concordant / ($concordant + $discordant);
	push @scores, $score;
	
	print  join "\t", map { $_->name() } @genotypes;
	print "\t$score\n";
    }
}

$dbh->disconnect();

