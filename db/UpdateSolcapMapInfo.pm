#!/usr/bin/env perl


=head1 NAME

 UpdateSolcapMapInfo.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]
    
this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.
    
=head1 DESCRIPTION

This is a patch for updating info for solcap maps. This should be run after running the loading script for the 3 maps
 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateSolcapMapInfo;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;
use CXGN::Accession;

sub init_patch {
    my $self = shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'loading solcap map info';
    my @previous_requested_patches ; #ADD HERE

    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);

}

sub patch {
    my $self=shift;
    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


    my @maps = (
        {
            name => "Integrated map: Yellow Stuffer X LA1589 and Sun1642 X LA1589",
            abstract => "Linkage maps were developed for the Yellow Stuffer × LA1589 and Sun1642 × LA1589 populations separately then the two maps were combined by chromosome into an integrated map using Joinmap 3.0 (Van Ooijen and Voorrips 2001).",
            parent1 =>'any',
            parent2 => 'any',
            species1 => 'Solanum lycopersicum',
            species2 => 'Solanum lycopersicum',
            long_name => "Integrated map: Yellow Stuffer X LA1589 and Sun1642 X LA1589"
        },
        {
            name => "Yellow Stuffer x LA1589",
            abstract =>"200 F2 plants from a cross between Yellow Stuffer and LA1589 (van der Knaap and Tanksley 2003).",
            parent1  =>  "Yellow Stuffer",
            parent2  => "LA1589",
            species1 => 'Solanum lycopersicum',
            species2 => 'Solanum pimpinellifolium',
            long_name => 'S.lycopersicum Yellow Stuffer X S.pimpinellifolium LA1589'
        },
        {
            name => "Sun1642 x LA1589",
            abstract => "The mapping population derived from Sun1642 (S.lycopersicum) and LA1589 (S. pimpinellifolium) consists of 100 F2 individuals (van der Knaap and Tanksley 2001).",
            parent1  => 'LA1589',
            parent2  => 'Sun1642',
            species1 => 'Solanum pimpinellifolium',
            species2 => 'Solanum lycopersicum',
            long_name => 'S.lycopersicum Sun1642 X S.pimpinellifolium LA1589'
        },
       );

    my $result = $schema->txn_do( sub {

        for my $map ( @maps ) {

            my ( $map_id ) = $self->dbh->selectrow_array( <<'', undef, $map->{name} );
                 SELECT map_id
                   FROM   sgn.map
                  WHERE  short_name = ?

            $map_id or die "Map '$map->{name}' not found in database.  Aborting.\n";

            my $accession_id1 = $self->_find_accession( $schema, $map->{name}, $map->{parent1}, $map->{species1} );
            my $accession_id2 = $self->_find_accession( $schema, $map->{name}, $map->{parent2}, $map->{species2} );

            print <<"";
Updating map '$map->{name}'
    id       = $map_id
    abstract = $map->{abstract}
    parent1  = $accession_id1
    parent2  = $accession_id2

            $self->dbh->do( <<'', undef, $map->{long_name}, $map->{abstract}, $accession_id1, $accession_id2, ,'genetic' , $map_id );
                UPDATE sgn.map
                   SET long_name= ?, abstract = ? , parent_1 = ? , parent_2 = ?, map_type = ?
                 WHERE map_id = ?

        }

        if ( $self->trial ) {
	    print "Trial mode! Rolling back transaction.\n\n";
	    $schema->txn_rollback;
            return 0;
        } else {
            print "Committing.\n";
            return 1;
        }
    });

    print $result ? "Patch applied successfully.\n" : "Patch not applied.\n";
}

sub _find_accession {
    my $self = shift;
    my $schema = shift;
    my $name = shift;
    my $parent = shift;
    my $species = shift;

    my $organism = $schema->resultset("Organism::Organism")->find( { species=> $species }, );
    die 'Organism $species not found in the database! Aborting\n' if !$organism;
    my $sgn_q = "SELECT organism_id FROM sgn.organism WHERE chado_organism_id =? ";
    my $o_sth = $self->dbh->prepare($sgn_q);
    $o_sth->execute($organism->organism_id);
    my ($sgn_organism_id) = $o_sth->fetchrow_array();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with( {
        name => 'accession',
        cv   => 'stock type', }
        );
    $self->dbh->do('set search_path to sgn, public');
    my $accession = CXGN::Accession->new($self->dbh , $parent);
    my $accession_id;
    if ( !$accession) {
        my ($stock) = $schema->resultset("Stock::Stock")->find_or_create( 
            {
                name => $parent,
                uniquename => $parent,
                type_id => $accession_cvterm->cvterm_id,
                organism_id => $organism->organism_id,
            }, );
        print "inserting into accession_names value $parent\n";
        $self->dbh->do("insert into sgn.accession_names (accession_name) values ('".$parent."') " );
        my $a_name_id = $self->dbh->last_insert_id('Pg' , 'sgn','accession_names', 'accession_name_id');
        print "inserting into accession value $a_name_id, stock_id = " . $stock->stock_id . "\n";
        $self->dbh->do("insert into sgn.accession (accession_name_id, stock_id, organism_id, chado_organism_id) values ('".$a_name_id . "', " . $stock->stock_id  . ", $sgn_organism_id , " . $organism->organism_id . ")");
        $accession_id = $self->dbh->last_insert_id('Pg' , 'sgn','accession', 'accession_id');
        print "Updating accession_names , setting accession_id = ". $accession_id . "\n";
        $self->dbh->do("UPDATE sgn.accession_names SET accession_id = ". $accession_id . " WHERE accession_name_id = $a_name_id");

        $accession = CXGN::Accession->new($self->dbh , $parent);
    } else { $accession_id = $accession->accession_id ; }

    return $accession_id;
}


####
1; #
####

