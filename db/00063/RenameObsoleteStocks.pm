#!/usr/bin/env perl

=head1 NAME

RenameObsoleteStocks.pm

=head1 SYNOPSIS

mx-run RenameObsoleteStocks [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch renames obsolete stocks by adding _OBSOLETED and a timestamp to the end of the uniquename and name. This then allows new stocks to be added with the same name as the obsoleted stock.

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package RenameObsoleteStocks;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch renames obsolete stocks by adding _OBSOLETED and a timestamp to the end of the uniquename and name. This then allows new stocks to be added with the same name as the obsoleted stock.


sub patch {
  my $self=shift;

  print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

  print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

  print STDOUT "\nExecuting the SQL commands.\n";

  my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

  my $coderef = sub {
      print STDERR "Updating names of obsolete stocks . . .\n";

      my $obsolete_stocks = $schema->resultset("Stock::Stock")->search({is_obsolete => 't'});

      while (my $stock = $obsolete_stocks->next) {
        my $obsolete_string = '_OBSOLETED_' . localtime();
        my $name = $stock->name();
        my $uniquename = $stock->uniquename();

        unless ($name =~ /OBSOLETE/ || $uniquename =~ /OBSOLETE/) { # skip if already renamed
          $stock->update( { name => $name . $obsolete_string, uniquename => $uniquename . $obsolete_string }, );
          print STDERR "Set stock $name name to $name$obsolete_string and uniquename to $uniquename$obsolete_string . . .\n";
        }

      }
  };

  try {
    $schema->txn_do($coderef);
  } catch {
    die "RenameObsoleteStocks patch failed! " . $_ .  "\n" ;
  };

  print "You're done!\n";

}

####
1; #
####
