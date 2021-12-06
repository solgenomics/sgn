#!/usr/bin/env perl


=head1 NAME

 AddSpProductProfilePropertyCv

=head1 SYNOPSIS

mx-run AddSpProductProfilePropertyCv[options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds sp_product_profile_property cv and update product_profile_json cvterm
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSpProductProfilePropertyCv;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the 'sp_product_profile_property' cv and updates 'product_profile_json' cvterm

has '+prereq' => (
	default => sub {
        ['AddProductProfileCvterm'],
    },

);

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    my $cv_rs = $schema->resultset("Cv::Cv");
    my $cvterm_rs = $schema->resultset("Cv::Cvterm");

    print STDERR "CREATING CV...\n";
    my $cv = $cv_rs->find_or_create({ name => 'sp_product_profile_property' });

    print STDERR "UPDATING CVTERM...\n";

	my $product_profile_json_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'product_profile_json', 'project_property');
    my $product_profile_cv = $schema->resultset("Cv::Cv")->find({ name => 'sp_product_profile_property' });

    $product_profile_json_cvterm->update( { cv_id => $product_profile_cv->cv_id  } );


    print "You're done!\n";
}


####
1; #
####
