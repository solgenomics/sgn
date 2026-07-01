#!/usr/bin/env perl

=head1 NAME

 AddExperimentMeetingCvterms

=head1 SYNOPSIS

mx-run AddExperimentMeetingCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds:
- the cv 'experiment_meeting'
- the cvterm 'meeting_project' in cv 'experiment_meeting'
- the cvterm 'meeting_json' in cv 'project_property'

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Chris Simoes

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddExperimentMeetingCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds the cv 'experiment_meeting', the cvterm 'meeting_project' in cv 'experiment_meeting', and the cvterm 'meeting_json' in cv 'project_property'

has '+prereq' => (
    default => sub {
        [],
    },
);

sub patch {
    my $self = shift;

    print STDOUT "Executing the patch:\n " . $self->name . ".\n\nDescription:\n  " . $self->description . ".\n\nExecuted by:\n " . $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";
    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDERR "INSERTING CVS AND CV TERMS...\n";

    my $cv_name = 'experiment_meeting';

    my $cv = $schema->resultset('Cv::Cv')->find({ name => $cv_name });
    if (!$cv) {
        $cv = $schema->resultset('Cv::Cv')->create({ name => $cv_name });
        print STDERR "Created cv '$cv_name'\n";
    }
    else {
        print STDERR "cv '$cv_name' already exists\n";
    }

    my $meeting_project = $schema->resultset('Cv::Cvterm')->find({
        name  => 'meeting_project',
        cv_id => $cv->cv_id
    });

    if (!$meeting_project) {
        $schema->resultset('Cv::Cvterm')->create_with({
            name => 'meeting_project',
            cv   => $cv_name
        });
        print STDERR "Created cvterm 'meeting_project' in cv '$cv_name'\n";
    }
    else {
        print STDERR "cvterm 'meeting_project' already exists in cv '$cv_name'\n";
    }

    my $project_property_cv = $schema->resultset('Cv::Cv')->find({ name => 'project_property' });
    die "cv 'project_property' does not exist\n" unless $project_property_cv;

    my $meeting_json = $schema->resultset('Cv::Cvterm')->find({
        name  => 'meeting_json',
        cv_id => $project_property_cv->cv_id
    });

    if (!$meeting_json) {
        $schema->resultset('Cv::Cvterm')->create_with({
            name => 'meeting_json',
            cv   => 'project_property'
        });
        print STDERR "Created cvterm 'meeting_json' in cv 'project_property'\n";
    }
    else {
        print STDERR "cvterm 'meeting_json' already exists in cv 'project_property'\n";
    }

    print "You're done!\n";
}

####
1; #
####