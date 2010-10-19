#!/usr/bin/env perl


=head1 NAME

 LoadSGNSequenceTypes.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]
    
this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.
    
=head1 DESCRIPTION

This is a patch for loading in the cvterm table the required sgn sequence types for the sgn.pcr_experiment_sequence table. 
 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>
    
=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package LoadSGNSequenceTypes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'loading sgn sequence types in the cvterm table';
    my @previous_requested_patches ; #ADD HERE 
    
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
    
}

sub patch {
    my $self=shift;
    
   
    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";
    
    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";
    
   
    print STDOUT "\nExecuting the SQL commands.\n";

     my $schema = Bio::Chado::Schema->connect( sub { $self->dbh } ,  { on_connect_do => ['SET search_path TO public;'], autocommit => 1 });
    my @primers = ( 'forward primer', 'reverse primer','dcaps primer','aspe primer', 'snp nucleotide', 'indel' , 'reference nucleotide');
    foreach my $p (@primers) {
        print "Storing primer type $p\n";
        my $cvterm = $schema->resultset("Cv::Cvterm")->create_with( 
            { name   => $p,
              cv     => 'sgn sequence type',
              db     => 'SGN',
              dbxref => "sgn $p",
            });
    }
    print "You're done!\n";
    
}


####
1; #
####

