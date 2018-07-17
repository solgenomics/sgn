use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new(timeout=>30000);
my $response;

# "observations": [
#     {
#       "observationDbId": "153453453",
#       "observationUnitDbId": "333888",
#       "observationVariableDbId": "18020",
#       "collector": "Mr. Technician",
#       "observationTimeStamp": "2015-06-16T00:53:26Z",
#       "value": "55.2"
#     },
#     {
#       "observationDbId": "",
#       "observationUnitDbId": "333888",
#       "observationVariableDbId": "18021",
#       "collector": "Mr. Technician",
#       "observationTimeStamp": "2015-06-16T00:53:26Z",
#       "value": "2.9998"
#     },
#     {
#       "observationDbId": null,
#       "observationUnitDbId": "333888",
#       "observationVariableDbId": "18022",
#       "collector": "Mr. Technician",
#       "observationTimeStamp": "2015-06-16T00:53:26Z",
#       "value": "0.003"
#     }
#   ]

my $plot_id1 = $schema->resultset('Stock::Stock')->find({uniquename=>'test_trial210'})->stock_id;
my $plot_id2 = $schema->resultset('Stock::Stock')->find({uniquename=>'test_trial214'})->stock_id;

my %observations = (
    observations => [
        {
            observationDbId => '',
            observationUnitDbId => $plot_id1,
            observationVariableDbId => '70666',
            collector => 'collector1',
            observationTimestamp => '2015-06-16T00:53:26Z',
            value => '11'
        },
        {
            observationDbId => '',
            observationUnitDbId => $plot_id2,
            observationVariableDbId => '70741',
            collector => 'collector1',
            observationTimestamp => '2015-06-16T00:53:26Z',
            value => '110'
        },
    ]
);

my $j = encode_json \%observations;
$mech->put_ok('http://localhost:3010/brapi/v1/observations', \%observations);
$response = decode_json $mech->content;
print STDERR Dumper $response;

done_testing;
