#!/usr/bin/env perl


=head1 NAME

FixTrialTypes.pm

=head1 SYNOPSIS

mx-run FixTrialTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the list of possible trial types by removing duplicates, standardizing names, and assigning types to trials where it can be deduced from the trial name.

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixTrialTypes;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the list of possible trial types by removing duplicates, standardizing names, and assigning types to trials where it can be deduced from the trial name.


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
      my $cv_rs = $schema->resultset("Cv::Cv");
      my $cvterm_rs = $schema->resultset("Cv::Cvterm");
      my $projectprop_rs = $schema->resultset("Project::Projectprop");

      my $project_type_cv_row = $cv_rs->search( { name => 'project_type' } );
      my $cv_id = $project_type_cv_row->cv_id;

      my $SN_id = update_or_create_type('%seedling%', 'Seedling Nursery', $cvterm_rs, $cv_id);
      my $CE_id = update_or_create_type('%clonal%', 'Clonal Evaluation', $cvterm_rs, $cv_id);
      my $PYT_id = find_or_update_type ('PYT', 'Preliminary Yield Trial', $cvterm_rs, $cv_id)


    link_to_new_type('PYT', $new_type_id, $cv_id, $projectprop_rs);
    link_to_new_type('Preliminary Yield Trials', $new_type_id, $cv_id, $projectprop_rs);
    delete_old_type('PYT');
    delete_old_type('Preliminary Yield Trials');


    sub update_or_create_type ($duplicate_type_name, $new_type_name, $cvterm_rs, $cv_id) {
      my $duplicate_rs = $cvterm_rs->find(
        {
          cv_id => $cv_id,
          name => $duplicate_type_name
        });
      if ($duplicate_rs) {
        $duplicate_rs->first->update( { name => $new_type_name }, );
      } else {
        my $new_rs = $cvterm_rs->create_with(
		      {
            cv_id => $cv_id,
		        name => $new_type_name
		      });
      }
      return $new_rs->cvterm_id;
    }

    sub find_or_update_type ($duplicate_type_name, $type_name, $cvterm_rs, $cv_id) {
      my $type_rs = $cvterm_rs->find(
        {
          cv_id => $cv_id,
          name => $type_name
        });
      if (!$type_rs) {
        $type_rs = $cvterm_rs->find(
          {
            cv_id => $cv_id,
            name => $duplicate_type_name
          });
        $type_rs->first->update( { name => $type_name }, );
      }
      return $type_rs->cvterm_id;
    }

    sub update_project_type ($old_type_name, $new_type_id, $cv_id, $projectprop_rs) {
      my $duplicate_rs = $cvterm_rs->find(
        {
          cv_id => $cv_id,
          name => $old_type_name
        });
      my $duplicate_cvterm_id = $duplicate_rs->cvterm_id;

      my $trials_to_update_rs = $projectprop_rs->search(
        {
          type_id => $duplicate_cvterm_id
        });
      foreach my $row (@$trials_to_update_rs) {
        $row->update( { type_id => $new_type_id } );
      }
    }

    sub delete_old_type ($old_type_name) {

    }

    $self->dbh->do(<<EOSQL);

--do your SQL here

# find or create new standaradized trial_type (ex. Preliminary Yield Trial) , save it's cvterm_ids
# find any duplicates present and save their cvterm_ids
# update all rows with old ids in project prop table to new ids and new values
# confirm those ids are no longer in the projectproptable, then delete them from cvterm.
# Find all trials without a type assigned. Use regex to match and assign a type if the trial has a type or type abbreviation in its name

--
EOSQL

print "You're done!\n";
}


####
1; #
####
