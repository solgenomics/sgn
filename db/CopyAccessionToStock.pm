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


package CopyAccessionToStock;

use Moose;
extends 'CXGN::Metadata::Dbpatch';
use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'populate the chado stock table with sgn accessions';
    my @previous_requested_patches = ('AddStockLinks'); 
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);

}

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    my $q = "SELECT accession.accession_id, common_name, chado_organism_id , accession_name FROM sgn.accession JOIN sgn.accession_names USING (accession_name_id)";
    my $sth = $self->dbh->prepare($q);
    $sth->execute();

    my ($accession_cvterm_id) = $schema->resultset("Cv::Cvterm")->find( { name => 'accession' } )->cvterm_id ||
        die "cvterm for 'accession' has to be stored first in the database ! ";

    while ( my ($accession_id, $cname, $organism_id , $acc_name)  = $sth->fetchrow_array) {
        print "Storing new stock $acc_name ($cname)\n";
        $cname = " ($cname)" if $cname;
        my $stock = $schema->resultset("Stock::Stock")->find_or_create(
            { name   => $acc_name,
              uniquename => $acc_name.$cname,
              organism_id     => $organism_id,
              type_id  => $accession_cvterm_id,
            });
        my $stockprop = $stock->create_stockprops( { stock_synonym => $cname } , {autocreate => 1 } );
        #add the stock_id to the accession table
        my $stock_id = $stock->stock_id;
        $self->dbh->do("UPDATE sgn.accession SET stock_id = $stock_id WHERE accession_id = $accession_id");
    }
    print "You're done!\n";
}


####
1; #
####

