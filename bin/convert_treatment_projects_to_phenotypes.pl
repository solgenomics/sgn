=head1 NAME

convert_treatment_projects_to_phenotypes.pl - a script to take deprecated treatment/field_management_factor projects and turn them into treatment observations. Treatment projects will be deleted, and any treatments that are seen will be added to the experiment_treatment ontology.

=head1 SYNOPSIS

perl convert_treatment_projects_to_phenotypes.pl -H dbhost -D dbname -U user -P password -e username -t

=over 4

=item -H

The host of the database.

=item -D

The name of the database. 

=item -U

The user executing this action (postgres by default)

=item -P

The database password.

=item -e

The signing user. Must be a user in the database.

=item -t

Test mode. Changes not committed.

=back

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;

use Getopt::Std;
use Pod::Usage;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::People::Person;
use CXGN::DB::InsertDBH;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Phenotypes::StorePhenotypes;
use DateTime;
use Cwd;
use File::Temp qw/tempfile/;
use List::Util qw/max/;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_e, $opt_t);

if (!$opt_U){
	$opt_U = "postgres";
}

getopts('H:D:U:P:e:t')
    or pod2usage();

my $dbh = CXGN::DB::InsertDBH->new({
	dbname => $opt_D,
	dbhost => $opt_H,
	dbuser => $opt_U,
	dbpass => $opt_P,
	dbargs => {
		AutoCommit => 0,
		RaiseError => 1
	},
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $metadata_schema = CXGN::Metadata::Schema->connect( 
        sub { $dbh->get_actual_dbh() }, 
        { on_connect_do => ['SET search_path TO public,metadata;'] }
    );
my $phenome_schema = CXGN::Phenome::Schema->connect( 
	sub { $dbh->get_actual_dbh() },
	{ on_connect_do => ['SET search_path TO public,phenome;'] }
);
my $site_basedir = getcwd()."/..";
my $temp_basedir_key = `cat $site_basedir/sgn.conf $site_basedir/sgn_local.conf | grep tempfiles_subdir`;
my (undef, $temp_basedir) = split(/\s+/, $temp_basedir_key);
$temp_basedir = "$site_basedir/$temp_basedir";
if (! -d "$temp_basedir/delete_nd_experiment_ids/"){
	mkdir("$temp_basedir/delete_nd_experiment_ids/");
}
my $signing_user_id = CXGN::People::Person->get_person_by_username($dbh, $opt_e); #not the db user, but the name attached as operator of new phenotypes

#definition of trials view
my $all_trials_q = "SELECT trial.project_id AS trial_id, trial.name as trial_name                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
    FROM (((project breeding_program                                                                                                                                                                                                                                                  
      JOIN project_relationship ON (((breeding_program.project_id = project_relationship.object_project_id) AND (project_relationship.type_id = ( SELECT cvterm.cvterm_id                                                                                                             
            FROM cvterm                                                                                                                                                                                                                                                               
           WHERE ((cvterm.name)::text = 'breeding_program_trial_relationship'::text))))))                                                                                                                                                                                             
      JOIN project trial ON ((project_relationship.subject_project_id = trial.project_id)))                                                                                                                                                                                           
      JOIN projectprop ON ((trial.project_id = projectprop.project_id)))                                                                                                                                                                                                              
   WHERE (NOT (projectprop.type_id IN ( SELECT cvterm.cvterm_id                                                                                                                                                                                                                       
            FROM cvterm                                                                                                                                                                                                                                                               
           WHERE (((cvterm.name)::text = 'cross'::text) OR ((cvterm.name)::text = 'trial_folder'::text) OR ((cvterm.name)::text = 'folder_for_trials'::text) OR ((cvterm.name)::text = 'folder_for_crosses'::text) OR ((cvterm.name)::text = 'folder_for_genotyping_trials'::text)))))
   GROUP BY trial.project_id, trial.name;";

#Give a description to all new treatment cvterms
my $update_new_treatment_sql = "UPDATE cvterm 
	SET definition = \'Legacy treatment from BreedBase before sgn-416.0 release. Binary value for treatment was/was not applied.\'
	WHERE cvterm_id IN (SELECT unnest(string_to_array(?, ',')::int[]));";

my $relationship_cv = $schema->resultset("Cv::Cv")->find({ name => 'relationship'});
my $rel_cv_id;
if ($relationship_cv) {
	$rel_cv_id = $relationship_cv->cv_id ;
} else {
	die "No relationship ontology in DB.\n";
}
my $variable_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'VARIABLE_OF'  , cv_id => $rel_cv_id });
my $variable_id;
if ($variable_relationship) {
	$variable_id = $variable_relationship->cvterm_id();
}

