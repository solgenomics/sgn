#!/usr/bin/env perl

=head1 NAME

AddAccessionsAndObsoletedAccessionsListTypesCvterm

=head1 SYNOPSIS

mx-run  AddAccessionsAndObsoletedAccessionsListTypesCvterm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds accessions_and_obsoleted_accessions list types cvterm
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddAccessionsAndObsoletedAccessionsListTypesCvterm;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds the 'accessions_and_obsoleted_accessions' list_types cvterm

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

    print STDERR "INSERTING CV TERMS...\n";

    $schema->resultset("Cv::Cvterm")->create_with({
        name => 'accessions_and_obsoleted_accessions',
        cv => 'list_types'
    });

    print "You're done!\n";
}


####
1; #
####
