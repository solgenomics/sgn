#!/usr/bin/env perl


=head1 NAME

CreateTreatmentCV.pm

=head1 SYNOPSIS

mx-run CreateTreatmentCV [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateTreatmentCV;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

has '+description' => ( default => <<'' );
Creates a controlled vocabulary for treatments. Paired with an ontology that tracks treatments like traits. 

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

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
        
    print STDERR "INSERTING CV TERMS...\n";

    my $check_treatment_cv_exists = "SELECT cv_id FROM cv WHERE name='treatment'";
    
    my $h = $schema->storage->dbh()->prepare($check_treatment_cv_exists);
    $h->execute();

    my $row = $h->fetchrow_array();

    if (defined($row)) {
        print STDERR "Patch already run\n";
    } else {
        my $insert_treatment_cv = "INSERT INTO cv (name, definition) 
        VALUES ('treatment', 'Experimental treatments applied to some of the stocks in a project. Distinct from management factors/management regimes.');";

        $schema->storage->dbh()->do($insert_treatment_cv);

        my $h = $schema->storage->dbh()->prepare($check_treatment_cv_exists);
        $h->execute();

        my $treatment_cv_id = $h->fetchrow_array();

        # need to create the treatment_ontology cvterm as well, of cv composable_cvtypes

        my $insert_treatment_cvprop = "INSERT INTO cvprop ()";
    }

    print STDERR "Patch complete\n";
}


####
1; #
####
