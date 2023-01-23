#!/usr/bin/env perl


=head1 NAME

 AddVectorStockProps.pm

=head1 SYNOPSIS

mx-run AddVectorStockProps [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Mirella Flores <mrf252@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddVectorStockProps;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create a cvterm for vectors

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

	my $vector_stockprop_SelectionMarker_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
	    name => 'SelectionMarker',
	    cv   => 'stock_property',
	});
	my $vector_stockprop_CloningOrganism_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
	    name => 'CloningOrganism',
	    cv   => 'stock_property',
	});
	my $vector_stockprop_CassetteName_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
	    name => 'CassetteName',
	    cv   => 'stock_property',
	});

    my $vector_stockprop_InherentMarker_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'InherentMarker',
        cv   => 'stock_property',
    });
    my $vector_stockprop_Strain_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'Strain',
        cv   => 'stock_property',
    });
    my $vector_stockprop_Backbone_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'Backbone',
        cv   => 'stock_property',
    });

    my $vector_stockprop_Gene_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'Gene',
        cv   => 'stock_property',
    });
    my $vector_stockprop_Promotors_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'Promotors',
        cv   => 'stock_property',
    });
    my $vector_stockprop_Terminators_cvterm = $schema->resultset("Cv::Cvterm")->create_with({
        name => 'Terminators',
        cv   => 'stock_property',
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
