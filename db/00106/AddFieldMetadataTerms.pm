#!/usr/bin/env perl


=head1 NAME

 AddFieldMetadataTerms.pm

=head1 SYNOPSIS

mx-run AddFieldMetadataTerms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds the following terms to the projectproperties cv:

=over 10

=item *

plants_per_plot

=item * 

plant_spacing

=item * 

inter_row_spacing

=item * 

interplot_spacing

=back

Note: plants_per_plot is a field metadata for trials that have or don't have plant-level phenotyping activated. If there are plant entries in the database, the configuration parameter project_has_plant_entries is treated as a flag.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddFieldMetadataTerms;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

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

    print STDERR "INSERTING CV TERMS...\n";
    
    my @terms = qw | plants_per_plot plant_spacing inter_row_spacing inter_plot_spacing  | ;

    foreach my $t (@terms) { 

        $self->dbh->do(<<EOSQL);
INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), '$t');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT cv_id FROM cv where name='project_property' ), '$t', '$t', (SELECT dbxref_id FROM dbxref WHERE accession='$t'));

EOSQL

}

    print "You're done!\n";
}


####
1; #
####
