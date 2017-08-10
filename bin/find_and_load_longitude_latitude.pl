#!/usr/bin/perl

=head1

find_and_load_longitude_latitude.pl - find long and lat for locations in cxgn databases. optionally can store the found lat and long

=head1 SYNOPSIS

    find_and_load_longitude_latitude.pl -I https://cassavabase.org/brapi/v1/locations -O outfile.tsv

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -I input url to get location names from brapi

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

our ($opt_I, $opt_O);

getopts('I:O:');

if (!$opt_I || !$opt_O) {
    pod2usage(-verbose => 2, -message => "Must provide options -I and -O \n");
}


my $req = HTTP::Request->new(GET => $opt_I."?pageSize=10000");
$req->header('content-type' => 'application/json');
my $ua = LWP::UserAgent->new;
my $resp = $ua->request($req)

;
if ($resp->is_success) {
    
    open(my $F, ">", $opt_O) || die "Can't open file ".$opt_O;
    print $F "OriginalName\tLongitude\tLatitude\tCountry\tCountryCode\n";

    my $message = $resp->decoded_content;
    my $message_hash = decode_json $message;
    #print STDERR Dumper $message_hash;
    my $locations = $message_hash->{'result'}->{'data'};

    foreach (@$locations){
        my $name = $_->{'name'};
        my $name_orginal = $name;
        $name =~ s/\s/+/g;
        my $server_endpoint = "https://maps.googleapis.com/maps/api/geocode/json?address=$name";
        $req = HTTP::Request->new(GET => $server_endpoint);
        $req->header('content-type' => 'application/json');
        $ua = LWP::UserAgent->new;
        $resp = $ua->request($req);
        if ($resp->is_success) {
            my $message = $resp->decoded_content;
            my $message_hash = decode_json $message;
            #print STDERR Dumper $message_hash;
            
            my $result = $message_hash->{'results'}->[0];
            my $address_components = $result->{'address_components'};
            
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
            
            print $F $name_orginal."\t".$longitude."\t".$latitude."\t".$country."\t".$country_code."\n";
        }
    }
    
    close($F);
}



