#!/usr/bin/env perl


=head1 NAME

CreateTreatmentCV.pm

=head1 SYNOPSIS

mx-run CreateTreatmentCV [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateExperimentTreatmentCV;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Data::Dumper;
use SGN::Model::Cvterm;
use Cwd;
use File::Temp qw/tempfile/;

has '+description' => ( default => <<'' );
Creates a controlled vocabulary for experimental treatments. Paired with an ontology that tracks experimental treatments like traits. 

has '+prereq' => (
    default => sub {
        [ ],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $dbhost = $self->dbhost;
    my $dbname = $self->dbname;
    my $signing_user = $self->username;

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    my $site_basedir = getcwd()."/../..";
    my $dbpass_key = `cat $site_basedir/sgn.conf $site_basedir/sgn_local.conf | grep '^dbpass'`;
    my (undef, $dbpass) = split(/\s+/, $dbpass_key);
    my $dbuser_key = `cat $site_basedir/sgn.conf $site_basedir/sgn_local.conf | grep '^dbuser'`;
    my (undef, $dbuser) = split(/\s+/, $dbuser_key);
        
    print STDERR "INSERTING CV TERMS...\n";

    my $check_treatment_cv_exists = "SELECT cv_id FROM cv WHERE name='experiment_treatment'";
    
    my $h = $schema->storage->dbh()->prepare($check_treatment_cv_exists);
    $h->execute();

    my $row = $h->fetchrow_array();

    if (defined($row)) {
        print STDERR "Patch already run\n";
    } else {
        my $insert_treatment_cv = "INSERT INTO cv (name, definition) 
        VALUES ('experiment_treatment', 'Experimental treatments applied to some of the stocks in a project. Distinct from management factors/management regimes.');";

        $schema->storage->dbh()->do($insert_treatment_cv);

        my $h = $schema->storage->dbh()->prepare($check_treatment_cv_exists);
        $h->execute();

        my $treatment_cv_id = $h->fetchrow_array();

        my $terms = { 
        'composable_cvtypes' => 
            [
             "experiment_treatment_ontology",
            ],
        };

        my $treatment_ontology_cvterm_id;

        foreach my $t (sort keys %$terms){
            foreach (@{$terms->{$t}}){
                $treatment_ontology_cvterm_id = $schema->resultset("Cv::Cvterm")->create_with(
                    {
                        name => $_,
                        cv => $t
                    })->cvterm_id();
            }
        }

        $schema->resultset("Cv::Cvprop")->create({
            cv_id   => $treatment_cv_id,
            type_id => $treatment_ontology_cvterm_id
        });

        my $experiment_treatment_root_id = $schema->resultset("Cv::Cvterm")->create_with({
				name => 'Experimental treatment ontology',
				cv => 'experiment_treatment',
				db => 'EXPERIMENT_TREATMENT',
				dbxref => '0000000'
		})->cvterm_id();

        system("perl $site_basedir/bin/convert_treatment_projects_to_phenotypes.pl -H $dbhost -D $dbname -U $dbuser -P $dbpass -e $signing_user");

    }
    print STDERR "Patch complete\n";
}


####
1; #
####