my $experiment_treatment_cv = $schema->resultset("Cv::Cv")->find({ name => 'experiment_treatment'});
my $experiment_treatment_cv_id;
if ($experiment_treatment_cv) {
	$experiment_treatment_cv_id = $experiment_treatment_cv->cv_id ;
} else {
	die "No experiment_treatment CV found. Has DB patch been run?\n";
}
my $legacy_experiment_treatment = $schema->resultset("Cv::Cvterm")->find({ name => 'Legacy experiment treatment'  , cv_id => $experiment_treatment_cv_id });
my $legacy_experiment_treatment_root_id;
if ($legacy_experiment_treatment) {
	$legacy_experiment_treatment_root_id = $legacy_experiment_treatment->cvterm_id();
} else {
	die "No legacy EXPERIMENT_TREATMENT root term. Has DB patch been run?\n";
}

my $get_db_accessions_sql = "SELECT accession FROM dbxref JOIN db USING (db_id) WHERE db.name='EXPERIMENT_TREATMENT';";

my $h = $schema->storage->dbh->prepare($get_db_accessions_sql);
$h->execute();

my @accessions;

while (my $accession = $h->fetchrow_array()) {
	push @accessions, int($accession =~ s/^0+//r);
}

my $accession_start = max(@accessions) + 1;

$h = $schema->storage->dbh->prepare($all_trials_q);
$h->execute();

my %new_treatment_cvterms = (); # name => cvterm_id
my %new_treatment_full_names = (); # name => full name (with ontology)
my $dbxref_id = $accession_start;

while(my ($trial_id, $trial_name) = $h->fetchrow_array()) {

	my $trial = CXGN::Trial->new({
		bcs_schema => $schema,
		trial_id => $trial_id
	});

	my $treatment_trials = $trial->get_treatment_projects();

	next if !$treatment_trials; #skip if there are no treatment trials. Don't waste time getting plots or anything.

	my $parent_observation_units = $trial->get_plots(); #get all plots
	my @this_trial_treatments = (); # holds the full names of all treatments of this trial
	my $treatment_values_hash = {};
	my @phenotype_store_stock_list = ();

	my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

	my $has_treatments = 0;

	foreach my $treatment_trial (@{$treatment_trials}) {

		$has_treatments = 1;

		my $treatment_trial_name = $treatment_trial->[1];
		my $treatment_trial_id = $treatment_trial->[0];

		print STDERR "Found a treatment trial with ID $treatment_trial_id \n";

		$treatment_trial = CXGN::Trial->new({
			bcs_schema => $schema,
			trial_id => $treatment_trial->[0]
		});

		my $observation_units = $treatment_trial->get_plots();
		my %observation_units_lookup = map {$_->[0] => 1} @{$observation_units};

		my $treatment_name = $treatment_trial_name =~ s/$trial_name(_)//r;
		$treatment_name =~ s/_/ /g;
		$treatment_name =~ s/[^\p{Alpha} ]//g;
		$treatment_name = lc($treatment_name); #enforce no underscores and all lowercase

		my $treatment_id;
		my $treatment_full_name;

		if (!exists($new_treatment_cvterms{$treatment_name})) { #if this is a new treatment name, make new db entries and get cvterm ids
			my $zeroes = "0" x (7-length($dbxref_id));
			eval {
				$treatment_id = $schema->resultset("Cv::Cvterm")->create_with({
					name => $treatment_name,
					cv => 'experiment_treatment',
					db => 'EXPERIMENT_TREATMENT',
					dbxref => "$zeroes"."$dbxref_id"
				})->cvterm_id();

				$new_treatment_cvterms{$treatment_name} = $treatment_id;
				$treatment_full_name = "$treatment_name|EXPERIMENT_TREATMENT:$zeroes"."$dbxref_id";
				$new_treatment_full_names{$treatment_name} = $treatment_full_name;
				push @this_trial_treatments, $treatment_full_name;

				$schema->resultset("Cv::CvtermRelationship")->find_or_create({
					object_id => $legacy_experiment_treatment_root_id,
					subject_id => $treatment_id,
					type_id => $variable_id
				});
			};
			if ($@) {
				die "An error occurred trying to create a new treatment! $@\n";
			}
			$dbxref_id++;
		} else { #if not new treatment, get the treatment cvterm_id and full names
			$treatment_id = $new_treatment_cvterms{$treatment_name};
			$treatment_full_name = $new_treatment_full_names{$treatment_name};
			push @this_trial_treatments, $treatment_full_name;
		}

		foreach my $obs_unit (@{$parent_observation_units}){ #Construct the phenotype values hash
			my $plot_name = $obs_unit->[1];
			my $plot_id = $obs_unit->[0];
			my $treatment_val = exists($observation_units_lookup{$plot_id}) ? 1 : 0;

			my $plot = CXGN::Stock->new({
				schema => $schema,
				stock_id => $plot_id
			});

			$treatment_values_hash->{$plot_name}->{$treatment_full_name} = [
				$treatment_val,
				$timestamp,
				$opt_e,
				'',
				''
			];

			my $plot_contents = $plot->get_child_stocks_flat_list(); #treatment values are inherited by child stocks

			push @phenotype_store_stock_list, $plot_name;

			foreach my $child (@{$plot_contents}) {
				next if ($child->{type} eq "accession"); #dont want to assign a phenotype to an accession, that would be bad
				$treatment_values_hash->{$child->{name}}->{$treatment_full_name} = $treatment_values_hash->{$plot_name}->{$treatment_full_name};
				push @phenotype_store_stock_list, $child->{name};
			}
		}

		# $trial->remove_treatment_project($treatment_trial_id); # delete the treatment trial;
	}

	if ($has_treatments) {
		my $phenotype_metadata = { #make phenotype metadata
			archived_file => 'none',
			archived_file_type => 'treatment project conversion patch',
			operator => $opt_e,
			date => $timestamp
		};

		my (undef, $tempfile) = tempfile("$temp_basedir/delete_nd_experiment_ids/fileXXXX"); #tempfile

		my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
			basepath => $temp_basedir,
			dbhost => $opt_H,
			dbname => $opt_D,
			dbuser => $opt_U,
			dbpass => $opt_P,
			temp_file_nd_experiment_id => $tempfile,
			bcs_schema => $schema,
			metadata_schema => $metadata_schema,
			phenome_schema => $phenome_schema,
			user_id => $signing_user_id,
			stock_list => \@phenotype_store_stock_list,
			trait_list => \@this_trial_treatments,
			values_hash => $treatment_values_hash,
			metadata_hash => $phenotype_metadata
		});

		my ($verified_warning, $verified_error) = $store_phenotypes->verify();

		if ($verified_warning) {
			warn $verified_warning;
		}
		if ($verified_error) {
			die $verified_error;
		}

		my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

		if ($stored_phenotype_error) {
			die "An error occurred converting treatments: $stored_phenotype_error\n";
		}
	}
}

$h = $schema->storage->dbh->prepare($update_new_treatment_sql);
$h->execute(join(",", values(%new_treatment_cvterms)));

if ($opt_t) {
	print STDERR "Test mode. Changes not committed.\n";
	$schema->txn_rollback();
} else {
	$schema->txn_commit();
}

1;