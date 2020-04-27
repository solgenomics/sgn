#!/usr/bin/env perl


=head1 NAME

 UpdateCoPrefix.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates the cassava_trait db name from the generic CO prefix to the crop ontology CO_334 prefix


This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateCoPrefix;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Update cassava_trait db prefix

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

    my $db_rs = $schema->resultset("General::Db")->search( 
	{
	    'cv.name' => "cassava_trait" ,
	},
	{ join => { 'dbxrefs' => { 'cvterm' => 'cv' } }},
	);
    if ($db_rs) {
	my $db = $db_rs->first;
	my $db_name = $db->name;
	print STDERR "db name = $db_name \n";
	if ($db_name eq "CO") {
	    $db->name("CO_334");
	    $db->update();
	    print STDERR "db name is now " . $db->name() . "\n";
	}
    }
    print "You're done!\n";
}


####
1; #
####
