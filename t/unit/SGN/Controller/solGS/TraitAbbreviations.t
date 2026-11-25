use strict;
use warnings;
use utf8;

use Test::More;
use Encode;
use SGN::Controller::solGS::Utils;
use SGN::Controller::solGS::solGS;

# R scripts read the trait abbreviations as column names, so an abbreviation
# must be a name that R keeps as it is (#6527).
my @cases = (
    ['Grain moisture content - % [0001198]', 'GMC_P_0001198', 'brackets of a Crop Ontology variable name'],
    ['height[cm]',                           'height_cm',     'brackets in a one-word name'],
    ['A+B',                                  'A_B',           'other punctuation'],
    ['100 seed weight',                      'X100SW',        'a leading digit'],
    ['nitrogen application',                 'NA_',           'an R reserved word'],
    ['dry matter content percentage',        'DMCP',          'a plain name does not change'],
    ['Plot harvested area - m2',             'PHA_M',         'an underscore from a dash stays'],
    ['plant height (cm)',                    'PH_C',          'a unit in parentheses does not change'],
    ['pH',                                   'pH',            'a one-word name keeps its case'],
    ['Урожайність т/га',                     'УРОЖАЙНІСТЬТГА', 'letters of other alphabets stay'],
    ['pH–soil',                              'pH_soil',       'punctuation outside ASCII'],
    ['Brix°',                                'Brix',          'a symbol outside ASCII'],
    ['++',                                   'X',             'a name of punctuation only is not empty'],
    ['pH.water',                             'pH.water',      'a name R keeps does not change'],
    ['Grain yield -',                        'GY_',           'a trailing underscore R keeps stays'],
);

for my $case (@cases) {
    my ($name, $expected, $label) = @$case;
    is(SGN::Controller::solGS::Utils->abbreviate_term($name), $expected, $label);
}

is(SGN::Controller::solGS::Utils->abbreviate_term(Encode::encode('UTF-8', 'Урожайність т/га')),
    Encode::encode('UTF-8', 'Урожайністьтга'), 'bytes of a name that is not decoded stay as they are');

for my $case (grep { $_->[0] !~ /[^\x00-\x7F]/ } @cases) {
    like(SGN::Controller::solGS::Utils->abbreviate_term($case->[0]), qr/^[A-Za-z][A-Za-z0-9._]*$/,
        "$case->[0]: a syntactic R name");
}

is(SGN::Controller::solGS::solGS->format_phenotype_dataset_headers(
        join("\t", 'germplasmName', 'replicate', 'Grain moisture content - % [0001198]|CO_321:0001198', 'height[cm]'),
        ['germplasmName', 'replicate']),
    "germplasmName\treplicate\tGMC_P_0001198\theight_cm",
    'the phenotype file header has the same names');

done_testing();
