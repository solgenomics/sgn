#!/usr/bin/env perl


=head1 NAME

 CreateSnpTable.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch for creating a new sgn.snp table for storing snps ... 
Motivation is the new genotyping data from the SolCAP project 

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

    Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateSnpTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adding new sgn snp table';
    my @previous_requested_patches = (); #ADD HERE
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
}

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL); 
--do your SQL here
--
CREATE TABLE sgn.snp (
    snp_id serial PRIMARY KEY,
    marker_id integer REFERENCES sgn.marker(marker_id),
    reference_nucleotide varchar(4),
    snp_nucleotide varchar(4) NOT NULL,
    confirmed boolean DEFAULT false,
    sequence_left_id integer REFERENCES sgn.sequence(sequence_id),
    sequence_right_id integer REFERENCES sgn.sequence(sequence_id),
    reference_stock_id integer  REFERENCES public.stock(stock_id),
    stock_id integer NOT NULL REFERENCES public.stock(stock_id),
    metadata_id integer REFERENCES metadata.md_metadata(metadata_id)
);
CREATE TABLE sgn.snpprop (
    snpprop_id serial PRIMARY KEY,
    snp_id integer REFERENCES sgn.snp(snp_id),
    value varchar(255) NOT NULL,
    rank integer,
    type_id integer REFERENCES public.cvterm(cvterm_id)
);

--table snp_file
CREATE TABLE sgn.snp_file (
    snp_file_id serial PRIMARY KEY,
    snp_id integer NOT NULL REFERENCES sgn.snp(snp_id),
    file_id integer NOT NULL REFERENCES metadata.md_files(file_id)
);

--grant permissions to web_usr
 grant SELECT  on sgn.snp to web_usr ;
 grant SELECT  on sgn.snp_snp_id_seq TO  web_usr ;

 grant SELECT  on sgn.snpprop to web_usr ;
 grant SELECT  on sgn.snpprop_snpprop_id_seq TO  web_usr ;

 grant SELECT  on sgn.snp_file to web_usr ;
 grant SELECT  on sgn.snp_file_snp_file_id_seq TO  web_usr ;

EOSQL

    print "You're done!\n";

}


####
1; #
####

