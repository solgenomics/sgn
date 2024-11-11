#!/usr/bin/env perl


=head1 NAME

AddFillerIdentification.pm

head1 SYNOPSIS

mx-run AddFillerIdentification [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds transplanting date cvterm 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



package AddFillerIdentification;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch will add system cvterms required for the functionality of the cxgn databases

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


    my %cvterms = 
    (
        
    'stock_property'      => [
                  'is a filler'
                  ]
     
    );
    

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    

    my $coderef = sub {

    
        foreach my $cv_name ( keys  %cvterms  ) {
        print "\nKEY = $cv_name \n\n";
        my @cvterm_names = @{$cvterms{ $cv_name } }  ;
        
        foreach  my $cvterm_name ( @cvterm_names ) {
        print "cvterm= $cvterm_name \n";
        my $new_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
            {
            name => $cvterm_name,
            cv   => $cv_name,
            });
        }
    }
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
