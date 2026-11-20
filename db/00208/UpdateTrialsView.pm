#!/usr/bin/env perl


=head1 NAME

  UpdateTrialsView

=head1 SYNOPSIS

mx-run UpdateTrialsView [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateTrialsView;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This updates the trials view to better filter out non-trial projects

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";


    $self->dbh()->do( <<EOSQL);
--do your SQL here
--
DROP VIEW IF EXISTS public.trials;
CREATE VIEW public.trials AS
SELECT trial.project_id AS trial_id,
    trial.name AS trial_name
   FROM project breeding_program
   JOIN project_relationship ON(breeding_program.project_id = object_project_id AND project_relationship.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program_trial_relationship'))
   JOIN project trial ON(subject_project_id = trial.project_id)
   JOIN projectprop on(trial.project_id = projectprop.project_id)
   WHERE projectprop.type_id = (
      SELECT cvterm_id FROM cvterm WHERE name = 'design' AND cv_id = (
        SELECT cv_id FROM cv WHERE name = 'project_property'
      )
   ) AND projectprop.value NOT IN ('treatment', 'genotyping_data_project', 'pcr_genotype_data_project', 'genotyping_plate', 'drone_run', 'drone_run_band', 'Meeting')
   GROUP BY trial.project_id, trial.name;
ALTER VIEW trials OWNER TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
