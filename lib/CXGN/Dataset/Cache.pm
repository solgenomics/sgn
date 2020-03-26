
package CXGN::Dataset::Cache;

use strict;
use warnings;
use Moose;
use Cache::File;
use Digest::MD5 qw | md5_hex |;
use JSON::Any;
use JSON;
use Data::Dumper;

extends 'CXGN::Dataset';

has 'cache_root' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'cache' => (
    isa => 'Cache::File',
    is => 'rw',
);

has 'cache_expiry' => (
    isa => 'Int',
    is => 'rw',
    default => 0, # never expires?
);

sub key {
    my $self = shift;
    my $datatype = shift;

    #print STDERR Dumper($self->_get_dataref());
    my $json = JSON->new();
    #preserve order of hash keys to get same text
    $json = $json->canonical();
    my $key = md5_hex($json->encode( $self-> _get_dataref() )."_$datatype");
    return $key;
}

sub genotype_key {
    my $self = shift;
    my $datatype = shift;
    my $protocol_id = shift;
    my $markerprofiles = shift;
    my $genotypedataprojects = shift;
    my $markernames = shift;
    my $genotypeprophash = shift;
    my $protocolprophash = shift;
    my $protocolpropmarkerhash = shift;
    my $return_only_first_genotypeprop_for_stock = shift;
    my $chromosome_list = shift;
    my $start_position = shift;
    my $end_position = shift;
    my $marker_name_list = shift;

    #print STDERR Dumper($self->_get_dataref());
    my $json = JSON->new();
    #preserve order of hash keys to get same text
    $json = $json->canonical();
    my $dataref = $json->encode( $self-> _get_dataref() );
    $markerprofiles = $json->encode( $markerprofiles || [] );
    $genotypedataprojects = $json->encode( $genotypedataprojects || [] );
    $markernames = $json->encode( $markernames || [] );
    $genotypeprophash = $json->encode( $genotypeprophash || [] );
    $protocolprophash = $json->encode( $protocolprophash || [] );
    $protocolpropmarkerhash = $json->encode( $protocolpropmarkerhash || [] );
    $chromosome_list = $json->encode( $chromosome_list || [] );
    $start_position = $start_position || '';
    $end_position = $end_position || '';
    $marker_name_list = $json->encode( $marker_name_list || [] );
    my $key = md5_hex($dataref.$protocol_id.$markerprofiles.$genotypedataprojects.$markernames.$genotypeprophash.$protocolprophash.$protocolpropmarkerhash.$return_only_first_genotypeprop_for_stock.$chromosome_list.$start_position.$end_position.$marker_name_list."_$datatype");
    return $key;
}


after('BUILD', sub {
    my $self = shift;
    $self->cache( Cache::File->new( cache_root => $self->cache_root() ));
});


override('retrieve_genotypes',
    sub {
        my $self = shift;
        my $protocol_id = shift;
        my $genotypeprop_hash_select = shift;
        my $protocolprop_top_key_select = shift;
        my $protocolprop_marker_hash_select = shift;
        my $return_only_first_genotypeprop_for_stock = shift;
        my $chromosome_list = shift || [];
        my $start_position = shift;
        my $end_position = shift;
        my $marker_name_list = shift || [];
        
        my $key = $self->genotype_key("retrieve_genotypes", $protocol_id, undef, undef, undef, $genotypeprop_hash_select, $protocolprop_top_key_select, $protocolprop_marker_hash_select, $return_only_first_genotypeprop_for_stock, $chromosome_list, $start_position, $end_position, $marker_name_list);

        if ($self->cache()->exists($key)) {
            my $genotype_json = $self->cache()->get($key);
            my $genotypes = JSON::Any->decode($genotype_json);
            undef $genotype_json;
            return $genotypes;
        }
        else {
            my $genotypes = $self->SUPER::retrieve_genotypes($protocol_id, $genotypeprop_hash_select, $protocolprop_top_key_select, $protocolprop_marker_hash_select, $return_only_first_genotypeprop_for_stock);
            my $genotype_json = JSON::Any->encode($genotypes);
            $self->cache()->set($key, $genotype_json, $self->cache_expiry());
            undef $genotype_json;
            return $genotypes;
        }
    });

