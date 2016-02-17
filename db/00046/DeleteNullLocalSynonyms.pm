#!/usr/bin/env perl


=head1 NAME

 DeleteMullLocalSynonyms

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch deletes the ubiquitous 'synonym' cvterms with cv_id of 'null' or 'local'
synonyms should be loaded with an explicit cv_id providing the right context, e.g. cvterm.name = stock_synoym cv_id = stock_property, organism_synonym cv_id = organism_property
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package DeleteNullLocalSynonyms ;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find cvterms with name ilike synonyms and cv.name 
local or null and will delete those.
this is important for using only synonyms with an explicit cvterm.name and cv.name.

has '+prereq' => (
    default => sub {
        ['UpdateOrganismSynonymCvterms', 'UpdateStockSynonymCvterms' ],
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


###########################

#find all cvterms with name  ilike 'synonym%' and cv.name = local 
# delete the cvterm of name = synonym and cv name = "local" or "null"

	my $local_syn_cvterms = $schema->resultset("Cv::Cvterm")->search( 
	    {
		'me.name' => { ilike => 'synonym%' },
		'cv.name' => 'local' 
	    },
	    { 
		join => 'cv' 
	    } 
	    );
    
	print "** found " . $local_syn_cvterms->count . " cv.name=local cvterms \n\n";

	if ($local_syn_cvterms ) {
	    print "**Deleting ... \n";
	    $local_syn_cvterms->delete;
	}
#############################

	my $null_syn_cvterms = $schema->resultset("Cv::Cvterm")->search( 
	    {
		'me.name' => { ilike => 'synonym%' },
		'cv.name' => 'null' 
	    },
	    { 
		join => 'cv' 
	    } 
	    );
    
	print "** found " . $null_syn_cvterms->count . " cv.name=null cvterms \n\n";

	if ($null_syn_cvterms) { 
	    print "**Deleting ... \n";
	    $null_syn_cvterms->delete;
	}

###############################

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
