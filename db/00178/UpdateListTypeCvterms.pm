#!/usr/bin/env perl

=head1 NAME

 UpdateListTypeCvterms.pm

=head1 SYNOPSIS

mx-run UpdateListTypeCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch changes the cvterm name genotyping_trials to genotyping_plates and adds crossing_experiments, genotyping_projects list types.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Titima Tantikanjana<tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateListTypeCvterms;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';



has '+description' => ( default => <<'' );
This patch changes the cvterms name from genotyping_trials to genotyping_plates and adds crossing_experiments, genotyping_projects list types

has '+prereq' => (
	default => sub {
        ['AddGenotypingTrialListCvterm'],
    },

  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $genotyping_trials_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_trials', 'list_types');

    $genotyping_trials_cvterm->update( { name => 'genotyping_plates'  } );

    my $terms = {
        'list_types' => [
            'crossing_experiments',
            'genotyping_projects',
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
