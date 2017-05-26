
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Onto;
use SGN::Model::Cvterm;

my $t = SGN::Test::Fixture->new();
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
                              'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                70775,
                                77499,
                                77536,
                                77174
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ],
                            [
                              [
                                70775,
                                77526,
                                77536,
                                77171
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                70775,
                                77526,
                                77536,
                                77174
                              ],
                              'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ],
                            [
                              [
                                76555,
                                77499,
                                77536,
                                77171
                              ],
                              'ease of harvest assessment 1-3|CO:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                76555,
                                77499,
                                77536,
                                77174
                              ],
                              'ease of harvest assessment 1-3|CO:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                            ],
                            [
                              [
                                76555,
                                77526,
                                77536,
                                77171
                              ],
                              'ease of harvest assessment 1-3|CO:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                            ],
                            [
                              [
                                76555,
                                77526,
                                77536,
                                77174
                              ],
                              'ease of harvest assessment 1-3|CO:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
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
is_deeply($results2, [
          [
            77560,
            'anthocyanin pigmentation visual rating 0-3||month 10||end of day||cass lower leaf|COMP:0000014'
          ],
          [
            77561,
            'anthocyanin pigmentation visual rating 0-3||month 10||end of day||cass sink leaf|COMP:0000015'
          ],
          [
            77562,
            'anthocyanin pigmentation visual rating 0-3||month 1||end of day||cass lower leaf|COMP:0000016'
          ],
          [
            77563,
            'anthocyanin pigmentation visual rating 0-3||month 1||end of day||cass sink leaf|COMP:0000017'
          ],
          [
            77564,
            'ease of harvest assessment 1-3||month 10||end of day||cass lower leaf|COMP:0000018'
          ],
          [
            77565,
            'ease of harvest assessment 1-3||month 10||end of day||cass sink leaf|COMP:0000019'
          ],
          [
            77566,
            'ease of harvest assessment 1-3||month 1||end of day||cass lower leaf|COMP:0000020'
          ],
          [
            77567,
            'ease of harvest assessment 1-3||month 1||end of day||cass sink leaf|COMP:0000021'
          ]
        ], 'check store composed terms 2');

my $new_traits3 = $traits3->{new_traits};
my %new_composed_terms3;
foreach (@$new_traits3){
    $new_composed_terms3{$_->[1]} = join ',', @{$_->[0]};
}
my $results3 = $onto->store_composed_term(\%new_composed_terms3);
#print STDERR Dumper $results3;
is_deeply($results3, [
          [
            77568,
            'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000022'
          ],
          [
            77569,
            'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000023'
          ],
          [
            77570,
            'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000024'
          ],
          [
            77571,
            'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000025'
          ],
          [
            77572,
            'ease of harvest assessment 1-3|CO:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000026'
          ],
          [
            77573,
            'ease of harvest assessment 1-3|CO:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000027'
          ],
          [
            77574,
            'ease of harvest assessment 1-3|CO:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010|COMP:0000028'
          ],
          [
            77575,
            'ease of harvest assessment 1-3|CO:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009|COMP:0000029'
          ]
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
is_deeply($traits3_duplicate, {
          'new_traits' => [],
          'existing_traits' => [
                                 [
                                   77568,
                                   'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                                 ],
                                 [
                                   77569,
                                   'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                                 ],
                                 [
                                   77570,
                                   'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                                 ],
                                 [
                                   77571,
                                   'anthocyanin pigmentation visual rating 0-3|CO:0000103||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                                 ],
                                 [
                                   77572,
                                   'ease of harvest assessment 1-3|CO:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                                 ],
                                 [
                                   77573,
                                   'ease of harvest assessment 1-3|CO:0000225||month 10|TIME:0000069||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                                 ],
                                 [
                                   77574,
                                   'ease of harvest assessment 1-3|CO:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem bark|CASSTISS:0000010'
                                 ],
                                 [
                                   77575,
                                   'ease of harvest assessment 1-3|CO:0000225||month 1|TIME:0000060||end of day|TIME:0000003||cass lower stem whole|CASSTISS:0000009'
                                 ]
                               ]
        }, 'check that duplicate traits are separated from new_traits');


done_testing();
