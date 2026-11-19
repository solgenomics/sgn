#!/usr/bin/env perl


=head1 NAME

FixJobTypeIds.pm

=head1 SYNOPSIS

mx-run FixJobTypeIds [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

CXGN::Job created a missing job type with create_with({ cv_id => ... }),
which ignores cv_id: the term went to the 'null' cv instead of 'job_type', so
it was never found again and every job of that type (e.g. the Analysis
Pipeline's script_factory_analysis) was stored without a type (empty Type in
the job list). This patch moves those terms to the 'job_type' cv and sets the
type of the jobs stored without one.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixJobTypeIds;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Moves job types created in the 'null' cv to the 'job_type' cv and sets the type of jobs stored without one

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

    $self->dbh->do(<<EOSQL);
INSERT INTO cv (name) SELECT 'job_type' WHERE NOT EXISTS (SELECT 1 FROM cv WHERE name = 'job_type');

-- job types autocreated in the 'null' cv (only names used as job types)
UPDATE cvterm c SET cv_id = jt.cv_id
  FROM cv n, cv jt, dbxref x
 WHERE n.name = 'null' AND jt.name = 'job_type'
   AND c.cv_id = n.cv_id AND x.dbxref_id = c.dbxref_id AND x.accession = 'autocreated:' || c.name
   AND c.name IN (SELECT args->>'job_type' FROM sgn_people.sp_job WHERE args->>'job_type' IS NOT NULL
                  UNION SELECT 'script_factory_analysis')
   AND NOT EXISTS (SELECT 1 FROM cvterm o WHERE o.cv_id = jt.cv_id AND o.name = c.name);

-- Analysis Pipeline jobs stored without a type (their args have no job_type either)
UPDATE sgn_people.sp_job j
   SET type_id = c.cvterm_id,
       args = j.args || jsonb_build_object('job_type', c.name)
  FROM cvterm c JOIN cv ON cv.cv_id = c.cv_id AND cv.name = 'job_type'
 WHERE c.name = 'script_factory_analysis' AND j.type_id IS NULL
   AND (j.args->>'results_page' LIKE '/tools/script_factory%' OR j.args->>'cmd' LIKE '%script_factory%');

-- other jobs stored without a type whose args name it
UPDATE sgn_people.sp_job j
   SET type_id = c.cvterm_id
  FROM cvterm c JOIN cv ON cv.cv_id = c.cv_id AND cv.name = 'job_type'
 WHERE j.type_id IS NULL AND c.name = j.args->>'job_type';
EOSQL

    print "You're done!\n";
}


####
1; #
####
