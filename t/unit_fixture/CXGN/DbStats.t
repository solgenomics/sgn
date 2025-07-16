

use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;

use CXGN::DbStats;

my $f = SGN::Test::Fixture->new();

my $dbs = CXGN::DbStats->new( { dbh => $f->dbh() });

my $types = $dbs->trial_types();

my $trial_count_by_breeding_program = $dbs->trial_count_by_breeding_program();

my $phenotype_count_by_breeding_program = $dbs->phenotype_count_by_breeding_program();

my $traits = $dbs->traits();

is($traits->[0]->[1], 999, "spot check trait result");

print STDERR "Traits: ".Dumper($traits);

my $stocks = $dbs->stocks();

is($stocks->[0]->[1], 1955, "spot check stock result");

print STDERR "Stocks: ".Dumper($stocks);

my $projects = $dbs->projects();

is($projects, 30, "project check");

print STDERR "Projects: ".Dumper($projects);

my $activity = $dbs->activity();

print STDERR "Activity: ".Dumper($activity);

my $stock_stats = $dbs->stock_stats();

is($stock_stats->[0]->[1], 479, "stock stats check");

print STDERR "Stock stats: ".Dumper($stock_stats);

my $accession_count_by_breeding_program = $dbs->accession_count_by_breeding_program();

is($accession_count_by_breeding_program->[0]->[1], 45, "accession by breeding program test");

print STDERR "Accession_count : ".Dumper($accession_count_by_breeding_program);

my $accession_count_by_breeding_program_without_trials = $dbs->accession_count_by_breeding_program_without_trials();

is(scalar(@$accession_count_by_breeding_program_without_trials), 0, "accessions without trials");

print STDERR "Accession_count without trials: ".Dumper($accession_count_by_breeding_program_without_trials);

my $plot_count_by_breeding_program = $dbs->plot_count_by_breeding_program();

is($plot_count_by_breeding_program->[0]->[1], 5456, "plot count by breeding program check"); 

print STDERR "Plot count : ".Dumper($plot_count_by_breeding_program);

my $germplasm_count_with_pedigree = $dbs->germplasm_count_with_pedigree();

print STDERR "Germplasm count with pedigrees: ".Dumper($germplasm_count_with_pedigree);

my $germplasm_count_with_phenotypes = $dbs->germplasm_count_with_phenotypes();

print STDERR "Germplasm_count_with_phenotypes : ".Dumper($germplasm_count_with_phenotypes);

my $germplasm_count_with_genotypes = $dbs->germplasm_count_with_genotypes();

print STDERR "Germpalsm count with genotypes: ".Dumper($germplasm_count_with_genotypes);

my $phenotype_count_per_trial = $dbs->phenotype_count_per_trial();

print STDERR "PHenotype count per trial: ".Dumper($phenotype_count_per_trial);

done_testing();
