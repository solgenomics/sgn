#!/usr/bin/env perl


=head1 NAME

 UpdateStockSynonymCvterms

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all stockprops of cvterm type "synonym" to a "stock_synonym" cvterm, "stock_property" cv , and "autocreated:stock_synonym" dbxref.
This is done to eliminate redundant usage of synonym-like cvterms loaded in the different databases using different cv terms (null, local, stock_property), making the cvterm name for stock synonyms more explicit: "stock_synonym" instead of "synonym" which may be used for other CVs such as organism_property.
This also solves a potential conflict with the unique constraint in the dbxref table, since using the cvterm name "synonym" causes creating a dbxref.accession of "autocreated:synonym" when creating properties using BCS create_stockprops function. The same accession will be attempted to be created when autocreating another property with the name "synonym", e.g. create_organismprop (organism_synonym will be taken care of in another db_patch)

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateStockSynonymCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create a cvterm name stock_synonym
with cv of stock_property and dbxref of autocreated:stock_synonym
Then all stockprop of type_id matching the word synonym will be associated with 
the stock_synonym cvterm
this is important for making stock synonyms unified across the different databases and eliminating redundancy of cvterms with name = synonym

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


#find or create cvterm with name stock_synonym
#make sure it has a dbxref of autocreated:stock_synonym and db = null
##there might be an existing dbxref with accession = autocreated:synonym
#we will not be using that one anymore for distincting between synonyms of different entities.
    my $coderef = sub {

	my $stock_synonym_cvterm = $schema->resultset("Cv::Cvterm")->create_with( {
	    name => 'stock_synonym',
	    cv   => 'stock_property', }
	    );
	
	my $stock_synonym_cvterm_id = $stock_synonym_cvterm->cvterm_id;
	print "***stock_synonym_cvterm_id is $stock_synonym_cvterm_id \n";
#find all stockprops that have a type_id  ilike %synonym%' and change it to the 
#stock_synonym cvterm 
# delete the cvterm of name = synonym and cv name = "local" or "null"

	my $stockprops = $schema->resultset("Stock::Stockprop")->search( 
	    {
		'type.name' => { ilike => 'synonym%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $stockprops->count . " stockprops \n\n";
	print "**Changing cvterm name of stock synonyms to stock_synonym , cv= stock_property ";
	$stockprops->update( { type_id => $stock_synonym_cvterm_id } ) ;
    
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
