#!/usr/bin/env perl


=head1 NAME

MakeTreatmentOntologyTraits.pm

=head1 SYNOPSIS

mx-run MakeTreatmentOntologyTraits [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch changes the treatment ontology to also be a trait ontology.

=head1 AUTHOR

Chris Tucker

=head1 COPYRIGHT & LICENSE

Copyright 2026 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package MakeTreatmentOntologyTraits;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch changes the treatment ontology to also be a trait ontology.


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
insert into cvprop (cv_id, type_id)
select cv.cv_id, cvterm.cvterm_id
from cv join cvterm on (cvterm.name = 'trait_ontology')
where cv.name = 'experiment_treatment';

EOSQL

    print "You're done!\n";
}


####
1; #
####
