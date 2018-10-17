#!/usr/bin/env perl


=head1 NAME

 FixTrialPluralTypes.pm

=head1 SYNOPSIS

mx-run FixTrialPluralTypes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch fixes the odd "Preliminary Yield Trials" and "Advanced Yeld Trials" and "Advanced Yield Trials" terms that should be singular terms
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixTrialPluralTypes;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch fixes the odd "Preliminary Yield Trials" and "Advanced Yeld Trials" and "Advanced Yield Trials" terms that should be singular terms

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

    my $correct_ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();
    my $correct_pyt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Preliminary Yield Trial', 'project_type')->cvterm_id();

    my $previously_saved_wrong_ayt_projectprops_sql = "SELECT projectprop_id FROM projectprop join cvterm on(type_id=cvterm_id) where name='Advanced Yeld Trials' OR name='Advanced Yield Trials';";
    my $update_previously_saved_wrong_ayt_projectprops_sql = "UPDATE projectprop SET type_id = $correct_ayt_cvterm_id WHERE projectprop_id = ?;";

    my $h1 = $schema->storage->dbh()->prepare($previously_saved_wrong_ayt_projectprops_sql);
    my $h_update = $schema->storage->dbh()->prepare($update_previously_saved_wrong_ayt_projectprops_sql);

    $h1->execute();
    while (my ($projectprop_id) = $h1->fetchrow_array()) {
        $h_update->execute($projectprop_id);
    }

    my $previously_saved_wrong_pyt_projectprops_sql = "SELECT projectprop_id FROM projectprop join cvterm on(type_id=cvterm_id) where name='Preliminary Yield Trials';";
    my $update_previously_saved_wrong_pyt_projectprops_sql = "UPDATE projectprop SET type_id = $correct_pyt_cvterm_id WHERE projectprop_id = ?;";

    my $h2 = $schema->storage->dbh()->prepare($previously_saved_wrong_pyt_projectprops_sql);
    my $h2_update = $schema->storage->dbh()->prepare($update_previously_saved_wrong_pyt_projectprops_sql);

    $h2->execute();
    while (my ($projectprop_id) = $h2->fetchrow_array()) {
        $h2_update->execute($projectprop_id);
    }

    my $wrong_trial_types_rs = $schema->resultset("Cv::Cvterm")->search({
        name => {-in => ["Advanced Yeld Trials", "Advanced Yield Trials", "Preliminary Yield Trials"]}
    });
    while (my $r = $wrong_trial_types_rs->next){
        $r->delete;
    }

    print "You're done!\n";
}


####
1; #
####
