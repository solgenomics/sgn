
=head1 NAME

download_trials.pl - script to download trials

=head1 DESCRIPTION

perl download_spatial_trials.pl -H host (breedbase_db) -D dbname (cxgn_cassava) -U dbuser (postgres) -P dbpass (postgres)

Downloads trials whose ids are provided as a comma separated list for the -i parameter.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Data::Dumper;

use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Trial;

our ($opt_H, $opt_D, $opt_U, $opt_P);

getopts('H:D:U:P');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
#my $non_interactive = $opt_n;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 0,
				      RaiseError => 1}
				    }
    );

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });
my $people_schema = CXGN::People::Schema->connect( sub { $dbh->get_actual_dbh() } );

print STDERR "Retrieving all projects...\n";
my $trial_rs = $schema->resultset("Project::Project")->search( { } ); # get all trials

my @trial_ids;

while (my $row= $trial_rs->next()) {
    print STDERR "Retrieving project row with id ".$row->project_id()."\n";
    push @trial_ids, $row->project_id();
}


my @spreadsheet;
my %trial_data;
my %trial_cols;

foreach my $trial_id (@trial_ids) { 
    print STDERR "Retrieving trial information for trial $trial_id...\n";

    my $t = CXGN::Trial->new({
        bcs_schema => $schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        trial_id => $trial_id
    });

    if ($t->isa("CXGN::PhenotypingTrial")) {
	print STDERR "We have a field trial!\n";
    }
    else {
	print STDERR "Trial with id $trial_id is not a field trial. Skipping.\n";	
	next();
    }

    if (! $t->has_col_and_row_numbers()) {
	print STDERR "Trial with id $trial_id does not have a spatial layout. Skipping.\n";
	next();
    }

    # retrieve associated genotypes using a dataset
    #
    my $d = CXGN::Dataset::File->new( { people_schema => $people_schema, schema => $schema } );
    
    $d->trials( [ $trial_id ]);

    my $genotyping_protocols = $d->retrieve_genotyping_protocols();

    if (ref($genotyping_protocols) && (@$genotyping_protocols > 0) ) {

	my $accessions = $d->retrieve_accessions();

	print STDERR "Genotyping protocols: ". Dumper($genotyping_protocols). Dumper($accessions);
    }
    else {
	print STDERR "This trial has no genotyping info associated with it. Skipping!\n";
	next();
    }
    
    my $location = $t->get_location();

    my $breeding_programs = $t->get_breeding_programs();

    my $breeding_program_name = $t->get_breeding_program();

    my $planting_date = $t->get_planting_date();

    my $harvest_date = $t->get_harvest_date();
    
    my $breeding_program_id;
    my $breeding_program_description;
    
    foreach my $bp (@$breeding_programs) {
	if ($bp->[1] eq $breeding_program_name) {
	    $breeding_program_id = $bp->[0];
	    $breeding_program_description = $bp->[2];
	}
    }

    my $trial_name = $t->get_name();

    my $traits = $t->get_traits_assayed();

    my $year = $t->get_year();

    my $trial_id = $t->get_trial_id();

    my $design_type = $t->get_design_type();

    my $plot_width = $t->get_plot_width();

    my $plot_length = $t->get_plot_length();
    
    print STDERR "Traits assayed = ".Dumper($traits);

    my @trait_names = map { $_->[1] } @$traits;
    my @trait_ids = map { $_->[0] } @$traits;

    print STDERR "trait_ids = ". Dumper(\@trait_ids);
    
    my $data = $t->get_stock_phenotypes_for_traits(\@trait_ids, 'all', ['plot_of','plant_of'], 'accession', 'subject');

    print STDERR Dumper($data);


    $trial_data{$trial_id} = $data;
    $trial_cols{$trial_id} = [ $year, $breeding_program_id, $breeding_program_name, $breeding_program_description, $trial_id, $trial_name, $design_type, $plot_width, $plot_length, '', '', '', $planting_date, $harvest_date, $location->[0], $location->[1] ];

    
}

my @trial_header = qw | studyYear programDbId breeding_programName programDescription studyDbId studyName studyDesign plotWidth plotLength fieldSize fieldTrialIsPlannedToBeGenotyped fieldTrialIsPlannedToCross plantingDate harvestDate, locationDbId, locationName |;

# first organize traits in hash structure
my %obs;
my %traits;
my %plots;
my %plot_ids;
foreach my $trial_id (keys %trial_data) { 
    foreach my $line (@{$trial_data{$trial_id}}) {
	# keys: {trial_id} -> {accession}-> {plot} -> {trait} = value
	$obs{$trial_id}->{$line->[9]}->{$line->[1]}->{$line->[3]} = $line->[7];
	$traits{$line->[3]}++;
	$plots{$line->[1]} = $line->[0];
    }

}


# get plot metadata

my %plot_data;
foreach my $p (keys %plots) {
    my $rs= $schema->resultset("Stock::Stockprop")->search( { stock_id => $plots{$p} }, { join => 'type', '+select' => 'type.name', '+as'=> 'cvterm_name' });

    while (my $row = $rs->next()) {
	print STDERR "stockprop: ".$row->get_column("cvterm_name"). " ".$row->value()."\n";
	$plot_data{$p}->{$row->get_column("cvterm_name")} = $row->value();
    }
}


print STDERR "observations: ".Dumper(\%obs);

print STDERR "Traits: ".Dumper(\%traits);

print join("\t", (@trial_header, 'accession',  'plot', 'replicate', 'blockNumber', 'plotNumber', 'rowNumber', 'colNumber', 'entryType', sort(keys(%traits))))."\n";
    
foreach my $trial_id (keys(%obs)) {

    foreach my $accession (keys %{$obs{$trial_id}}) {
	
	foreach my $plot (keys %{$obs{$trial_id}->{$accession}}) { 

	    
	    my @out = ( @{$trial_cols{$trial_id}}, $accession, $plot );

	    foreach my $prop (qw| replicate block_number plot_number row_number col_number entry_type |) {
		push @out, $plot_data{$plot}->{$prop};
	    }

	    
	    foreach my $trait (sort(keys %traits)) {
		push @out, $obs{$trial_id}->{$accession}->{$plot}->{$trait};
	    }
	    print join("\t", @out)."\n";
	}
    }
}
    

#print STDERR "spreadsheet : ". Dumper(\@spreadsheet);	
