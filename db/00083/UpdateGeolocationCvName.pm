#!/usr/bin/env perl


=head1 NAME

 UpdateGeolocationCvName.pm

=head1 SYNOPSIS

mx-run UpdateGeolocationCvName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates the geolocation property cvname to the chado default of 'geolocations_property'
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateGeolocationCvName;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
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

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $plural_row = $schema->resultset("Cv::Cv")->find( { name => 'geolocations_property' } );
    my $singular_row = $schema->resultset("Cv::Cv")->find( { name => 'geolocation_property' } );

    if (defined $plural_row && defined $singular_row) {
        my $old_id = $plural_row->cv_id();
        my $new_id = $singular_row->cv_id();
        my $rows_to_update = $schema->resultset("Cv::Cvterm")->search( { cv_id => $old_id } );
        foreach my $row ($rows_to_update->all()) {
            $row->cv_id($new_id);
            $row->update();
        }
        $plural_row->delete();
    }
    elsif (defined $plural_row) {
        print STDOUT "Fixing cv name...\n";
        $plural_row->name('geolocation_property');
        $plural_row->update();
    }
    elsif (defined $singular_row) {
        print STDOUT "Cv name is already correct, no changes necessary.\n";
    }
    else {
        print STDOUT "No geolocation property cv found. Run patch 00076/AddBrAPIPropertyCvterms.pm to add geolocation props.\n";
    }

    print "You're done!\n";
}


####
1; #
####
