#!/usr/bin/env perl

=head1 NAME
AddNewFolderCvterms.pm
=head1 SYNOPSIS
mx-run AddNewFolderCvterms [options] -H hostname -D dbname -u username [-F]
this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.
=head1 DESCRIPTION
This patch adds new project_property cvterms for classifying folders
=head1 AUTHOR
Nicolas Morales <nm529@cornell.edu>
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

    my $folder_for_trials = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'folder_for_trials',
        cv   => 'project_property',
    });

    my $folder_for_crosses = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'folder_for_crosses',
        cv   => 'project_property',
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