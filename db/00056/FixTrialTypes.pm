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
  my $cvterm_rs = $schema->resultset("Cv::Cvterm");
  my $cv_rs = $schema->resultset("Cv::Cv");

  my $nd_experiment_property_cv = $cv_rs->find_or_create( { name => 'nd_experiment_property' });

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
