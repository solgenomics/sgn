
=head1 NAME

CXGN::GrowingDegreeDays - helper class for locations

=head1 SYNOPSYS

my $gdd = CXGN::GrowingDegreeDays->new({
    bcs_schema => $schema,
    start_date => "2019-01-13", #YYYY-MM-DD
    end_date => "2019-12-19", #YYYY-MM-DD
    noaa_station_id => "GHCND:US1NCBC0005",
    noaa_ncdc_access_token => $noaa_ncdc_access_token
});
my $temperature_averaged_growing_degree_days = $gdd->get_temperature_averaged_gdd($gdd_base_temperature);

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=head1 METHODS

=cut

package CXGN::GrowingDegreeDays;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use LWP::UserAgent;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'start_date' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'end_date' => (
	isa => 'Str',
	is => 'rw',
    required => 1
);

has 'noaa_station_id' => (
    isa => 'Str',
	is => 'rw',
    required => 1
);

has 'noaa_ncdc_access_token' => (
    isa => 'Str',
	is => 'rw',
    required => 1
);

sub get_temperature_averaged_gdd {
    my $self = shift;
    my $gdd_base_temperature = shift || '50'; #For Maize use 50
    my $result;

    my $ua = LWP::UserAgent->new(
        ssl_opts => { verify_hostname => 0 }
    );
    my $server_endpoint = "https://www.ncdc.noaa.gov/cdo-web/api/v2/data?stationid=".$self->noaa_station_id."&datasetid=GHCND&datatypeid=TMAX&datatypeid=TMIN&startdate=".$self->start_date."&enddate=".$self->end_date;
    print STDERR $server_endpoint."\n";
    my $resp = $ua->get($server_endpoint, "token"=>$self->noaa_ncdc_access_token);

    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $message_hash = decode_json $message;
        print STDERR Dumper $message_hash;
    }
    else {
        print STDERR Dumper $resp;
    }

    return $result;
}

1;

