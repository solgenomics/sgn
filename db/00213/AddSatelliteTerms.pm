#!/usr/bin/env perl

=head1 NAME

AddSatelliteTerms

=head1 SYNOPSIS

mx-run AddSatelliteTerms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Terms of the Satellite page (/breeders/satellite):

=over

=item location_fields_geo_json (nd_geolocation_property): the production
fields drawn for a location (farm), a GeoJSON FeatureCollection of polygons
with a name each; reused by every later analysis of the farm.

=item trial_field_geo_json (project_property): the field of a trial drawn on
the map when its plots have no GPS coordinates (GeoJSON Polygon).

=item satellite_analysis (job_type): the background job of the page models.

=item satellite_yield_model (protocol_type): a trained yield model saved from a
run (Breedbase analysis model), used again without calibrating.

=item satellite NDVI, satellite NDRE, satellite EVI: vegetation indices of the
plots measured from Sentinel-2 images (10 m), repeated over the season
(trait_repeat_type time_series, one value per image date).

=back

Running it again changes nothing.

=head1 AUTHOR

Chris Simoes

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddSatelliteTerms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
Adds the satellite page terms: location_fields_geo_json (farm fields), trial_field_geo_json (trial field outline), the satellite_analysis job type, the satellite_yield_model model type and the satellite NDVI / NDRE / EVI time-series traits

has '+prereq' => ( default => sub { [] } );

my $TRAIT_CV = 'satellite_vegetation_index';
my $TRAIT_DB = 'SATIDX';

my @TRAITS = (
    { name => 'satellite NDVI', accession => '0000001', minimum => -1, maximum => 1,
      definition => 'Normalized difference vegetation index (NIR - red) / (NIR + red) of the plot, mean of the cloud-free Sentinel-2 L2A pixels (10 m) covering it on the image date (bands B08, B04).' },
    { name => 'satellite NDRE', accession => '0000002', minimum => -1, maximum => 1,
      definition => 'Normalized difference red-edge index (NIR - red edge) / (NIR + red edge) of the plot, mean of the cloud-free Sentinel-2 L2A pixels covering it on the image date (bands B08 at 10 m, B05 at 20 m).' },
    { name => 'satellite EVI', accession => '0000003', minimum => -1, maximum => undef,
      definition => 'Enhanced vegetation index 2.5 (NIR - red) / (NIR + 6 red - 7.5 blue + 1) of the plot, mean of the cloud-free Sentinel-2 L2A pixels (10 m) covering it on the image date (bands B08, B04, B02).' },
);

sub patch {
    my $self = shift;
    print STDOUT "Executing the patch:\n " . $self->name . ".\n\nDescription:\n  " . $self->description . ".\n\nExecuted by:\n " . $self->username . " .";

    my $schema = Bio::Chado::Schema->connect(sub { $self->dbh->clone });
    my $coderef = sub {
        foreach my $t ([ 'location_fields_geo_json', 'nd_geolocation_property' ], [ 'trial_field_geo_json', 'project_property' ], [ 'satellite_analysis', 'job_type' ], [ 'satellite_yield_model', 'protocol_type' ]) {
            print STDOUT "\ncvterm $t->[0] ($t->[1])\n";
            $schema->resultset('Cv::Cvterm')->create_with({ name => $t->[0], cv => $t->[1] });
        }

        my $prop_type = sub {
            my $name = shift;
            my $row = $schema->resultset('Cv::Cvterm')->search({ 'me.name' => $name, 'cv.name' => 'trait_property' }, { join => 'cv' })->first;
            return $row || $schema->resultset('Cv::Cvterm')->create_with({ name => $name, cv => 'trait_property' });
        };
        foreach my $t (@TRAITS) {
            print STDOUT "trait $t->{name}|$TRAIT_DB:$t->{accession}\n";
            my $trait = $schema->resultset('Cv::Cvterm')->create_with({ name => $t->{name}, cv => $TRAIT_CV, db => $TRAIT_DB, dbxref => $t->{accession} });
            $trait->update({ definition => $t->{definition} });
            my %props = (
                trait_repeat_type => 'time_series',
                trait_format => 'numeric',
                trait_details => 'Sentinel-2 satellite image (Breedbase satellite page)',
                trait_decimal_places => 4,
            );
            $props{trait_minimum} = $t->{minimum} if defined $t->{minimum};
            $props{trait_maximum} = $t->{maximum} if defined $t->{maximum};
            foreach my $p (sort keys %props) {
                my $type = $prop_type->($p);
                my $existing = $schema->resultset('Cv::Cvtermprop')->search({ cvterm_id => $trait->cvterm_id, type_id => $type->cvterm_id })->first;
                if ($existing) { $existing->update({ value => $props{$p} }) }
                else { $schema->resultset('Cv::Cvtermprop')->create({ cvterm_id => $trait->cvterm_id, type_id => $type->cvterm_id, value => $props{$p}, rank => 0 }) }
            }
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        die "Load failed! " . $_ . "\n";
    };
    print STDOUT "\nYou successfully added the satellite terms!\n";
}

1;
