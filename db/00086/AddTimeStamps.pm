#!/usr/bin/env perl


=head1 NAME

 AddTimeStamps.pm

=head1 SYNOPSIS

mx-run AddTimeStamps [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds timestamps to project, nd_experiment, stock and phenotype tables so that progress can be tracked more easily.

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddTimeStamps;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds timestamps to project, nd_experiment, stock, stock_relationship, and phenotype tables.

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    $self->dbh->do(<<EOSQL);
--do your SQL here
--



ALTER TABLE nd_experiment ADD column create_date timestamp without time zone default now();
    
    ALTER TABLE project ADD column create_date timestamp without time zone default now();
    
    ALTER TABLE stock ADD column create_date timestamp without time zone default now();
    
    ALTER TABLE stock_relationship ADD column create_date timestamp without time zone default now();
    
    ALTER TABLE phenotype ADD column create_date timestamp without time zone default now();




EOSQL

print "You're done!\n";
}


####
1; #
####
