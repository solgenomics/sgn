#!/usr/bin/env perl
package AddWebUsrDeletePermToOrganismprop;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

sub patch {
    my $self=shift;
    
   
    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";
    
    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    

    print STDOUT "\nExecuting the SQL commands.\n";
    
    $self->dbh->do(<<EOSQL); 
--do your SQL here
--

grant insert on cvterm to web_usr;
grant usage, update on cvterm_cvterm_id_seq to web_usr;
grant insert,delete on public.organismprop to web_usr;
grant usage, update on organismprop_organismprop_id_seq to web_usr;
EOSQL

print "You're done!\n";
    
}


####
1; #
####
