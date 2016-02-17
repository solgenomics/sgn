#!/usr/bin/env perl


=head1 NAME

 UpdateOrganismSynonymCvterms

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all organismprops of cvterm type "synonym" to a "organism_synonym" cvterm, "orgnaism_property" cv,
and "autocreated:organism_synonym" dbxref.
This is done to eliminate redundant usage of synonym-like cvterms loaded in the different databases 
using different cv terms (null, local, stock_property), making the cvterm name for organism synonyms more explicit: 
"orgnaism_synonym" instead of "synonym" 
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "synonym" 
causes creating a dbxref.accession of "autocreated:synonym" when creating properties using BCS create_stockprops function. 
The same accession will be attempted to be created when autocreating another property with the name "synonym", e.g. 
create_stockprops (stock_synonym is take care of in db_patch UpdateStockSynonymCvterms )

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateOrganismSynonymCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create a cvterm name organism_synonym
with cv of organism_property and dbxref of autocreated:organism_synonym
Then all organismprops of type_id matching the word synonym will be associated with 
the organism_synonym cvterm
this is important for making organism synonyms unified across the different databases and eliminating redundancy of cvterms with name = synonym

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


#find or create cvterm with name organism_synonym
#make sure it has a dbxref of autocreated:organism_synonym and db = null
##there might be an existing dbxref with accession = autocreated:synonym
#we will not be using that one anymore for distincting between synonyms of different entities.
    my $coderef = sub {

	my $organism_synonym_cvterm = $schema->resultset("Cv::Cvterm")->create_with( {
	    name => 'organism_synonym',
	    cv   => 'organism_property', }
	    );
	
	my $organism_synonym_cvterm_id = $organism_synonym_cvterm->cvterm_id;
	print "***organism_synonym_cvterm_id is $organism_synonym_cvterm_id \n";
#find all organismprops that have a type_id  ilike %synonym%' and change it to the 
#organism_synonym cvterm 
# delete the cvterm of name = synonym and cv name = "local" or "null"

	my $organismprops = $schema->resultset("Organism::Organismprop")->search( 
	    {
		'type.name' => { ilike => '%synonym%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $organismprops->count . " organismprops \n\n";
	print "**Changing cvterm name of organism synonyms to organism_synonym , cv= organism_property ";
	$organismprops->update( { type_id => $organism_synonym_cvterm_id } ) ;
    
	if ($self->trial) {
            print "Trial mode! Rolling back transaction\n\n";
            $schema->txn_rollback;
	    return 0;
        }
        return 1;
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
