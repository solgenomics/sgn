#!/usr/bin/env perl

=head1 NAME

AddNewCrossCvterms.pm

=head1 SYNOPSIS

mx-run AddNewCrossCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds new cross cvterms so that they can be stored in the nd_experimentprop table.

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNewCrossCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds new cross cvterms so that they can be stored in the nd_experimentprop table.


sub patch {
  my $self=shift;

  print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

  print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

  print STDOUT "\nExecuting the SQL commands.\n";

  my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

  my $coderef = sub {

    my $date_of_pollination = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'date_of_pollination',
        cv   => 'nd_experiment_property',
    });

    my $date_of_harvest  = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'date_of_harvest',
        cv   => 'nd_experiment_property',
    });

    my $date_of_seed_extraction  = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'date_of_seed_extraction',
        cv   => 'nd_experiment_property',
    });

    my $number_of_seeds_extracted  = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'number_of_seeds_extracted',
        cv   => 'nd_experiment_property',
    });

    my $number_of_viable_seeds  = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'number_of_viable_seeds',
        cv   => 'nd_experiment_property',
    });

    my $date_of_embryo_rescue  = $schema->resultset("Cv::Cvterm")->create_with({
        name => '$date_of_embryo_rescue',
        cv   => 'nd_experiment_property',
    });

    my $number_of_embryos_rescued  = $schema->resultset("Cv::Cvterm")->create_with({
        name => '$number_of_embryos_rescued',
        cv   => 'nd_experiment_property',
    });

    my $number_of_embryos_germinated  = $schema->resultset("Cv::Cvterm")->create_with({
        name => '$number_of_embryos_germinated',
        cv   => 'nd_experiment_property',
    });

    my $number_of_contaminated_embryos  = $schema->resultset("Cv::Cvterm")->create_with({
        name => '$number_of_contaminated_embryos',
        cv   => 'nd_experiment_property',
    });

    my $number_of_seeds_planted  = $schema->resultset("Cv::Cvterm")->create_with({
        name => '$number_of_seeds_planted',
        cv   => 'nd_experiment_property',
    });

    my $number_of_seeds_germinated  = $schema->resultset("Cv::Cvterm")->create_with({
        name => '$number_of_seeds_germinated',
        cv   => 'nd_experiment_property',
    });

  };

  try {
    $schema->txn_do($coderef);
  } catch {
    die "Load failed! " . $_ .  "\n" ;
  };

  print "You're done!\n";

}

####
1; #
####
