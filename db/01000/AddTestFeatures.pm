#!/usr/bin/env perl


=head1 NAME

    AddTestFeatures.pm

=head1 SYNOPSIS

mx-run AddTestFeatures [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds test chromosomes to the feature table
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddTestFeatures;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'');
This patch adds test chromosomes to the feature table


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


    # Get feature type to use
    my $sequence_cv_id = $schema->resultset("Cv::Cv")->find({ name => 'sequence' })->cv_id();
    my $feature_type_id = $schema->resultset("Cv::Cvterm")->find({ 
        name => 'chromosome',
        cv_id => $sequence_cv_id
    })->cvterm_id();


    # Get organism to use
    my $organism_id = $schema->resultset("Organism::Organism")->find({ genus => 'Triticum', species=> 'aestivum' })->organism_id();



    $self->dbh->do(<<EOSQL);

-- add 21 chromosomes
INSERT INTO "public"."feature" ("organism_id", "name", "uniquename","type_id", "is_obsolete") VALUES
('$organism_id', 'chr1A', 'chr1A', '$feature_type_id', 'f'),
('$organism_id', 'chr2A', 'chr2A', '$feature_type_id', 'f'),
('$organism_id', 'chr3A', 'chr3A', '$feature_type_id', 'f'),
('$organism_id', 'chr4A', 'chr4A', '$feature_type_id', 'f'),
('$organism_id', 'chr5A', 'chr5A', '$feature_type_id', 'f'),
('$organism_id', 'chr6A', 'chr6A', '$feature_type_id', 'f'),
('$organism_id', 'chr7A', 'chr7A', '$feature_type_id', 'f'),
('$organism_id', 'chr1B', 'chr1B', '$feature_type_id', 'f'),
('$organism_id', 'chr2B', 'chr2B', '$feature_type_id', 'f'),
('$organism_id', 'chr3B', 'chr3B', '$feature_type_id', 'f'),
('$organism_id', 'chr4B', 'chr4B', '$feature_type_id', 'f'),
('$organism_id', 'chr5B', 'chr5B', '$feature_type_id', 'f'),
('$organism_id', 'chr6B', 'chr6B', '$feature_type_id', 'f'),
('$organism_id', 'chr7B', 'chr7B', '$feature_type_id', 'f'),
('$organism_id', 'chr1D', 'chr1D', '$feature_type_id', 'f'),
('$organism_id', 'chr2D', 'chr2D', '$feature_type_id', 'f'),
('$organism_id', 'chr3D', 'chr3D', '$feature_type_id', 'f'),
('$organism_id', 'chr4D', 'chr4D', '$feature_type_id', 'f'),
('$organism_id', 'chr5D', 'chr5D', '$feature_type_id', 'f'),
('$organism_id', 'chr6D', 'chr6D', '$feature_type_id', 'f'),
('$organism_id', 'chr7D', 'chr7D', '$feature_type_id', 'f');


EOSQL

print "You're done!\n";
}


####
1; #
####
