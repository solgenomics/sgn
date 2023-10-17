#!/usr/bin/env perl


=head1 NAME

 CreateStockRelatednessTable.pm

=head1 SYNOPSIS

mx-run CreateStockRelatednessTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Creates the stock_relatedness table for genomic relationships, etc
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateStockRelatednessTable;

use Moose;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates the stock_relatedness table for genomic relationships, etc

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $terms = {
        'stock_relatedness' => [
            'genomic_relatedness_dosage',
        ],
    };

    foreach my $t (keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $_,
                cv => $t
            });
        }
    }

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

DROP TABLE IF EXISTS public.stock_relatedness CASCADE;
CREATE TABLE public.stock_relatedness (
   stock_relatedness_id SERIAL PRIMARY KEY,
   type_id INT NOT NULL,
   a_stock_id INT NOT NULL,
   b_stock_id INT NOT NULL,
   nd_protocol_id INT NOT NULL,
   value DOUBLE PRECISION NOT NULL,
   create_date TIMESTAMP DEFAULT now(),
   CONSTRAINT stock_relatedness_type_id_cvterm_id_fkey
       FOREIGN KEY(type_id)
           REFERENCES cvterm(cvterm_id)
           ON DELETE CASCADE,
   CONSTRAINT stock_relatedness_a_stock_id_stock_id_fkey
       FOREIGN KEY(a_stock_id)
           REFERENCES stock(stock_id)
           ON DELETE CASCADE,
   CONSTRAINT stock_relatedness_b_stock_id_stock_id_fkey
       FOREIGN KEY(b_stock_id)
           REFERENCES stock(stock_id)
           ON DELETE CASCADE,
   CONSTRAINT stock_relatedness_nd_protocol_id_nd_protocol_id_fkey
       FOREIGN KEY(nd_protocol_id)
           REFERENCES nd_protocol(nd_protocol_id)
           ON DELETE CASCADE
);

ALTER TABLE public.stock_relatedness OWNER TO postgres;
GRANT select, update, insert, delete ON public.stock_relatedness to postgres, web_usr;
GRANT usage on sequence stock_relatedness_stock_relatedness_id_seq to postgres, web_usr;

EOSQL


print "You're done!\n";
}


####
1; #
####
