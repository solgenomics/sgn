#!/usr/bin/env perl


=head1 NAME

 CreateSolcapMarkerTables.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]
    
this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.
    
=head1 DESCRIPTION

This is a patch for creating the necessary tables and rows to accommodate the solcap marker data. Since the SolCap markers have 2-5 primers, we cannot use pcr_experiment.primer_id (which holds only 2 primers), and need instead pcr_experiment_sequence.
 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>
    
=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateSolcapMarkerTables;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'altering marker schema to accommodate SolCap markers';
    my @previous_requested_patches = (); #ADD HERE 
    print "This patch requires version 1.280 of Sequence Ontology";
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
ALTER TABLE sgn.pcr_experiment ADD COLUMN stock_id integer REFERENCES public.stock;
    
CREATE TABLE sgn.pcr_experiment_sequence (
    pcr_experiment_sequence_id serial PRIMARY KEY,
    pcr_experiment_id integer NOT NULL REFERENCES sgn.pcr_experiment ON DELETE CASCADE,
    sequence_id integer NOT NULL REFERENCES sgn.sequence ON DELETE CASCADE,
    type_id integer REFERENCES public.cvterm(cvterm_id)
    );

--copying the pcr_experimet.primer_id columns to pcr_experiment_sequence
--first create a tmp table 
create TEMP TABLE tmp_pcr_rev as SELECT pcr_experiment_id, primer_id_rev FROM sgn.pcr_experiment WHERE primer_id_rev is not null;

--populate the new table 
INSERT INTO sgn.pcr_experiment_sequence (pcr_experiment_id, sequence_id ) SELECT tmp_pcr_rev.* FROM tmp_pcr_rev ;

--update the type_id 
 UPDATE sgn.pcr_experiment_sequence SET type_id = (SELECT cvterm_id FROM public.cvterm where name = 'reverse_primer');

    CREATE TEMP TABLE tmp_pcr_fwd as SELECT pcr_experiment_id, primer_id_fwd FROM sgn.pcr_experiment WHERE primer_id_fwd is not null;

    INSERT INTO sgn.pcr_experiment_sequence (pcr_experiment_id, sequence_id) SELECT tmp_pcr_fwd.* FROM tmp_pcr_fwd;
    
    UPDATE sgn.pcr_experiment_sequence SET type_id =  (SELECT cvterm_id FROM public.cvterm where name = 'forward_primer') WHERE type_id is null;

   CREATE TEMP TABLE tmp_pcr_pd as SELECT pcr_experiment_id, primer_id_fwd FROM sgn.pcr_experiment WHERE primer_id_pd is not null;

    INSERT INTO sgn.pcr_experiment_sequence (pcr_experiment_id, sequence_id) SELECT tmp_pcr_pd.* FROM tmp_pcr_pd;
    
    UPDATE sgn.pcr_experiment_sequence SET type_id =  (SELECT cvterm_id FROM public.cvterm where name ilike 'dcaps_primer') WHERE type_id is null;


--need to refactor the code that uses pcr_experiment.primer_id_fwd/rev/pd (dCAPs?). This will be done in the topic/solcap_marker branch
  

--add SNP to the trigger

alter table sgn.marker_experiment drop constraint marker_experiment_protocol_check;

    alter table sgn.marker_experiment add constraint marker_experiment_protocol_check CHECK (protocol = 'AFLP'::text OR protocol = 'CAPS'::text OR protocol = 'RAPD'::text OR protocol = 'SNP'::text OR protocol = 'SSR'::text OR protocol = 'RFLP'::text OR protocol = 'PCR'::text OR protocol = 'dCAPS'::text OR protocol = 'DART'::text OR protocol = 'OPA'::text OR protocol = 'unknown'::text  OR protocol = 'ASPE'::text  OR protocol = 'INDEL'::text);

--grant permissions to web_usr
 grant SELECT  on sgn.pcr_experiment_sequence to web_usr ;
 grant SELECT  on sgn.pcr_experiment_sequence_pcr_experiment_sequence_id_seq TO  web_usr ;

EOSQL

    print "You're done!\n";

}


####
1; #
####

