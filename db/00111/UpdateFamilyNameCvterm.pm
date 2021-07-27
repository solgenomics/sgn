#!/usr/bin/env perl


=head1 NAME

 UpdateFamilyNameCvterm.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates the cvterm family_name by changing from cv = stock_property to cv = stock_type.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Titima Tantikanjana<tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateFamilyNameCvterm;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';



has '+description' => ( default => <<'' );
This patch updates the cvterm family_name by changing from cv = stock_property to cv = stock_type.

has '+prereq' => (
	default => sub {
        ['AddFamilyNameCvterm'],
    },

  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );



    my $family_name_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_property');
    my $stock_type_cv = $schema->resultset("Cv::Cv")->find({ name => 'stock_type' });

    $family_name_cvterm->update( { cv_id => $stock_type_cv->cv_id  } );

    print "You're done!\n";
}


####
1; #
####
