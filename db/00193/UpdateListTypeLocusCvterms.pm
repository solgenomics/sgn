#!/usr/bin/env perl

=head1 NAME

 UpdateListTypeLocusCvterms.pm

=head1 SYNOPSIS

mx-run UpdateListTypeLocusCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds locus name list type.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Clay Birkett<clb343@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateListTypeLocusCvterms;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';



has '+description' => ( default => <<'' );
This patch adds locus and locus_alleles list type

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

    my $terms = {
        'list_types' => [
            'locus',
	    ],
    };

    foreach my $t (keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $_,
                cv => $t
            });
        }
    }

    print "You're done!\n";
}


####
1; #
####
