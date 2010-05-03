#!/usr/bin/perl -wT

=head1 DESCRIPTION
A small script for downloading population 
phenotype raw data in tab delimited format.

=head1 AUTHOR(S)

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

use CXGN::DB::Connection;
use CXGN::Phenome::Population;
use CXGN::Phenome::Individual;
use CXGN::Scrap;

my $scrap = CXGN::Scrap->new();
my $dbh   = CXGN::DB::Connection->new();

my $population_id = $scrap->get_encoded_arguments("population_id");

my $pop = CXGN::Phenome::Population->new( $dbh, $population_id );
my $name = $pop->get_name();

print
"Pragma: \"no-cache\"\nContent-Disposition:filename=phenotype_data_${population_id}.txt\nContent-type:application/data\n\n";

#print "Content-Type: text/plain\n\n";

print "Phenotype data for $name\n\n\n";


my @individuals = $pop->get_individuals();

my ( @pop_id, @name, @obs_id, @cvterm, @definition, @value );

my $individual_obj = $individuals[1];

my $indv_id = $individual_obj->get_individual_id();

my @cvterms = $individual_obj->get_unique_cvterms($indv_id);

print "Lines \t";
print join( "\t", @cvterms );

my ( $pop_id, $pop_name, $ind_id, $ind_name, $obs_id, $cvterm, $definition,
     $value )
  = $pop->get_pop_raw_data();

my $old_ind_id = "";

for ( my $i = 0 ; $i < @$pop_id ; $i++ )
{
    if ( $old_ind_id ne $ind_id->[$i] )
    {

        print "\n$ind_name->[$i]\t";
    }

    foreach my $t (@cvterms)
    {
        my $term = $cvterm->[$i];
        if ( $t =~ /^$term$/i )
        {
            print "$value->[$i]\t";
        }
    }
    $old_ind_id = $ind_id->[$i];
}

