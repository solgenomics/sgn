#!/usr/bin/env perl


=head1 NAME

CreateTreatmentCV.pm

=head1 SYNOPSIS

mx-run CreateTreatmentCV [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateExperimentTreatmentCV;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Phenotype;

has '+description' => ( default => <<'' );
Creates a controlled vocabulary for experimental treatments. Paired with an ontology that tracks experimental treatments like traits. 

has '+prereq' => (
    default => sub {
        [ ],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
        
    print STDERR "INSERTING CV TERMS...\n";

    my $check_treatment_cv_exists = "SELECT cv_id FROM cv WHERE name='experiment_treatment'";
    
    my $h = $schema->storage->dbh()->prepare($check_treatment_cv_exists);
    $h->execute();

    my $row = $h->fetchrow_array();

    if (defined($row)) {
        print STDERR "Patch already run\n";
    } else {
        my $insert_treatment_cv = "INSERT INTO cv (name, definition) 
        VALUES ('experiment_treatment', 'Experimental treatments applied to some of the stocks in a project. Distinct from management factors/management regimes.');";

        $schema->storage->dbh()->do($insert_treatment_cv);

        my $h = $schema->storage->dbh()->prepare($check_treatment_cv_exists);
        $h->execute();

        my $treatment_cv_id = $h->fetchrow_array();

        my $terms = { 
        'composable_cvtypes' => 
            [
             "experiment_treatment_ontology",
            ],
        };

        my $treatment_ontology_cvterm_id;

        foreach my $t (sort keys %$terms){
            foreach (@{$terms->{$t}}){
                $treatment_ontology_cvterm_id = $schema->resultset("Cv::Cvterm")->create_with(
                    {
                        name => $_,
                        cv => $t
                    })->cvterm_id();
            }
        }

        $schema->resultset("Cv::Cvprop")->create({
            cv_id   => $treatment_cv_id,
            type_id => $treatment_ontology_cvterm_id
        });

        my $experiment_treatment_root_id = $schema->resultset("Cv::Cvterm")->create_with({
				name => 'Experimental treatment ontology',
				cv => 'experiment_treatment',
				db => 'EXPERIMENT_TREATMENT',
				dbxref => '0000000'
		})->cvterm_id();

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

        $h = $schema->storage->dbh->prepare($all_trials_q);
        $h->execute();

        my %new_treatment_cvterms = ();
        my $dbxref_id = 0;

        while(my ($trial_id, $trial_name) = $h->fetchrow_array()) {
            my $trial = CXGN::Trial->new({
                bcs_schema => $schema,
                trial_id => $trial_id
            });
            my $parent_observation_units = $trial->get_plots();
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
                my %observation_units_lookup = map {$_->[0] => 1} @{$observation_units};
                my $treatment_name = $treatment_trial_name =~ s/$trial_name(_)//r;
                $treatment_name =~ s/_/ /g;
                $treatment_name = lc($treatment_name);
                my $treatment_id;
                if (!exists($new_treatment_cvterms{$treatment_name})) {
                    $dbxref_id++;
                    my $zeroes = "0" x (7-length($dbxref_id));
                    eval {
                        $treatment_id = $schema->resultset("Cv::Cvterm")->create_with({
                            name => $treatment_name,
                            cv => 'experiment_treatment',
                            db => 'EXPERIMENT_TREATMENT',
                            dbxref => "$zeroes"."$dbxref_id"
                        })->cvterm_id();
                        $new_treatment_cvterms{$treatment_name} = $treatment_id;
                        my $variable_of_id = 
                        $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                            subject_id => $experiment_treatment_root_id,
                            object_id => $treatment_id,
                            type_id => $variable_id
                        });
                    };
                    if ($@) {
                        die "An error occurred trying to create a new treatment! $@\n";
                    }
                } else {
                    $treatment_id = $new_treatment_cvterms{$treatment_name};
                }
                my $trial_date = $trial->get_create_date() =~ s/ /_/r;
                foreach my $obs_unit (@{$parent_observation_units}){
                    my $stock_name = $obs_unit->[1];
                    eval {
                        my $phenotype = CXGN::Phenotype->new({
                            schema => $schema,
                            cvterm_id => $treatment_id,
                            value => exists($observation_units_lookup{$obs_unit->[0]}) ? 1 : 0,
                            stock_id => $obs_unit->[0],
                            observationunit_id => $obs_unit->[0],
                            uniquename => "Stock: $stock_name, trait: $treatment_name date: $trial_date operator = ".$self->username,
                            collect_date => $trial_date,
                            operator => $self->username,
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
        $h->execute(join(",", values(%new_treatment_cvterms)));
    }
    print STDERR "Patch complete\n";
}


####
1; #
####
