#!/usr/bin/env perl


=head1 NAME

 UnderlineExpCvterms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This path adds underline to breeder toolbox cv names that are used with a space in their name instead of an underline. This patch goes along with code updates since some cv names are (were)  hardcoded 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UnderlineExpCvterms;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will add underline to the cvterm names with experiment_type cv 
field_layout
phenotyping_experiment
genotyping_layout
genotyping_experiment
this is important for making CVterms uniform and less room for errors when using these

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
--do your SQL here
--
UPDATE cvterm SET name = 'field_layout' WHERE name = 'field layout';
UPDATE cvterm SET name = 'genotyping_experiment' WHERE name = 'genotyping experiment';
UPDATE cvterm SET name = 'genotyping_layout' WHERE name = 'genotyping layout';
UPDATE cvterm SET name = 'phenotyping_experiment' WHERE name = 'phenotyping experiment';

EOSQL

print "You're done!\n";
}


####
1; #
####
