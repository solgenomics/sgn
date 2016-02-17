	
#!/usr/bin/env perl


=head1 NAME

 UpdateMembersOf

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch moves all stock_relationship rows with type_id of  "members of" to a "member_of" cvterm, cv , and name dbxref.
This is done to eliminate duplicates of members of cvterms loaded previously in the different databases from the load_genotypes.pl loading script. 
 


This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Guillaume Bauchet<gjb99@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateMembersOf;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will find_or_create a member_of cvterm
with cv of stock_relationship
Then all stock_relationship rows  of type_id matching the word members of will be associated with the member_of cvterm
this is important for making stock_relationship member_of term unified across the different databases and eliminating redundancy

has '+prereq' => (
    default => sub {
        [ 'UnderlineCvNames' ],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


#find or create cvterm with members of name and cv
#make sure it has db = null
##there might be an existing dbxref with members of = autocreated:members of
#
    my $coderef = sub {
	
	my $member_of_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'member_of',
      cv     => 'stock_relationship',
    });

	my $member_of_cvterm_id = $member_of_cvterm->cvterm_id;
	print "***member_of_cvterm_id is $member_of_cvterm_id \n";
	

#find all stock_relationship rows that have a type_id  ilike %members of%' and change it to the 
#stock_relationship member of cvterm 
# delete the old cvterm 'members of' that was created by the load_genotypes.pl script

	my $stock_rel_rs = $schema->resultset("Stock::StockRelationship")->search( 
	    {
		'type.name' => { ilike => 'members of%' },
	    },
	    { 
		join => 'type' 
	    } 
	    );
    
	print "** found " . $stock_rel_rs->count . " stock_relationship rows \n\n";
	print "**Changing type_id to cvterm_id of member_of, cv= stock_relationship \n";
	$stock_rel_rs->update( { type_id => $member_of_cvterm_id});
	
	my $old_cvterm_rs = $schema->resultset("Cv::Cvterm")->search(
	    {
		'me.name' => 'members of', 
		'cv.name' => 'stock_relationship' ,
	    },
	    {
		join => 'cv'
	    }
	    );	
	print "Found . " . $old_cvterm_rs->count . " cvterm(s) with name = 'members of' \n\n";
	if ($old_cvterm_rs->count ) {
	    print "Found cvterm_id for term 'members of' = " . $old_cvterm_rs->first->cvterm_id . "\n DELETING...\n";
	    $old_cvterm_rs->delete();
	} else { 
	    print "nothing to delete here \n\n";
	}
    
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