override('retrieve_phenotypes',
    sub {
        my $self = shift;
        if ($self->cache()->exists($self->key("phenotype"))) {
            my $phenotype_json = $self->cache()->get($self->key("phenotype"));
            my $phenotypes = JSON::Any->decode($phenotype_json);
            return $phenotypes;
        }
        else {
            my $phenotypes = $self->SUPER::retrieve_phenotypes();
            my $phenotype_json = JSON::Any->encode($phenotypes);
            $self->cache()->set($self->key("phenotype"), $phenotype_json, $self->cache_expiry());
            return $phenotypes;
        }
    });

override('retrieve_accessions',
	 sub {
	     my $self = shift;
	     if ($self->cache()->exists($self->key("accessions"))) {
		 my $accession_json = $self->cache()->get($self->key("accessions"));
		 my $accessions = JSON::Any->decode($accession_json);
		 return $accessions;
	     }
	     else {
		 my $accessions = $self->SUPER::retrieve_accessions();
		 my $accession_json = JSON::Any->encode($accessions);
		 $self->cache()->set($self->key("accessions"), $accession_json, $self->cache_expiry());
		 return $accessions;
	     }
	 });

override('retrieve_plots',
	 sub {
	     my $self = shift;

	     if ($self->cache()->exists($self->key("plots"))) {
		 print STDERR "Retrieving plots from cache...\n";
		 my $plot_json = $self->cache()->get($self->key("plots"));
		 my $plots = JSON::Any->decode($plot_json);
		 return $plots;
	     }
	     else {
		 print STDERR "Retrieving plots and caching them...\n";
		 my $plots = $self->SUPER::retrieve_plots();
		 #print STDERR Dumper($plots);
		 my $plot_json = JSON::Any->encode($plots);
		 $self->cache()->set($self->key("plots"), $plot_json, $self->cache_expiry());
		 return $plots;
	     }
	 });

override('retrieve_trials',
	 sub {
	     my $self = shift;

	     if ($self->cache()->exists($self->key("trials"))) {
		 my $trial_json = $self->cache()->get($self->key("trials"));
		 my $trials = JSON::Any->decode($trial_json);
		 return $trials;
	     }
	     else {
		 my $trials = $self->SUPER::retrieve_trials();
		 my $trial_json = JSON::Any->encode($trials);
		 $self->cache()->set(
		     $self->key("trials"), $trial_json, $self->cache_expiry()
		 );
		 return $trials;
	     }
	 });

override('retrieve_traits',
	 sub {
	     my $self = shift;
	     if ($self->cache()->exists($self->key("traits"))) {
		 my $traits_json = $self->cache()->get($self->key("traits"));
		 my $traits = JSON::Any->decode($traits_json);
		 return $traits;
	     }
	     else {
		 my $traits = $self->SUPER::retrieve_traits();
		 my $trait_json = JSON::Any->encode($traits);
		 $self->cache()->set(
		     $self->key("traits"), $trait_json, $self->cache_expiry()
		 );
		 return $traits;
	     }
	 });

override('retrieve_years',
	 sub {
	     my $self = shift;
	     if ($self->cache()->exists($self->key("years"))) {
		 my $year_json = $self->cache()->get($self->key("years"));
		 my $years = JSON::Any->decode($year_json);
		 return $years;
	     }
	     else {
		 my $years = $self->SUPER::retrieve_years();
		 my $year_json = JSON::Any->encode($years);
		 $self->cache()->set(
		     $self->key("years"), $year_json, $self->cache_expiry()
		 );
		 return $years;
	     }
	 });



1;
