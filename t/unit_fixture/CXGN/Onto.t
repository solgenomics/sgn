
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Onto;
use SGN::Model::Cvterm;
use Test::WWW::Mechanize;
use JSON;

my $mech = Test::WWW::Mechanize->new;
my $json = JSON->new->allow_nonref;

my $t = SGN::Test::Fixture->new();
my $schema = $t->bcs_schema();

my $onto = CXGN::Onto->new( { schema => $t->bcs_schema() });

my $cv_type = 'attribute_ontology';
my @results = $onto->get_root_nodes($cv_type);
#print STDERR "test 1 results " .Dumper @results;

is_deeply(@results, [
               59,
               'CHEBI:00000 chebi_compounds'
             ], 'onto get root nodes test');

=for comment
my $cv_id = 58; # CASSTISS ontology with cvprop 'object'
@results = $onto->get_terms($cv_id);
print STDERR "test 2 results: @results";
my @cass_tissues = ["[77181,'cass fibrous root|CASSTISS:0000011']",
                    "[77176,'cass lower leaf|CASSTISS:0000006']",
                    "[77171,'cass lower stem bark|CASSTISS:0000010']",
                    "[77174,'cass lower stem whole|CASSTISS:0000009']",
                    "[77178,'cass pre-storage root|CASSTISS:0000012']",
                    "[77180,'cass sink leaf|CASSTISS:0000004']",
                    "[77170,'cass source leaf|CASSTISS:0000005']",
                    "[77168,'cass storage root|CASSTISS:0000013']",
                    "[77172,'cass upper stem|CASSTISS:0000007']"];
                    # problem with this data structure
is_deeply(@results, @cass_tissues, 'onto get terms test');
=cut

my @allowed_composed_cvs = ('trait','toy');
my $composable_cvterm_delimiter = '|';
my $composable_cvterm_format = 'concise';
my $traits1 = SGN::Model::Cvterm->get_traits_from_component_categories($t->bcs_schema(), \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
    object => [],
    attribute => [],
    method => [],
    unit => [],
    trait => [70775,76555],
    tod => [],
    toy => [77526,77499],
    gen => [],
});
#print STDERR Dumper $traits1;
is_deeply($traits1, {
          'existing_traits' => [],
          'new_traits' => [
                            [
                              [
                                70775,
                                77526
                              ],
                              'anthocyanin pigmentation visual rating 0-3|month 1'
                            ],
                            [
                              [
                                70775,
                                77499
                              ],
                              'anthocyanin pigmentation visual rating 0-3|month 10'
                            ],
                            [
                              [
                                76555,
                                77526
                              ],
                              'ease of harvest assessment 1-3|month 1'
                            ],
                            [
                              [
                                76555,
                                77499
                              ],
                              'ease of harvest assessment 1-3|month 10'
                            ]
                          ]
        }, 'check composed trait creation 1');

@allowed_composed_cvs = ('trait','toy','tod','object');
$composable_cvterm_delimiter = '||';
$composable_cvterm_format = 'concise';
my $traits2 = SGN::Model::Cvterm->get_traits_from_component_categories($t->bcs_schema(), \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
  object => [77176, 77180],
  attribute => [],
  method => [],
  unit => [],
  trait => [70775,76555],
  tod => [77536],
  toy => [77526,77499],
  gen => [],
});
#print STDERR Dumper $traits2;
is_deeply($traits2, {
          'existing_traits' => [],
          'new_traits' => [
                            [
                              [
                                70775,
                                77499,
                                77536,
                                77176
                              ],
                              'anthocyanin pigmentation visual rating 0-3||month 10||end of day||cass lower leaf'
                            ],
                            [
                              [
                                70775,
                                77499,
                                77536,
                                77180
                              ],
                              'anthocyanin pigmentation visual rating 0-3||month 10||end of day||cass sink leaf'
                            ],
                            [
                              [
                                70775,
                                77526,
                                77536,
                                77176
                              ],
                              'anthocyanin pigmentation visual rating 0-3||month 1||end of day||cass lower leaf'
                            ],
                            [
                              [
                                70775,
                                77526,
                                77536,
                                77180
                              ],
                              'anthocyanin pigmentation visual rating 0-3||month 1||end of day||cass sink leaf'
                            ],
                            [
                              [
                                76555,
                                77499,
                                77536,
                                77176
                              ],
                              'ease of harvest assessment 1-3||month 10||end of day||cass lower leaf'
                            ],
                            [
                              [
                                76555,
                                77499,
                                77536,
                                77180
                              ],
                              'ease of harvest assessment 1-3||month 10||end of day||cass sink leaf'
                            ],
                            [
                              [
                                76555,
                                77526,
                                77536,
                                77176
                              ],
                              'ease of harvest assessment 1-3||month 1||end of day||cass lower leaf'
                            ],
                            [
                              [
                                76555,
                                77526,
                                77536,
                                77180
                              ],
                              'ease of harvest assessment 1-3||month 1||end of day||cass sink leaf'
                            ]
                          ]
        }, 'check composed trait creation 2');

