#!/usr/bin/env perl


=head1 NAME

RemoveValueRulesFromStatisticTraits.pm

=head1 SYNOPSIS

mx-run RemoveValueRulesFromStatisticTraits [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Post-composed traits copy the properties of their component trait. For a trait
composed with a statistical term (SGNSTAT, e.g. "gy|Adjusted means from BLUPs")
that copied its value rules too: format, categories, minimum, maximum and
default value. The values of these traits are computed by an analysis, are
continuous and can be outside the scale of the measured trait (a BLUP can be
negative, the mean of a 1-9 score is not one of the categories), so storing an
analysis failed the trait checks.

This patch removes those value rules from the existing traits composed with a
SGNSTAT term. Other properties (trait details, comments) are kept.
CXGN::Onto::store_composed_term no longer copies them for new terms.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package RemoveValueRulesFromStatisticTraits;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Removes the value rules (format, categories, minimum, maximum, default) copied from the measured trait to traits post-composed with a statistical (SGNSTAT) term

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

    my $deleted = $self->dbh->do(<<'SQL');
DELETE FROM cvtermprop p
 USING cvterm prop_type
 WHERE prop_type.cvterm_id = p.type_id
   AND prop_type.name IN ('trait_format', 'trait_categories', 'trait_minimum', 'trait_maximum', 'trait_default_value')
   AND EXISTS (
       SELECT 1
         FROM cvterm_relationship r
         JOIN cvterm component ON component.cvterm_id = r.subject_id
         JOIN dbxref x ON x.dbxref_id = component.dbxref_id
         JOIN db ON db.db_id = x.db_id
        WHERE r.object_id = p.cvterm_id
          AND db.name = 'SGNSTAT'
   )
SQL

    print STDOUT "Removed " . ($deleted + 0) . " value rule(s) from traits composed with a statistical term.\n";

    print "You're done!\n";
}


####
1; #
####
