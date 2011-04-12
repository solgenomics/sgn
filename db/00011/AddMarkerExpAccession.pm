#!/usr/bin/env perl


=head1 NAME

 SampleDbpatchMoose.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]
    
this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.
    
=head1 DESCRIPTION

This is a test dummy patch. 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>
    
=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMarkerExpAccession;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adds a stock_id column to pcr_exp_accession and populates it.';
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
-- add a stock_id column to pcr_exp_accession

set search_path=public,sgn;

alter table sgn.pcr_exp_accession add column stock_id bigint references public.stock;

-- copy the stock to accession mapping from sgn.accession
--
update sgn.pcr_exp_accession set stock_id=sgn.accession.stock_id FROM sgn.accession where sgn.accession.accession_id=pcr_exp_accession.accession_id;
   
alter table sgn.map add column parent1_stock_id bigint references public.stock;

alter table sgn.map add column parent2_stock_id bigint references public.stock;

alter table sgn.map add column population_stock_id bigint references public.stock;

    update sgn.map set parent1_stock_id=accession.stock_id FROM sgn.accession where sgn.accession.accession_id=map.parent_1;

    update sgn.map set parent2_stock_id=accession.stock_id FROM sgn.accession where sgn.accession.accession_id=map.parent_2;

update sgn.map set population_stock_id=phenome.population.stock_id FROM phenome.population WHERE sgn.map.population_id=phenome.population.population_id;

-- remove trigger
    drop trigger pcr_accession_check_trigger on sgn.pcr_exp_accession;;

alter table sgn.pcr_exp_accession drop constraint accession_id_check;

EOSQL

print "You're done!\n";
    
}


####
1; #
####
