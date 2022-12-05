#!/usr/bin/perl

use strict;
use warnings;
use Bio::Chado::Schema;
use Getopt::Std;
use SGN::Model::Cvterm;
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

print STDERR "Getting genotype names... ";
my %g2s;

my $q = "SELECT genotype.uniquename, stock.uniquename FROM genotype join nd_experiment_genotype using(genotype_id) JOIN nd_experiment_stock using(nd_experiment_id) join stock using(stock_id)";

my $h = $dbh->prepare($q);
$h->execute();

while (my ($gt, $stock) = $h->fetchrow_array()) {
    $g2s{uc($gt)} = $stock;#uc($stock);
    if ($gt =~ m/(.*?)\|(.*)/) {
	$g2s{uc($1)} = $stock; #uc($stock);
    }
}

print STDERR "Done.\n";

my %stock_types;
print STDERR "Getting stock type ids... ";
my $rs = $schema->resultset("Cv::Cvterm")->search( { 'cv.name' => 'stock_type'}, { join => 'cv' } );

while (my $r = $rs->next()) {
    $stock_types{$r->cvterm_id()} = $r->name();
}

print STDERR "Done.\n";
    
open (my $file_fh, "<", $file ) || die ("\nERROR: the file $file could not be found\n" );

my $synonym_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
my $accession_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

my %stats;
my $line_count = 0;

while (my $line = <$file_fh>) {
    chomp($line);

    $line_count++;
    
    $line = uc($line);
    
    my $id = $line;
    if ($line =~ m/(.*?)\:(.*)$/) {
	$id = $1;
    }

#    if ($line =~ /^(TMS.*)\_A\d{5}$/) {
#	$id = $1;
#    }
    
    my $uniquename = "";
    my $match_type = "";
    my $stock_type = "";
    
    if ($g2s{$line}) {
	$uniquename = $g2s{$line};
	$match_type = "hash_direct";
	$stats{hash_direct}++;

	my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => { ilike => $uniquename } });
	
	$stock_type = $stock_types{$stock_row->type_id};# "accession";
    }
    elsif( $g2s{$id}) {
	$uniquename = $g2s{$id};
	$match_type = "hash_modified";
	$stats{hash_modified}++;

	my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => { ilike => $uniquename } });
	$stock_type = $stock_types{$stock_row->type_id}; #"accession";	
    }
    else {
	
	my $stock_row = $schema->resultset("Stock::Stock")->find( { uniquename => { ilike => $id } });
		
	if ($stock_row) {
	    $uniquename = $stock_row->uniquename();
	    $match_type = "direct";
	    $stats{direct}++;
	    $stock_type = $stock_types{$stock_row->type_id} || $stock_row->type_id;
	}
	else {
	    my $syn_rs = $schema->resultset("Stock::Stockprop")->search( { value => { ilike => $id }, 'me.type_id' => $synonym_id }, { join => 'stock' } );

	    
	    if ($syn_rs->count() == 1) {
		my $row = $syn_rs->first()->stock();
		$uniquename = $row->uniquename();
		$match_type = "synonym";
		$stats{synonym}++;
		$stock_type = $stock_types{$row->type_id()} || $row->type_id();
	    }
	    elsif ($syn_rs->count() > 1) {
		while (my $r = $syn_rs->next()) {
		    $uniquename .= $r->stock->uniquename().",";
		    $match_type = "multiple synonyms";
		    $stats{multiple_synonyms}++;
		    $stock_type .= $stock_types{$r->stock->type_id()}.",";
		}
	    }		    
	    else {
		$uniquename = $line;
		$match_type = "absent";
		$stats{absent}++;
	    }
	}
    }

    my $out = join("\t", $line, $id, $uniquename, $match_type, $stock_type);

    print "$out\n";

    
    if ($line_count % 100 == 0) { 
	print STDERR "Processing: ".join (", ", (map { "$_ : $stats{$_}" } sort keys(%stats)))."\r";
    }

    
}
    

print STDERR "Done.\n";
print STDERR "Complete.\n";
