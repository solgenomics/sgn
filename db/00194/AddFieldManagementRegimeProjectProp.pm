#!/usr/bin/env perl


=head1 NAME

AddFieldManagementRegimeProjectProp.pm

=head1 SYNOPSIS

mx-run AddFieldManagementRegimeProjectProp [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddFieldManagementRegimeProjectProp;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

has '+description' => ( default => <<'' );
Adds a projectprop to store field management data. Replaces field management factors, which were deprecated and separated into treatments and field management regimes.

has '+prereq' => (
    default => sub {
        [ ],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
        
    print STDERR "INSERTING CV TERMS...\n";
    
    my $terms = { 
        project_property => 
            [
             "field_management_regime",
            ],
    };
    
    foreach my $t (sort keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with(
                {
                    name => $_,
                    cv => $t
                });
        }
    }
    print STDERR "Patch complete\n";
}


####
1; #
####
