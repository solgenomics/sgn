#!/usr/bin/env perl


=head1 NAME

 AddRejectedPlotStockprops.pm

=head1 SYNOPSIS

mx-run AddRejectedPlotStockprops [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds the stock properties rejected and reject_reason: a planted plot whose data are kept but left out of phenotype downloads, datasets and analyses. See CXGN::Trial::AccessionChange and CXGN::Phenotypes::RejectedUnits.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Breedbase team

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddRejectedPlotStockprops;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create the stock_property cvterms rejected and reject_reason, for planted plots whose data must not be used

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

    my $coderef = sub {

        foreach my $name ('rejected', 'reject_reason') {
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $name,
                cv   => 'stock_property',
            });
        }
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
