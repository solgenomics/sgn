
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use Spreadsheet::Read;
use utf8;

my $f = SGN::Test::Fixture->new();
$f->get_db_stats();

my $schema = $f->bcs_schema;

for my $extension ("xls", "xlsx") {

    my $trial_id = $schema->resultset("Project::Project")->find({ name => 'test_trial' })->project_id();
    my @trait_list = ("dry matter content percentage|CO_334:0000092", "fresh root weight|CO_334:0000012");
    my $tempfile = "/tmp/test_create_pheno_datacollector.$extension";
    my $format = 'DataCollectorExcel';

    my $create_spreadsheet = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trial_id   => $trial_id,
        trait_list => \@trait_list,
        filename   => $tempfile,
        format     => $format,
    });

    $create_spreadsheet->download();

    my $contents = ReadData $tempfile;

    #print STDERR Dumper \@contents;

    #print STDERR Dumper @contents->[0]->[0];
    is($contents->[0]->{'type'}, "$extension", "check that type of file is correct");
    is($contents->[0]->{'sheets'}, '8', "check that type of file is correct");

    my $columns_1 = $contents->[1]->{'cell'};
    #print STDERR Dumper scalar(@$columns_1);
    ok(scalar(@$columns_1) == 3, "check number of columns in first sheet.");

    my $columns_2 = $contents->[2]->{'cell'};
    #print STDERR Dumper scalar(@$columns_2);
    ok(scalar(@$columns_2) == 3, "check number of columns in second sheet.");

    my $columns_3 = $contents->[3]->{'cell'};
    #print STDERR Dumper scalar(@$columns_3);
    ok(scalar(@$columns_3) == 14, "check number of columns in third sheet.");

    my $columns_4 = $contents->[4]->{'cell'};
    #print STDERR Dumper scalar(@$columns_4);
    ok(scalar(@$columns_4) == 14, "check number of columns in fourth sheet.");

    my $columns_5 = $contents->[5]->{'cell'};
    #print STDERR Dumper scalar(@$columns_5);
    ok(scalar(@$columns_5) == 15, "check number of columns in fifth sheet.");

    my $columns_6 = $contents->[6]->{'cell'};
    #print STDERR Dumper scalar(@$columns_6);
    ok(scalar(@$columns_6) == 10, "check number of columns in sixth sheet.");

    my $columns_7 = $contents->[7]->{'cell'};
    #print STDERR Dumper scalar(@$columns_7);
    ok(scalar(@$columns_7) == 7, "check number of columns in seventh sheet.");

    my $columns_8 = $contents->[8]->{'cell'};
    #print STDERR Dumper scalar(@$columns_8);
    ok(scalar(@$columns_8) == 9, "check number of columns in eigth sheet.");

    is_deeply($columns_1, [
        [],
        [
            undef,
            'Factor',
            'Short name or Title',
            'Version',
            'Crop',
            'Type of Trial',
            'Comments',
            'Begin date',
            'End date',
            'Leader',
            'Collaborators',
            'Site short name',
            'Agroecological zone',
            'CIP Region',
            'Continent',
            'Country',
            'Admin1',
            'Admin2',
            'Admin3',
            'Locality',
            'Elevation',
            'Latitude',
            'Longitude',
            'Owner',
            'Publisher',
            'Type',
            'Format',
            'Identifier',
            'Language',
            'Relation',
            'License',
            'Audience',
            'Provenance',
            'Embargo till',
            'Quality Indicator',
            'Status',
            'Donor',
            'Project name',
            'Project start',
            'Project end'
        ],
        [
            undef,
            'Value',
            undef,
            'V.2.2.0',
            'sweetpotato',
            'yield',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            'International Potato Center',
            'International Potato Center',
            'dataset',
            'Excel 2003',
            'to be done: doi',
            'en',
            'NA',
            "\x{a9} International Potato Center",
            'Breeder',
            'original',
            '2012-12-31',
            'NA',
            'draft'
        ]
    ], "check contents of first page.");

    is_deeply($columns_2, [
        [],
        [
            undef,
            'Factor',
            'Experimental design',
            'Genetic design',
            'Labels for factor genotypes',
            'Number of repetitions or blocks',
            'Block size (applicable for BIBD only)',
            'Plot start number',
            'Number of plants planted per plot',
            'Number of rows per plot',
            'Number of plants per row',
            'Plot size (m2)',
            'Distance between plants (m)',
            'Distance between rows (m)',
            'Planting density (plants/Ha)',
            'Row direction',
            'Planting mode',
            'Area of the experiment',
            'Additional factor name',
            'Labels for additional factor, level 1',
            'Labels for additional factor, level 2',
            'Labels for additional factor, level 3',
            'Labels for additional factor, level 4',
            'Labels for additional factor, level 5',
            'Latitude corner 1',
            'Longitude corner 1',
            'Latitude corner 2',
            'Longitude corner 2',
            'Latitude corner 3',
            'Longitude corner 3',
            'Latitude corner 4',
            'Longitude corner 4',
            'Initial sprout length (average)',
            'Field history cropping season t-1',
            'Field history cropping season t-2',
            'Field history cropping season t-3',
            'Field history cropping season t-4',
            'Field history cropping season t-5',
            'Sensor Elevation weather data (meters)'
        ],
        [
            undef,
            'Value',
            'Randomized Complete Block Design (RCBD)',
            undef,
            'Institutional number',
            '2',
            undef,
            undef,
            '10',
            '1',
            '10',
            '2.7',
            '0.3',
            '0.9',
            '37,037'
        ]
    ], "check contents of second page");

    is_deeply($columns_3, [
        [],
        [
            undef,
            'Numeration'
        ],
        [
            undef,
            'Control'
        ],
        [
            undef,
            'Institutional number'
        ],
        [
            undef,
            'Clone or variety name'
        ],
        [
            undef,
            'Code of clone'
        ],
        [
            undef,
            'Family Institutional number'
        ],
        [
            undef,
            'Female Institutional number'
        ],
        [
            undef,
            'Female code'
        ],
        [
            undef,
            'Male Institutional number'
        ],
        [
            undef,
            'Male code'
        ],
        [
            undef,
            'Seed source1'
        ],
        [
            undef,
            'References to simultaneous trials'
        ],
        [
            undef,
            'References to previous trials'
        ]
    ], "check contents of third page.");

    is_deeply($columns_4, [
        [],
        [
            undef,
            'Variables',
            'Date',
            'Requester',
            'Operator',
            'Latitude',
            'Longitude',
            'Laboratory code',
            'Sample code',
            'Field code',
            'pH',
            'Electrical conductivity',
            'Calcium Carbonate',
            'Organic matter',
            'Total nitrogen',
            'Phosphorus',
            'Potassium',
            'Sand',
            'Lime',
            'Clay',
            'Soil texture',
            'Cation Exchange Capacity',
            'Exchangeable Calcium',
            'Exchangeable Magnesium',
            'Exchangeable Potassium',
            'Exchangeable Sodium',
            'Aluminium + hidrogenum',
            'Total cations',
            'Total bases',
            'Base Saturation',
            'Exchangeable Acidity',
            'Anion Exchange capacity',
            'Iron',
            'Copper',
            'Zinc',
            'Boron',
            'Manganese',
            'Calcium',
            'Magnesium',
            'Potassium',
            'Sodium',
            'Chloride',
            'Carbonate',
            'Bicarbonate',
            'Nitrate',
            'Sulfate',
            'Phosphate'
        ],
        [
            undef,
            'Abbreviation',
            'DATE',
            'RQSTR',
            'OPRTR',
            'LATD',
            'LOND',
            'LabCo',
            'SCo',
            'FDCo',
            'pH',
            'EC',
            'CaCO3',
            'OM',
            'TN',
            'P',
            'K',
            'Sand',
            'Silt',
            'Clay',
            'Soil texture',
            'CEC',
            'ExCa2',
            'ExMg2',
            'ExK',
            'ExNa',
            'ExAl3_H',
            'TCA',
            'TBAS',
            'BS',
            'CCA',
            'AEC',
            'Fe',
            'Cu',
            'Zn',
            'B',
            'Mn',
            'Ca',
            'Mg',
            'K',
            'Na',
            'Cl',
            'CO3',
            '(CO3)2',
            'NO3',
            'SO4',
            'PO4'
        ],
        [
            undef,
            'Unit',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '1 dS/m= 1 mmho/cm',
            'percentage',
            'percentage',
            'percentage',
            'ppm',
            'ppm',
            'percentage',
            'percentage',
            'percentage',
            'percentage',
            'Meq/100g',
            'Meq/100g',
            'Meq/100g',
            'Meq/100g',
            'Meq/100g',
            'Meq/100g',
            'Meq/100g',
            'Meq/100g',
            'percentage',
            'percentage',
            'Meq/100g',
            'ppm',
            'ppm',
            'ppm',
            'ppm(*)',
            'ppm',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L',
            'meq/L'
        ],
        [
            undef,
            'Data1'
        ],
        [
            undef,
            'Data2'
        ],
        [
            undef,
            'Data3'
        ],
        [
            undef,
            'Data4'
        ],
        [
            undef,
            'Data5'
        ],
        [
            undef,
            'Data6'
        ],
        [
            undef,
            'Data7'
        ],
        [
            undef,
            'Data8'
        ],
        [
            undef,
            'Data9'
        ],
        [
            undef,
            'Data10'
        ]
    ], "check contents of fourth page");

    is_deeply($columns_5, [
        [],
        [
            undef,
            'Date of weather observation'
        ],
        [
            undef,
            'Hour of weather observation'
        ],
        [
            undef,
            'Rainfall (mm)'
        ],
        [
            undef,
            "Average temperature (\x{b0}C)"
        ],
        [
            undef,
            "Minimum temperature (\x{b0}C)"
        ],
        [
            undef,
            "Maximum temperature (\x{b0}C)"
        ],
        [
            undef,
            "Temperature amplitude \x{b0}C "
        ],
        [
            undef,
            'Relative humidity (%)'
        ],
        [
            undef,
            'Solar Radiation (w/m2)'
        ],
        [
            undef,
            'Barometric Pressure (mm)'
        ],
        [
            undef,
            "Dew point (\x{b0}C) "
        ],
        [
            undef,
            'Wind speed (m/s)'
        ],
        [
            undef,
            'Gust speed'
        ],
        [
            undef,
            'Wind direction'
        ]
    ], "check contents of fifth page");

    is_deeply($columns_6, [
        [],
        [
            undef,
            'Intervention category',
            'Preparation',
            'Harvest ',
            'Harvest'
        ],
        [
            undef,
            'Intervention type',
            'Planting',
            'Vine cutting / killing',
            'Harvest'
        ],
        [
            undef,
            'Date'
        ],
        [
            undef,
            'Operator'
        ],
        [
            undef,
            'Observations'
        ],
        [
            undef,
            'Active Ingredient'
        ],
        [
            undef,
            'Product concentration '
        ],
        [
            undef,
            'Dose of application'
        ],
        [
            undef,
            'Uncertainty of Measurement'
        ]
    ], "check contents of sixth page");

    is_deeply($columns_7, [
        [],
        [
            undef,
            'Factor Variables',
            'Number of plants planted',
            'Number of plants established',
            'Virus symptoms (1-9), first evaluation',
            'Virus symptoms (1-9), second evaluation',
            'Alternaria symptoms (1-9), first evaluation',
            'Alternaria symptoms (1-9), second evaluation',
            'Vine vigor (1-9), first evaluation',
            'Vine weight',
            'Number of plants harvested',
            'Number of plants with roots',
            'Number of commercial roots',
            'Number of non commercial roots',
            'Commercial root weight',
            'Non commercial root weight',
            'Root primary flesh color',
            'Root secondary flesh color',
            'Storage root skin color',
            'Storage root flesh color',
            'Root size (1-9)',
            'Root form (1-9)',
            'Root defects (1-9)',
            'Weevil damage (1-9), first evaluation',
            'Fresh weight of roots for dry matter assessment',
            'Dry weight of DMF samples',
            'Root fiber (1-9), first determination',
            'Root sugar (1-9), first determination',
            'Root starch (1-9), first determination',
            'Fresh weight vines for dry matter assessment',
            'Dry weight of DMVD samples',
            'Cooked fiber (1-9), first evaluation',
            'Cooked sugars (1-9), first evaluation',
            'Cooked starch (1-9), first evaluation',
            'Cooked taste (1-9), first evaluation',
            'Cooked appearance (1-9), first evaluation',
            'Vine vigor2 (1-9), second evaluation',
            'Virus symptoms (1-9), third evaluation',
            'Weevil damage2 (1-9), second evaluation',
            'Root fiber (1-9), second determination',
            'Root sugar (1-9), second determination',
            'Root starch (1-9), second determination',
            'Cooked fiber (1-9), second evaluation',
            'Cooked sugars (1-9), second evaluation',
            'Cooked starch (1-9), second evaluation',
            'Cooked taste (1-9), second evaluation',
            'Cooked appearance (1-9), second evaluation',
            'Root sprouting (1-9)',
            'Protein',
            'Fe',
            'Zn',
            'Ca',
            'Mg',
            'Beta carotene',
            'Total carotenoids',
            'Starch',
            'Fructose',
            'Glucose',
            'Sucrose',
            'Maltose',
            'Total root weight',
            'Commercial root yield t/ha',
            'Total root yield t/ha',
            'Average commercial root weight',
            'Number of roots per plant',
            'Yield per plant Kg',
            'Percent marketable roots (commercial index)',
            'Harvest index',
            'Harvest sowing index  (survival)',
            'Biomass yield',
            'Foliage total yield t/ha',
            'Storage root dry matter content (%)',
            'Dry matter foliage yield',
            'Dry matter root  yield',
            'Root foliage ratio'
        ],
        [
            undef,
            'Abbreviations',
            'NOPS',
            'NOPE',
            'VIR1',
            'VIR2',
            'ALT1',
            'ALT2',
            'W1',
            'VW',
            'NOPH',
            'NOPR',
            'NOCR',
            'NONC',
            'CRW',
            'NCRW',
            'RFCP',
            'RFCS',
            'SCOL',
            'FCOL',
            'RS',
            'RF',
            'DAMR',
            'WED1',
            'DMF',
            'DMD',
            'FRAW1',
            'SURAW1',
            'STRAW1',
            'DMVF',
            'DMVD',
            'COOF1',
            'COOSU1',
            'COOST1',
            'COOT1',
            'COOAP1',
            'W2',
            'VIR3',
            'WED2',
            'FRAW2',
            'SURAW2',
            'STRAW2',
            'COOF2',
            'COOSU2',
            'COOST2',
            'COOT2',
            'COOAP2',
            'RSPR',
            'PROT',
            'FE',
            'ZN',
            'CA',
            'MG',
            'BC',
            'TC',
            'STAR',
            'FRUC',
            'GLUC',
            'SUCR',
            'MALT',
            'TRW',
            'CYTHA',
            'RYTHA',
            'ACRW',
            'NRPP',
            'YPP',
            'CI',
            'HI',
            'SHI',
            'BIOM',
            'FYTHA',
            'DM',
            'DMFY',
            'DMRY',
            'RFR'
        ],
        [
            undef,
            'Fieldbook'
        ],
        [
            undef,
            'Summarize'
        ],
        [
            undef,
            'Analyze'
        ],
        [
            undef,
            'Selection direction'
        ]
    ], "check contents of seventh page");

    is_deeply($columns_8, [
        [],
        [
            undef,
            'plot_name',
            'test_trial21',
            'test_trial22',
            'test_trial23',
            'test_trial24',
            'test_trial25',
            'test_trial26',
            'test_trial27',
            'test_trial28',
            'test_trial29',
            'test_trial210',
            'test_trial211',
            'test_trial212',
            'test_trial213',
            'test_trial214',
            'test_trial215'
        ],
        [
            undef,
            'accession_name',
            'test_accession4',
            'test_accession5',
            'test_accession3',
            'test_accession3',
            'test_accession1',
            'test_accession4',
            'test_accession5',
            'test_accession1',
            'test_accession2',
            'test_accession3',
            'test_accession1',
            'test_accession5',
            'test_accession2',
            'test_accession4',
            'test_accession2'
        ],
        [
            undef,
            'plot_number',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12',
            '13',
            '14',
            '15'
        ],
        [
            undef,
            'block_number',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1'
        ],
        [
            undef,
            'is_a_control'
        ],
        [
            undef,
            'rep_number',
            '1',
            '1',
            '1',
            '2',
            '1',
            '2',
            '2',
            '2',
            '1',
            '3',
            '3',
            '3',
            '2',
            '3',
            '3'
        ],
        [
            undef,
            'dry matter content percentage|CO_334:0000092'
        ],
        [
            undef,
            'fresh root weight|CO_334:0000012'
        ]
    ], "check contents of eigth page");
    $f->clean_up_db();
}
done_testing();
