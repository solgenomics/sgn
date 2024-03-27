
=head1 NAME

download_trials.pl - script to download trials

=head1 DESCRIPTION

perl download_trials.pl -i trial_id -H host -D dbname -U dbuser -P dbpass

Downloads trials whose ids are provided as a comma separated list for the -i parameter.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Data::Dumper;

use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Trial;
use CXGN::Dataset;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_b, $opt_i, $opt_n, $opt_t, $opt_r);

getopts('H:D:U:P:b:i:t:r:ny:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $trial_ids = $opt_i;
my $years = $opt_y;
my $breeding_programs = $opt_b;
my $trial_names = $opt_t;
my $non_interactive = $opt_n;


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
my $people_schema = CXGN::Schema::People->connect( sub { $dbh->get_actual_dbh()});

my @trial_ids;
my @trial_names;

if ($opt_i || $opt_n) { 
    @trial_ids = split ",", $trial_ids;
    @trial_names = split ",", $trial_names;

}

if ($opt_b && $opt_y) {
    my @years = split /\,/, $opt_y;
    my @breeding_program_names = split/\,/, $breeding_programs;

    my @breeding_program_ids;
    my $rs = $schema->resultset('Project::Project')->search( { name => [ @breeding_program_names ] });

    while (my $bp_row = $rs->next()) {
	push @breeding_program_ids, $rs->project_id();
    }
    
    my $ds = CXGN::Dataset->new( { schema => $schema, people_schema => $people_schema });

    $ds->years(\@years);
    $ds->breeding_programs(\@breeding_programs);

    my $trials = $ds->retrieve_trials();

    foreach my $t (@$trials) {
	push @trials_ids, $t->[0];
	push @trials_names, $t->[1];
    }
    
}
    

foreach my $name (@trial_names) { 
    my $trial = $schema->resultset("Project::Project")->find( { name => $name });
    if (!$trial) { print STDERR "Trial $name not found. Skipping...\n"; next; }
    push @trial_ids, $trial->project_id();
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
