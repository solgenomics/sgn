=head1 NAME

convert_treatment_projects_to_phenotypes.pl - a script to take deprecated treatment/field_management_factor projects and turn them into treatment observations. Treatment projects will be deleted, and any treatments that are seen will be added to the treatment ontology.

=head1 SYNOPSIS

perl convert_treatment_projects_to_phenotypes.pl -H dbhost -D dbname -U user -P password

=over 4

=item -H

The host of the database.

=item -D

The name of the database. 

=item -U

The user executing this action (postgres by default)

=item -P

The database password.

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
use CXGN::DB::InsertDBH;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Phenotype;

our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_t);

getopts('H:D:U:P:t')
    or pod2usage();

my $dbh = CXGN::DB::InsertDBH->new({
	 dbname => $opt_D,
	 dbhost => $opt_H,
	#  dbuser => $opt_U,
	#  dbpass => $opt_P,
	 dbargs => {AutoCommit => 0,
		    RaiseError => 1},
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

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

my $update_new_treatment_sql = "UPDATE cvterm 
	SET definition = \'Legacy treatment from BreedBase before sgn-416.0 release. Binary value for treatment was/was not applied.\'
	WHERE cvterm_id IN (SELECT unnest(string_to_array(?, ',')::int[]));";

my $h = $schema->storage->dbh->prepare($all_trials_q);
$h->execute();

my @new_treatment_cvterms = ();

while(my ($trial_id, $trial_name) = $h->fetchrow_array()) {
	my $trial = CXGN::Trial->new({
		bcs_schema => $schema,
		trial_id => $trial_id
	});
	my $treatment_trials = $trial->get_treatment_projects();
	foreach my $treatment_trial (@{$treatment_trials}) {
		my $treatment_trial_name = $treatment_trial->[1];
		my $treatment_trial_id = $treatment_trial->[0];
		print STDERR "Found a treatment trial with ID $treatment_trial_id \n";
		$treatment_trial = CXGN::Trial->new({
			bcs_schema => $schema,
			trial_id => $treatment_trial->[0]
		});
		my $observation_units = $treatment_trial->get_plots();
		my $treatment_name = $treatment_trial_name =~ s/$trial_name(_)//r;
		$treatment_name =~ s/_/ /g;
		my $new_treatment_id;
		eval {
			$new_treatment_id = $schema->resultset("Cv::Cvterm")->create_with({
				name => $treatment_name,
				cv => 'treatment',
				db => 'TREATMENT'
			})->cvterm_id();
		};
		if ($@) {
			die "An error occurred trying to create a new treatment! $@\n";
		}
		push @new_treatment_cvterms, $new_treatment_id;
		my $trial_date = $trial->get_create_date();
		foreach my $obs_unit (@{$observation_units}){
			my $stock_name = $obs_unit->[1];
			eval {
				my $phenotype = CXGN::Phenotype->new({
					schema => $schema,
					cvterm_id => $new_treatment_id,
					value => 1,
					stock_id => $obs_unit->[0],
					observationunit_id => $obs_unit->[0],
					uniquename => "Stock: $stock_name, trait: $treatment_name date: $trial_date operator = $opt_U",
					collect_date => $trial_date,
					operator => $opt_U,
					nd_experiment_id => $trial->get_nd_experiment_id()->{nd_experiment_id}
				});
				$phenotype->store();
			};
			if ($@) {
				die "An error occurred trying to store new phenotype! $@\n";
			}
		}
		$trial->remove_treatment_project($treatment_trial_id);
	}
}

$h = $schema->storage->dbh->prepare($update_new_treatment_sql);
$h->execute(join(",", @new_treatment_cvterms));

if ($opt_t) {
	print STDERR "Test mode. Changes not committed.\n";
	$schema->txn_rollback();
} else {
	$schema->txn_commit();
}

print STDERR "Done!\n";
1;