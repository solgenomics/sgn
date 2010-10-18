#!/usr/bin/env perl


=head1 NAME

 CopyAccessionToStock.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]
    
this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.
    
=head1 DESCRIPTION

This is a patch for copying sgn accessions into the stock module.
sgn.accession should be deprecated! This will require some code refactoring like the genetic maps.
 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>
    
=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package TestDbpatchMoose;

use Moose;
extends 'CXGN::Metadata::Dbpatch';
use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'populate the chado stock table with sgn accessions';
    my @previous_requested_patches = ( "CreateSolcapMarkerTables"); #ADD HERE 
    
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
    
}

sub patch {
    my $self=shift;
    
   
    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";
    
    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";
    
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh } );
    my $q = "SELECT common_name, chado_organism_id , accession_name FROM accession JOIN accession_names USING (accession_name_id)";
    my $sth = $self->dbh->prepare($q);
    
    my ($accession_cvterm_id) = $schema->find( { name => 'accession' } ) || 
        die "cvterm for 'accession' has to be stored first in the database ! ";
    
    while ( my ($cname, $organism_id , $acc_name)  = $sth->fetchrow_array) {
        print "Storing new stock $acc_name ($cname)\n";
        my $stock = $schema->resultset("Stock::Stock")->find_or_create( 
            { name   => $acc_name,
              uniquename => "$acc_name ($cname)",
              organism_id     => $organism_id,
              type_id  => $accession_cvterm_id,
            });
        my $stockprop = $stock->create_stockprops( { common_name => $cname } , {autocreate => 1 } );
    }
    
    print "You're done!\n";
    
}


####
1; #
####

