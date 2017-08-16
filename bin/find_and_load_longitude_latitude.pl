#!/usr/bin/perl

=head1

find_and_load_longitude_latitude.pl - find long/lat, country_name, country_code, and address for locations in cxgn databases. optionally can directly update or create the found lat/long, country_name, country_code, and address into database

=head1 SYNOPSIS

    find_and_load_longitude_latitude.pl -H localhost -D cxgn -O outfile.tsv -s

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -H localhost
  -D database
  -O outfile.csv
  -s save found lat/long, country_name, country_code, and address into database

=head1 DESCRIPTION


=head1 AUTHOR

Nicolas Morales nm529@cornell.edu

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Spreadsheet::ParseExcel;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use LWP::UserAgent;
use JSON;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_O, $opt_s);

getopts('H:D:O:s');

if (!$opt_H || !$opt_D || !$opt_O) {
    pod2usage(-verbose => 2, -message => "Must provide options -H, -D, and -O \n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;

my $dbh = CXGN::DB::InsertDBH->new({
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

my $country_name_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "country_name", "geolocations_property")->cvterm_id();
my $country_code_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "country_code", "geolocations_property")->cvterm_id();
my $address_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "geolocation address", "geolocation_property")->cvterm_id();

my $geolocation_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();

open(my $F, ">", $opt_O) || die "Can't open file ".$opt_O;
print $F "LocationName\tLongitudeInDB\tLatitudeInDB\tFoundLongitude\tFoundLatitude\tFoundCountry\tFoundCountryCode\tFoundAddress\n";

while(my$r = $geolocation_rs->next){

    my $name = $r->description;
    $name =~ s/\s/+/g;
    my $server_endpoint = "http://maps.googleapis.com/maps/api/geocode/json?address=$name";
    my $req = HTTP::Request->new(GET => $server_endpoint);
    $req->header('content-type' => 'application/json');
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $message_hash = decode_json $message;
        #print STDERR Dumper $message_hash;

        my $result = $message_hash->{'results'}->[0];
        my $address_components = $result->{'address_components'};
        my $formatted_address = $result->{'formatted_address'};

        my $country = "";
        my $country_code = "";
        foreach my $a (@$address_components){
            my $types = $a->{'types'};
            my %type_hash = map {$_ => 1} @$types;
            if (exists($type_hash{'country'})){
                if(exists($a->{'long_name'})){
                    $country = $a->{'long_name'};
                }
                if(exists($a->{'short_name'})){
                    $country_code = $a->{'short_name'};
                }
            }
        }


        my $location = $result->{'geometry'}->{'location'};
        my $latitude = $location->{'lat'};
        my $longitude = $location->{'lng'};
        print STDERR "Lat: $latitude Long: $longitude\n";

        print $F $r->description()."\t".$r->longitude()."\t".$r->latitude()."\t".$longitude."\t".$latitude."\t".$country."\t".$country_code."\t".$formatted_address."\n";

        if ($opt_s){
            if($longitude && $latitude){
                my %update = (longitude=>$longitude, latitude=>$latitude);
                $r->update(\%update);
            }
            if($country){
                my $country_name_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
                    nd_geolocation_id=>$r->nd_geolocation_id(),
                    type_id=>$country_name_cvterm_id,
                });
                if ($country_name_prop){
                    $country_name_prop->update({value=>$country})
                } else {
                    $country_name_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({
                        nd_geolocation_id=>$r->nd_geolocation_id(),
                        type_id=>$country_name_cvterm_id,
                        value=>$country
                    });
                }
            }
            if($country_code){
                my $country_code_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
                    nd_geolocation_id=>$r->nd_geolocation_id(),
                    type_id=>$country_code_cvterm_id,
                });
                if ($country_code_prop){
                    $country_code_prop->update({value=>$country_code})
                } else {
                    $country_code_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({
                        nd_geolocation_id=>$r->nd_geolocation_id(),
                        type_id=>$country_code_cvterm_id,
                        value=>$country_code
                    });
                }
            }
            if($formatted_address){
                my $formatted_address_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
                    nd_geolocation_id=>$r->nd_geolocation_id(),
                    type_id=>$address_cvterm_id,
                });
                if ($formatted_address_prop){
                    $formatted_address_prop->update({value=>$formatted_address})
                } else {
                    $formatted_address_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({
                        nd_geolocation_id=>$r->nd_geolocation_id(),
                        type_id=>$address_cvterm_id,
                        value=>$formatted_address
                    });
                }
            }
        }
    }
}

close($F);
