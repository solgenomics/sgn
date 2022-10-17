#!/usr/bin/env perl

=head1 NAME

AddGenomicPredictionStatCvterms.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds genomic prediction analysis statistics cvterms.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Isaak Y Tecle<iyt2@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddGenomicPredictionStatCvterms;

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


    print STDERR "INSERTING Genomic Prediction statistics TERMS...\n";
    my $dbhost = $self->dbhost;
    my $dbname = $self->dbname;

    `perl ~/cxgn/chado_tools/chado/bin/gmod_load_cvterms.pl -H $dbhost -D $dbname -r postgres  -s SGNSTAT -d Pg  ~/cxgn/sgn/ontology/cxgn_statistics.obo`;

    print "\nYou're done!\n\n";

}


####
1; #
####