@allowed_composed_cvs = ('trait','toy','tod','object');
$composable_cvterm_delimiter = '||';
$composable_cvterm_format = 'extended';
my $traits3 = SGN::Model::Cvterm->get_traits_from_component_categories($t->bcs_schema(), \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
  object => [77171, 77174],
  attribute => [],
  method => [],
  unit => [],
  trait => [70775,76555],
  tod => [77536],
  toy => [77526,77499],
  gen => [],
});
#print STDERR Dumper $traits3;
is_deeply($traits3, {
          'existing_traits' => [],
          'new_traits' => [
                            [
                              [
                                70775,
                                77499,
                                77536,
                                77171
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                70775,
                                77499,
                                77536,
                                77174
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ],
                            [
                              [
                                70775,
                                77526,
                                77536,
                                77171
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                70775,
                                77526,
                                77536,
                                77174
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ],
                            [
                              [
                                76555,
                                77499,
                                77536,
                                77171
                              ],
                              'ease of harvest assessment 1-3|CO_334:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                76555,
                                77499,
                                77536,
                                77174
                              ],
                              'ease of harvest assessment 1-3|CO_334:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ],
                            [
                              [
                                76555,
                                77526,
                                77536,
                                77171
                              ],
                              'ease of harvest assessment 1-3|CO_334:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                76555,
                                77526,
                                77536,
                                77174
                              ],
                              'ease of harvest assessment 1-3|CO_334:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ]
                          ]
        }, 'check composed trait creation 3');

my $new_traits2 = $traits2->{new_traits};
my %new_composed_terms2;
foreach (@$new_traits2){
  $new_composed_terms2{$_->[1]} = join ',', @{$_->[0]};
}
my $results2 = $onto->store_composed_term(\%new_composed_terms2);
#print STDERR Dumper $results2;
my @results2_names;
foreach (@$results2){
    ok($_->[0], 'check that cvterm_id saved');
    push @results2_names, $_->[1];
}
print STDERR Dumper \@results2_names;
is_deeply(\@results2_names, [
          'anthocyanin pigmentation visual rating 0-3||month 10||end of day||cass lower leaf|COMP:0000014',
          'anthocyanin pigmentation visual rating 0-3||month 10||end of day||cass sink leaf|COMP:0000015',
          'anthocyanin pigmentation visual rating 0-3||month 1||end of day||cass lower leaf|COMP:0000016',
          'anthocyanin pigmentation visual rating 0-3||month 1||end of day||cass sink leaf|COMP:0000017',
          'ease of harvest assessment 1-3||month 10||end of day||cass lower leaf|COMP:0000018',
          'ease of harvest assessment 1-3||month 10||end of day||cass sink leaf|COMP:0000019',
          'ease of harvest assessment 1-3||month 1||end of day||cass lower leaf|COMP:0000020',
          'ease of harvest assessment 1-3||month 1||end of day||cass sink leaf|COMP:0000021'
        ], 'check store composed terms 2');

my $new_traits3 = $traits3->{new_traits};
my %new_composed_terms3;
foreach (@$new_traits3){
    $new_composed_terms3{$_->[1]} = join ',', @{$_->[0]};
}
my $results3 = $onto->store_composed_term(\%new_composed_terms3);
#print STDERR Dumper $results3;
my @results3_names;
foreach (@$results3){
    ok($_->[0], 'check that cvterm_id saved');
    push @results3_names, $_->[1];
}
print STDERR Dumper \@results3_names;
is_deeply(\@results3_names, [
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000022',
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000023',
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000024',
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000025',
          'ease of harvest assessment 1-3|CO_334:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000026',
          'ease of harvest assessment 1-3|CO_334:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000027',
          'ease of harvest assessment 1-3|CO_334:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000028',
          'ease of harvest assessment 1-3|CO_334:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000029'
        ], 'test save composed terms 3');

my $traits3_duplicate = SGN::Model::Cvterm->get_traits_from_component_categories($t->bcs_schema(), \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
  object => [77171, 77174],
  attribute => [],
  method => [],
  unit => [],
  trait => [70775,76555],
  tod => [77536],
  toy => [77526,77499],
  gen => [],
});
#print STDERR Dumper $traits3_duplicate;
my $new_traits = $traits3_duplicate->{new_traits};
my $existing_traits = $traits3_duplicate->{existing_traits};
my @check_names;
foreach (@$existing_traits){
    ok($_->[0], 'check that cvterm_id saved');
    push @check_names, $_->[1];
}
is_deeply($new_traits, [], 'check that duplicate traits are not added');
print STDERR Dumper \@check_names;
is_deeply(\@check_names, [
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000022',
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000023',
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000024',
          'anthocyanin pigmentation visual rating 0-3|CO_334:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000025',
          'ease of harvest assessment 1-3|CO_334:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000026',
          'ease of harvest assessment 1-3|CO_334:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000027',
          'ease of harvest assessment 1-3|CO_334:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000028',
          'ease of harvest assessment 1-3|CO_334:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000029'
        ], 'check that duplicate traits are separated from new_traits');


## Test adding observation variables, traits, methods, scales

my $response;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $q = "Select db_id FROM db where name = 'CO_334';";
my $sth = $schema->storage->dbh->prepare($q);
$sth->execute();
my ($db_id) = $sth->fetchrow_array();

$mech->post_ok('http://localhost:3010/ajax/onto/store_trait_method_scale_observation_variable',
    [
        "sgn_session_id"=>$sgn_session_id,
        "selected_observation_variable_db_id"=> $db_id,
        "new_observation_variable_name"=> "new observation variable name",
        "new_observation_variable_definition"=> "new observation variable definition",
        "selected_trait_db_id"=> $db_id,
        "selected_trait_cvterm_id"=> undef,
        "new_trait_name"=> "new trait name",
        "new_trait_definition"=> "new trait definition",
        "selected_method_db_id"=> $db_id,
        "selected_method_cvterm_id"=> undef,
        "new_method_name"=> "new method name",
        "new_method_definition"=> "new method definition",
        "selected_scale_db_id"=> $db_id,
        "selected_scale_cvterm_id"=> undef,
        "new_scale_name"=> "new scale name",
        "new_scale_definition"=> "new scale definition",
        "new_scale_format"=> "",
        "new_scale_minimum"=> "",
        "new_scale_maximum"=> "",
        "new_scale_default"=> "",
        "new_scale_categories"=> ""
    ]
);
$response = decode_json $mech->content;
print STDERR Dumper $response;
ok($response->{success});

$q = "Select cvterm_id FROM cvterm where name = 'new trait name';";
$sth = $schema->storage->dbh->prepare($q);
$sth->execute();
my ($trait_cvterm_id) = $sth->fetchrow_array();

$mech->post_ok('http://localhost:3010/ajax/onto/store_trait_method_scale_observation_variable',
    [
        "selected_observation_variable_db_id"=> $db_id,
        "new_observation_variable_name"=> "new observation variable name 2",
        "new_observation_variable_definition"=> "new observation variable definition 2",
        "selected_trait_db_id"=> $db_id,
        "selected_trait_cvterm_id"=> $trait_cvterm_id,
        "new_trait_name"=> "",
        "new_trait_definition"=> "",
        "selected_method_db_id"=> $db_id,
        "selected_method_cvterm_id"=> "",
        "new_method_name"=> "new method name 2",
        "new_method_definition"=> "new method definition 2",
        "selected_scale_db_id"=> $db_id,
        "selected_scale_cvterm_id"=> "",
        "new_scale_name"=> "new scale name 2",
        "new_scale_definition"=> "new scale definition 2",
        "new_scale_format"=> "",
        "new_scale_minimum"=> "",
        "new_scale_maximum"=> "",
        "new_scale_default"=> "",
        "new_scale_categories"=> ""
    ]
);
$response = decode_json $mech->content;
print STDERR Dumper $response;
ok($response->{success});

$mech->post_ok('http://localhost:3010/ajax/onto/store_ontology_identifier',
    [
        "sgn_session_id"=>$sgn_session_id,
        "ontology_name"=> "NewOntology1",
        "ontology_description"=> "new ontology",
        "ontology_identifier"=> "NOO1",
        "ontology_type"=> "method_ontology",
    ]
);
$response = decode_json $mech->content;
print STDERR Dumper $response;
ok($response->{success});

done_testing();
