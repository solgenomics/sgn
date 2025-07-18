#!/usr/bin/env perl


=head1 NAME

 AddTraitPropRepeatType

=head1 SYNOPSIS

mx-run AddTraitPropRepeatType [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This dbpatch adds the trait_repeat_type property to the trait_property cv.


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2024 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddTraitPropRepeatType;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub { []
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my %cvterms = ( 
	'trait_property' => [ 'trait_repeat_type' ],
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
    

    

print "You successfully added the new property 'trait_repeat_type'!\n";
}


####
1; #
####
