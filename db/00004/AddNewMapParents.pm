#!/usr/bin/env perl


=head1 NAME

 AddNewMapParents.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch for updating parents for the new Nicotiana maps (Wu et al 2010) and the potato map (from Dan Bolser)

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNewMapParents;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;
use CXGN::Accession;

sub init_patch {
    my $self = shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'loading map parents for tobacco and potato maps';
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

#-- insert Nicotiana acuminata#

#insert into sgn.accession (chado_organism_id, common_name) values (22547, 'Nicotiana acuminata');

#insert into sgn.accession (chado_organism_id, common_name) values (1483, 'Nicotiana tomentosiformis');

#insert into sgn.accession (chado_organism_id, common_name) values (13311, 'Solanum phureja');

    my @maps = (
        {
            name => "Tobacco N. tomentosiformis",
            abstract => "population of 55 interspecific F2 plants from the cross N. tomentosiformis TA3385 × N. otophora TA3353",
            parent1 =>'TA3385',
            parent2 => 'TA3353',
            species1 => 'Nicotiana tomentosiformis',
            species2 => 'Nicotiana otophora',
            long_name => "N. tomentosiformis TA3385 × N. otophora TA3353",
        },

        {
            name => "Tobacco N. acuminata",
            abstract => "mapping population of 51 intraspecific F2 plants from N. acuminata TA3460 × N. acuminata var. multiflora TA3461",
            parent1 =>'TA3460',
            parent2 => 'TA3461',
            species1 => 'Nicotiana acuminata',
            species2 => 'Nicotiana acuminata var. multiflora',
            long_name => "N. acuminata TA3460 × N. acuminata var. multiflora TA3461",
        },

        {
            name => "Solanum phureja diploid map 2010",
            abstract => "Potato, the world's most important vegetable crop and a key member of the Solanaceae, is being sequenced by the multi-national Potato Genome Sequencing Consortium (PGSC, see www.potatogenome.net). Using a whole
genome shotgun approach the PGSC has generated a high quality draft
sequence of a completely homozygous ‘doubled monoploid’ clone (DM1-3
516R44 or CIP 801092) of S. tuberosum group Phureja complementing
their earlier efforts using the heterozygous RH89-039-16 clone. In
order to augment the genetic and physical anchoring of the sequenced
DM genome, a segregating backcross population between the DM clone and
a heterozygous diploid S. goniocalyx clone (CIP No. 703825) as the
recurrent parent was established. The polymorphism across 169 progeny
clones was assessed using a total of 4836 STS markers including 2174
DArT (Diversity Arrays Technology), 378 SSR (simple sequence repeat)
alleles and 2304 SNP (single nucleotide polymorphism) marker types.
SSR and SNP markers were designed directly to scaffolds, whereas
polymorphic DArT marker sequences were searched against the scaffolds
for high quality unique matches. The data from 2619 polymorphic STS
markers was analysed using JoinMap 4 and a DM genetic map containing
the expected 12 potato linkage groups was developed de novo. The
mapped STS markers, because of their known unique position and/or
sequence on the genome, were directly anchored to the DM
super-scaffolds. This in turn assisted in physical anchoring of DM
super-scaffolds on to the DM/DI//DI linkage map. In addition to this,
in silico approaches involving the RH genetic and physical map, as
well as tomato map data from SGN (http://solgenomics.net/) were also
exploited to further enhance the anchoring of DM genome. Overall, we
are able to genetically anchor 623 Mb (85.7%) of the assembled 727 Mb
genome arranged in 651 super-scaffolds to an approximate location onto
one of the twelve potato linkage groups. In the post potato sequencing
era, this integrated sequence and genetic reference map will form an
important resource for linking to all future genetic mapping efforts
by the potato community.",
            parent1 =>'CIP 801092',
            parent2 => 'CIP 703825',
            species1 => 'Solanum phureja',
            species2 => 'Solanum goniocalyx',
            long_name =>  "DM1-3 516R44 clone (CIP 801092) backcrossed to a heterozygous diploid S. goniocalyx clone (CIP No. 703825)",
        },

        );
    $schema->resultset("Organism::Organism")->find_or_create( {
        genus => 'Solanum',
        species => 'Solanum goniocalyx',
                                                              }, );
    $schema->resultset("Organism::Organism")->find_or_create( {
        genus => 'Nicotiana',
        species => 'Nicotiana acuminata var. multiflora',
                                                              }, );
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
    my ($sgn_organism_id) = $o_sth->fetchrow_array() || 'NULL';

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

