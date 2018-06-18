#!/usr/bin/env perl


=head1 NAME

 AddPlants.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds plants to test_trial in fixture.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Titima Tantikanjana<tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddPlants;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use CXGN::Trial;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds plants to test_trial.

has '+prereq' => (
    default => sub {
        ['MyPrevPatch'],
    },
  );

sub patch {
    my $self = shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        my $trial_id = '137'
        my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id});
        my $number_of_plants = 2;

        $trial->create_plant_entries($number_of_plants);

    };

    try {
        $schema->txn_do($coderef);
    } catch {
        die "Patch failed! Transaction exited." .$_. "\n";
    };

    print "You're done!\n";
}


####
1; #
####
