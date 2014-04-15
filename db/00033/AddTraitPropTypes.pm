#!/usr/bin/env perl


=head1 NAME

 AddTraitPropTypes.pm

=head1 SYNOPSIS

mx-run AddTraitPropTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds a cv for trait_properties).
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

  Jeremy D. Edwards <jde22@cornell.edu>
  Naama Menda <nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddTraitPropTypes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

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

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

INSERT INTO cv (name, definition) VALUES ('trait_property', '');

EOSQL
    
    print STDERR "INSERTING CV TERMS...\n";
    
    my @terms = qw(
		    trait_format
		    trait_default_value
		    trait_minimum
		    trait_maximum
		    trait_details
		    trait_categories
		 );

    foreach my $t (@terms) { 

	$self->dbh->do(<<EOSQL);
INSERT INTO dbxref (db_id, accession) VALUES ((SELECT db_id FROM db WHERE name='local'), '$t');

INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES ( (SELECT currval('cv_cv_id_seq')), '$t', '$t', (SELECT dbxref_id FROM dbxref WHERE accession='$t'));


EOSQL

}

print "Done!\n";

}

####
1; #
####
