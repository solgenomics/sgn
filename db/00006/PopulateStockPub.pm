#!/usr/bin/env perl


=head1 NAME

    PopulateStockPub.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch for populating the stockpub table , and granting web_usr permissions

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

    Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package PopulateStockPub;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Populating stock_pub table';
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
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $stockdbxrefs = $schema->resultset("General::Db")->search( { name => 'PMID' } )
        ->search_related('dbxrefs')->search_related('stock_dbxrefs');
    my $result = $schema->txn_do( sub {
        while ( my $sd = $stockdbxrefs->next )  {
            $sd->stock->find_or_create_related('stock_pubs' , {
                pub_id => $sd->dbxref->search_related('pub_dbxrefs')->search_related('pub')->first->pub_id
                                               }, );
            print "Added publication for stock " . $sd->stock->name . "\n"; 
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


    $self->dbh->do(<<EOSQL); 
--do your SQL here
--
--grant permissions to web_usr
 grant ALL  on public.stock_pub to web_usr ;
 grant USAGE on public.stock_pub_stock_pub_id_seq TO  web_usr ;


EOSQL
    print $result ? "Patch applied successfully.\n" : "Patch not applied.\n";
}


####
1; #
####

