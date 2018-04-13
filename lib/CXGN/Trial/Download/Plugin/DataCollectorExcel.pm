
package CXGN::Trial::Download::Plugin::DataCollectorExcel;

=head1 NAME

CXGN::Trial::Download::Plugin::DataCollectorExcel

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a "DataCollector Spreadsheet" for collecting phenotypes (as
used in SGN::Controller::AJAX::DataCollectorDownload->create_DataCollector_spreadsheet_POST):

my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    trait_list => \@trait_list,
    filename => $file_path,
    format => 'DataCollectorExcel',
    data_level => $data_level,
});
my $spreadsheet_response = $create_spreadsheet->download();
if ($spreadsheet_response->{error}) {
    $c->stash->{rest} = { error => $spreadsheet_response->{error} };
    return;
}
my $file_name = basename($file_path);
$c->stash->{rest} = { filename => $urlencode{$tempfile.".xls"} };


=head1 AUTHORS

=cut

use Moose::Role;
use utf8;

sub verify {
    my $self = shift;
    return 1;
}


sub download {
    my $self = shift;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my @trait_list = @{$self->trait_list()};
    my $spreadsheet_metadata = $self->file_metadata();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout'} );

    my $design = $trial_layout->get_design();

    if (! $design) {
	     return { error => "No design found for this trial. A trial design must exist in order to create this file"};
    }

    my %design = %{$trial_layout->get_design()};
    my @plot_names = @{$trial_layout->get_plot_names};

    my $workbook = Spreadsheet::WriteExcel->new($self->filename());
    my $ws1 = $workbook->add_worksheet("Minimal");
    my $ws2 = $workbook->add_worksheet("Installation");
    my $ws3 = $workbook->add_worksheet("Material List");
    my $ws4 = $workbook->add_worksheet("Soil_analysis");
    my $ws5 = $workbook->add_worksheet("Weather_data");
    my $ws6 = $workbook->add_worksheet("Crop_management");
    my $ws7 = $workbook->add_worksheet("Var List");
    my $ws = $workbook->add_worksheet("Field Book");

    my $bold = $workbook->add_format();
    $bold->set_bold();

    # add information to Minimal (sheet1)
    #
    $ws1->write(0, 0, 'Factor', $bold); $ws1->write(0, 1, 'Value', $bold);
    $ws1->write(1, 0, 'Short name or Title');
    $ws1->write(2, 0, 'Version'); $ws1->write(2, 1, 'V.2.2.0');
    $ws1->write(3, 0, 'Crop'); $ws1->write(3, 1, 'sweetpotato');
    $ws1->write(4, 0, 'Type of Trial'); $ws1->write(4, 1, 'yield');
    $ws1->write(5, 0, 'Comments'); $ws1->write(6, 0, 'Begin date');
    $ws1->write(7, 0, 'End date'); $ws1->write(8, 0, 'Leader');
    $ws1->write(9, 0, 'Collaborators'); $ws1->write(10, 0, 'Site short name');
    $ws1->write(11, 0, 'Agroecological zone'); $ws1->write(12, 0, 'CIP Region');
    $ws1->write(13, 0, 'Continent'); $ws1->write(14, 0, 'Country');
    $ws1->write(15, 0, 'Admin1'); $ws1->write(16, 0, 'Admin2');
    $ws1->write(17, 0, 'Admin3'); $ws1->write(18, 0, 'Locality');
    $ws1->write(19, 0, 'Elevation'); $ws1->write(20, 0, 'Latitude');
    $ws1->write(21, 0, 'Longitude');
    $ws1->write(22, 0, 'Owner'); $ws1->write(22, 1, 'International Potato Center');
    $ws1->write(23, 0, 'Publisher'); $ws1->write(23, 1, 'International Potato Center');
    $ws1->write(24, 0, 'Type'); $ws1->write(24, 1, 'dataset');
    $ws1->write(25, 0, 'Format'); $ws1->write(25, 1, 'Excel 2003');
    $ws1->write(26, 0, 'Identifier'); $ws1->write(26, 1, 'to be done: doi');
    $ws1->write(27, 0, 'Language'); $ws1->write(27, 1, 'en');
    $ws1->write(28, 0, 'Relation'); $ws1->write(28, 1, 'NA');
    $ws1->write(29, 0, 'License'); $ws1->write(29, 1, "\x{a9} International Potato Center");
    $ws1->write(30, 0, 'Audience'); $ws1->write(30, 1, 'Breeder');
    $ws1->write(31, 0, 'Provenance'); $ws1->write(31, 1, 'original');
    $ws1->write(32, 0, 'Embargo till'); $ws1->write(32, 1, '2012-12-31');
    $ws1->write(33, 0, 'Quality Indicator'); $ws1->write(33, 1, 'NA');
    $ws1->write(34, 0, 'Status'); $ws1->write(34, 1, 'draft');
    $ws1->write(35, 0, 'Donor'); $ws1->write(36, 0, 'Project name');
    $ws1->write(37, 0, 'Project start'); $ws1->write(38, 0, 'Project end');

    # add information to Installation (sheet2)
    #
    $ws2->write(0, 0, 'Factor', $bold); $ws2->write(0, 1, 'Value', $bold);
    $ws2->write(1, 0, 'Experimental design'); $ws2->write(1, 1, 'Randomized Complete Block Design (RCBD)');
    $ws2->write(2, 0, 'Genetic design');
    $ws2->write(3, 0, 'Labels for factor genotypes'); $ws2->write(3, 1, 'Institutional number');
    $ws2->write(4, 0, 'Number of repetitions or blocks'); $ws2->write(4, 1, '2');
    $ws2->write(5, 0, 'Block size (applicable for BIBD only)');
    $ws2->write(6, 0, 'Plot start number');
    $ws2->write(7, 0, 'Number of plants planted per plot'); $ws2->write(7, 1, '10');
    $ws2->write(8, 0, 'Number of rows per plot'); $ws2->write(8, 1, '1');
    $ws2->write(9, 0, 'Number of plants per row'); $ws2->write(9, 1, '10');
    $ws2->write(10, 0, 'Plot size (m2)'); $ws2->write(10, 1, '2.7');
    $ws2->write(11, 0, 'Distance between plants (m)'); $ws2->write(11, 1, '0.3');
    $ws2->write(12, 0, 'Distance between rows (m)'); $ws2->write(12, 1, '0.9');
    $ws2->write(13, 0, 'Planting density (plants/Ha)'); $ws2->write(13, 1, '37,037');
    $ws2->write(14, 0, 'Row direction');
    $ws2->write(15, 0, 'Planting mode');
    $ws2->write(16, 0, 'Area of the experiment'); $ws2->write(17, 0, 'Additional factor name');
    $ws2->write(18, 0, 'Labels for additional factor, level 1'); $ws2->write(19, 0, 'Labels for additional factor, level 2');
    $ws2->write(20, 0, 'Labels for additional factor, level 3'); $ws2->write(21, 0, 'Labels for additional factor, level 4');
    $ws2->write(22, 0, 'Labels for additional factor, level 5'); $ws2->write(23, 0, 'Latitude corner 1');
    $ws2->write(24, 0, 'Longitude corner 1'); $ws2->write(25, 0, 'Latitude corner 2');
    $ws2->write(26, 0, 'Longitude corner 2'); $ws2->write(27, 0, 'Latitude corner 3');
    $ws2->write(28, 0, 'Longitude corner 3'); $ws2->write(29, 0, 'Latitude corner 4');
    $ws2->write(30, 0, 'Longitude corner 4'); $ws2->write(31, 0, 'Initial sprout length (average)');
    $ws2->write(32, 0, 'Field history cropping season t-1'); $ws2->write(33, 0, 'Field history cropping season t-2');
    $ws2->write(34, 0, 'Field history cropping season t-3'); $ws2->write(35, 0, 'Field history cropping season t-4');
    $ws2->write(36, 0, 'Field history cropping season t-5'); $ws2->write(37, 0, 'Sensor Elevation weather data (meters)');

    # add information to Material List (sheet3)
    #
    $ws3->write(0, 0, 'Numeration', $bold); $ws3->write(0, 1, 'Control', $bold);
    $ws3->write(0, 2, 'Institutional number', $bold); $ws3->write(0, 3, 'Clone or variety name', $bold);
    $ws3->write(0, 4, 'Code of clone', $bold); $ws3->write(0, 5, 'Family Institutional number', $bold);
    $ws3->write(0, 6, 'Female Institutional number', $bold); $ws3->write(0, 7, 'Female code', $bold);
    $ws3->write(0, 8, 'Male Institutional number', $bold); $ws3->write(0, 9, 'Male code', $bold);
    $ws3->write(0, 10, 'Seed source1', $bold); $ws3->write(0, 11, 'References to simultaneous trials', $bold);
    $ws3->write(0, 12, 'References to previous trials', $bold);

    # add information to Soil_analysis (sheet4)
    #
    $ws4->write(0, 0, 'Variables', $bold); $ws4->write(0, 1, 'Abbreviation', $bold);
    $ws4->write(0, 2, 'Unit', $bold); $ws4->write(0, 3, 'Data1', $bold);
    $ws4->write(0, 4, 'Data2', $bold); $ws4->write(0, 5, 'Data3', $bold);
    $ws4->write(0, 6, 'Data4', $bold); $ws4->write(0, 7, 'Data5', $bold);
    $ws4->write(0, 8, 'Data6', $bold); $ws4->write(0, 9, 'Data7', $bold);
    $ws4->write(0, 10, 'Data8', $bold); $ws4->write(0, 11, 'Data9', $bold);
    $ws4->write(0, 12, 'Data10', $bold);
    $ws4->write(1, 0, 'Date'); $ws4->write(1, 1, 'DATE');
    $ws4->write(2, 0, 'Requester'); $ws4->write(2, 1, 'RQSTR');
    $ws4->write(3, 0, 'Operator'); $ws4->write(3, 1, 'OPRTR');
    $ws4->write(4, 0, 'Latitude'); $ws4->write(4, 1, 'LATD');
    $ws4->write(5, 0, 'Longitude'); $ws4->write(5, 1, 'LOND');
    $ws4->write(6, 0, 'Laboratory code'); $ws4->write(6, 1, 'LabCo');
    $ws4->write(7, 0, 'Sample code'); $ws4->write(7, 1, 'SCo');
    $ws4->write(8, 0, 'Field code'); $ws4->write(8, 1, 'FDCo');
    $ws4->write(9, 0, 'pH'); $ws4->write(9, 1, 'pH');
    $ws4->write(10, 0, 'Electrical conductivity'); $ws4->write(10, 1, 'EC'); $ws4->write(10, 2, '1 dS/m= 1 mmho/cm');
    $ws4->write(11, 0, 'Calcium Carbonate'); $ws4->write(11, 1, 'CaCO3'); $ws4->write(11, 2, 'percentage');
    $ws4->write(12, 0, 'Organic matter'); $ws4->write(12, 1, 'OM'); $ws4->write(12, 2, 'percentage');
    $ws4->write(13, 0, 'Total nitrogen'); $ws4->write(13, 1, 'TN'); $ws4->write(13, 2, 'percentage');
    $ws4->write(14, 0, 'Phosphorus'); $ws4->write(14, 1, 'P'); $ws4->write(14, 2, 'ppm');
    $ws4->write(15, 0, 'Potassium'); $ws4->write(15, 1, 'K'); $ws4->write(15, 2, 'ppm');
    $ws4->write(16, 0, 'Sand'); $ws4->write(16, 1, 'Sand'); $ws4->write(16, 2, 'percentage');
    $ws4->write(17, 0, 'Lime'); $ws4->write(17, 1, 'Silt'); $ws4->write(17, 2, 'percentage');
    $ws4->write(18, 0, 'Clay'); $ws4->write(18, 1, 'Clay'); $ws4->write(18, 2, 'percentage');
    $ws4->write(19, 0, 'Soil texture'); $ws4->write(19, 1, 'Soil texture'); $ws4->write(19, 2, 'percentage');
    $ws4->write(20, 0, 'Cation Exchange Capacity'); $ws4->write(20, 1, 'CEC'); $ws4->write(20, 2, 'Meq/100g');
    $ws4->write(21, 0, 'Exchangeable Calcium'); $ws4->write(21, 1, 'ExCa2'); $ws4->write(21, 2, 'Meq/100g');
    $ws4->write(22, 0, 'Exchangeable Magnesium'); $ws4->write(22, 1, 'ExMg2'); $ws4->write(22, 2, 'Meq/100g');
    $ws4->write(23, 0, 'Exchangeable Potassium'); $ws4->write(23, 1, 'ExK'); $ws4->write(23, 2, 'Meq/100g');
    $ws4->write(24, 0, 'Exchangeable Sodium'); $ws4->write(24, 1, 'ExNa'); $ws4->write(24, 2, 'Meq/100g');
    $ws4->write(25, 0, 'Aluminium + hidrogenum'); $ws4->write(25, 1, 'ExAl3_H'); $ws4->write(25, 2, 'Meq/100g');
    $ws4->write(26, 0, 'Total cations'); $ws4->write(26, 1, 'TCA'); $ws4->write(26, 2, 'Meq/100g');
    $ws4->write(27, 0, 'Total bases'); $ws4->write(27, 1, 'TBAS'); $ws4->write(27, 2, 'Meq/100g');
    $ws4->write(28, 0, 'Base Saturation'); $ws4->write(28, 1, 'BS'); $ws4->write(28, 2, 'percentage');
    $ws4->write(29, 0, 'Exchangeable Acidity'); $ws4->write(29, 1, 'CCA'); $ws4->write(29, 2, 'percentage');
    $ws4->write(30, 0, 'Anion Exchange capacity'); $ws4->write(30, 1, 'AEC'); $ws4->write(30, 2, 'Meq/100g');
    $ws4->write(31, 0, 'Iron'); $ws4->write(31, 1, 'Fe'); $ws4->write(31, 2, 'ppm');
    $ws4->write(32, 0, 'Copper'); $ws4->write(32, 1, 'Cu'); $ws4->write(32, 2, 'ppm');
    $ws4->write(33, 0, 'Zinc'); $ws4->write(33, 1, 'Zn'); $ws4->write(33, 2, 'ppm');
    $ws4->write(34, 0, 'Boron'); $ws4->write(34, 1, 'B'); $ws4->write(34, 2, 'ppm(*)');
    $ws4->write(35, 0, 'Manganese'); $ws4->write(35, 1, 'Mn'); $ws4->write(35, 2, 'ppm');
    $ws4->write(36, 0, 'Calcium'); $ws4->write(36, 1, 'Ca'); $ws4->write(36, 2, 'meq/L');
    $ws4->write(37, 0, 'Magnesium'); $ws4->write(37, 1, 'Mg'); $ws4->write(37, 2, 'meq/L');
    $ws4->write(38, 0, 'Potassium'); $ws4->write(38, 1, 'K'); $ws4->write(38, 2, 'meq/L');
    $ws4->write(39, 0, 'Sodium'); $ws4->write(39, 1, 'Na'); $ws4->write(39, 2, 'meq/L');
    $ws4->write(40, 0, 'Chloride'); $ws4->write(40, 1, 'Cl'); $ws4->write(40, 2, 'meq/L');
    $ws4->write(41, 0, 'Carbonate'); $ws4->write(41, 1, 'CO3'); $ws4->write(41, 2, 'meq/L');
    $ws4->write(42, 0, 'Bicarbonate'); $ws4->write(42, 1, '(CO3)2'); $ws4->write(42, 2, 'meq/L');
    $ws4->write(43, 0, 'Nitrate'); $ws4->write(43, 1, 'NO3'); $ws4->write(43, 2, 'meq/L');
    $ws4->write(44, 0, 'Sulfate'); $ws4->write(44, 1, 'SO4'); $ws4->write(44, 2, 'meq/L');
    $ws4->write(45, 0, 'Phosphate'); $ws4->write(45, 1, 'PO4'); $ws4->write(45, 2, 'meq/L');

    # add information to Weather_data (sheet5)
    #
    $ws5->write(0, 0, 'Date of weather observation', $bold); $ws5->write(0, 1, 'Hour of weather observation', $bold);
    $ws5->write(0, 2, 'Rainfall (mm)', $bold); $ws5->write(0, 3, "Average temperature (\x{b0}C)", $bold);
    $ws5->write(0, 4, "Minimum temperature (\x{b0}C)", $bold); $ws5->write(0, 5, "Maximum temperature (\x{b0}C)", $bold);
    $ws5->write(0, 6, "Temperature amplitude \x{b0}C ", $bold); $ws5->write(0, 7, 'Relative humidity (%)', $bold);
    $ws5->write(0, 8, 'Solar Radiation (w/m2)', $bold); $ws5->write(0, 9, 'Barometric Pressure (mm)', $bold);
    $ws5->write(0, 10, "Dew point (\x{b0}C) ", $bold); $ws5->write(0, 11, 'Wind speed (m/s)', $bold);
    $ws5->write(0, 12, 'Gust speed', $bold); $ws5->write(0, 13, 'Wind direction', $bold);

    # add information to Crop_management (sheet6)
    #
    $ws6->write(0, 0, 'Intervention category', $bold); $ws6->write(0, 1, 'Intervention type', $bold);
    $ws6->write(0, 2, 'Date', $bold); $ws6->write(0, 3, 'Operator', $bold);
    $ws6->write(0, 4, 'Observations', $bold); $ws6->write(0, 5, 'Active Ingredient', $bold);
    $ws6->write(0, 6, 'Product concentration ', $bold); $ws6->write(0, 7, 'Dose of application', $bold);
    $ws6->write(0, 8, 'Uncertainty of Measurement', $bold);
    $ws6->write(1, 0, 'Preparation'); $ws6->write(1, 1, 'Planting');
    $ws6->write(2, 0, 'Harvest '); $ws6->write(2, 1, 'Vine cutting / killing');
    $ws6->write(3, 0, 'Harvest'); $ws6->write(3, 1, 'Harvest');

    # add information to Var List (sheet7)
    #
    $ws7->write(0, 0, 'Factor Variables', $bold); $ws7->write(0, 1, 'Abbreviations', $bold);
    $ws7->write(0, 2, 'Fieldbook', $bold); $ws7->write(0, 3, 'Summarize', $bold);
    $ws7->write(0, 4, 'Analyze', $bold); $ws7->write(0, 5, 'Selection direction', $bold);
    $ws7->write(1, 0, 'Number of plants planted'); $ws7->write(1, 1, 'NOPS');
    $ws7->write(2, 0, 'Number of plants established'); $ws7->write(2, 1, 'NOPE');
    $ws7->write(3, 0, 'Virus symptoms (1-9), first evaluation'); $ws7->write(3, 1, 'VIR1');
    $ws7->write(4, 0, 'Virus symptoms (1-9), second evaluation'); $ws7->write(4, 1, 'VIR2');
    $ws7->write(5, 0, 'Alternaria symptoms (1-9), first evaluation'); $ws7->write(5, 1, 'ALT1');
    $ws7->write(6, 0, 'Alternaria symptoms (1-9), second evaluation'); $ws7->write(6, 1, 'ALT2');
    $ws7->write(7, 0, 'Vine vigor (1-9), first evaluation'); $ws7->write(7, 1, 'W1');
    $ws7->write(8, 0, 'Vine weight'); $ws7->write(8, 1, 'VW');
    $ws7->write(9, 0, 'Number of plants harvested'); $ws7->write(9, 1, 'NOPH');
    $ws7->write(10, 0, 'Number of plants with roots'); $ws7->write(10, 1, 'NOPR');
    $ws7->write(11, 0, 'Number of commercial roots'); $ws7->write(11, 1, 'NOCR');
    $ws7->write(12, 0, 'Number of non commercial roots'); $ws7->write(12, 1, 'NONC');
    $ws7->write(13, 0, 'Commercial root weight'); $ws7->write(13, 1, 'CRW');
    $ws7->write(14, 0, 'Non commercial root weight'); $ws7->write(14, 1, 'NCRW');
    $ws7->write(15, 0, 'Root primary flesh color'); $ws7->write(15, 1, 'RFCP');
    $ws7->write(16, 0, 'Root secondary flesh color'); $ws7->write(16, 1, 'RFCS');
    $ws7->write(17, 0, 'Storage root skin color'); $ws7->write(17, 1, 'SCOL');
    $ws7->write(18, 0, 'Storage root flesh color'); $ws7->write(18, 1, 'FCOL');
    $ws7->write(19, 0, 'Root size (1-9)'); $ws7->write(19, 1, 'RS');
    $ws7->write(20, 0, 'Root form (1-9)'); $ws7->write(20, 1, 'RF');
    $ws7->write(21, 0, 'Root defects (1-9)'); $ws7->write(21, 1, 'DAMR');
    $ws7->write(22, 0, 'Weevil damage (1-9), first evaluation'); $ws7->write(22, 1, 'WED1');
    $ws7->write(23, 0, 'Fresh weight of roots for dry matter assessment'); $ws7->write(23, 1, 'DMF');
    $ws7->write(24, 0, 'Dry weight of DMF samples'); $ws7->write(24, 1, 'DMD');
    $ws7->write(25, 0, 'Root fiber (1-9), first determination'); $ws7->write(25, 1, 'FRAW1');
    $ws7->write(26, 0, 'Root sugar (1-9), first determination'); $ws7->write(26, 1, 'SURAW1');
    $ws7->write(27, 0, 'Root starch (1-9), first determination'); $ws7->write(27, 1, 'STRAW1');
    $ws7->write(28, 0, 'Fresh weight vines for dry matter assessment'); $ws7->write(28, 1, 'DMVF');
    $ws7->write(29, 0, 'Dry weight of DMVD samples'); $ws7->write(29, 1, 'DMVD');
    $ws7->write(30, 0, 'Cooked fiber (1-9), first evaluation'); $ws7->write(30, 1, 'COOF1');
    $ws7->write(31, 0, 'Cooked sugars (1-9), first evaluation'); $ws7->write(31, 1, 'COOSU1');
    $ws7->write(32, 0, 'Cooked starch (1-9), first evaluation'); $ws7->write(32, 1, 'COOST1');
    $ws7->write(33, 0, 'Cooked taste (1-9), first evaluation'); $ws7->write(33, 1, 'COOT1');
    $ws7->write(34, 0, 'Cooked appearance (1-9), first evaluation'); $ws7->write(34, 1, 'COOAP1');
    $ws7->write(35, 0, 'Vine vigor2 (1-9), second evaluation'); $ws7->write(35, 1, 'W2');
    $ws7->write(36, 0, 'Virus symptoms (1-9), third evaluation'); $ws7->write(36, 1, 'VIR3');
    $ws7->write(37, 0, 'Weevil damage2 (1-9), second evaluation'); $ws7->write(37, 1, 'WED2');
    $ws7->write(38, 0, 'Root fiber (1-9), second determination'); $ws7->write(38, 1, 'FRAW2');
    $ws7->write(39, 0, 'Root sugar (1-9), second determination'); $ws7->write(39, 1, 'SURAW2');
    $ws7->write(40, 0, 'Root starch (1-9), second determination'); $ws7->write(40, 1, 'STRAW2');
    $ws7->write(41, 0, 'Cooked fiber (1-9), second evaluation'); $ws7->write(41, 1, 'COOF2');
    $ws7->write(42, 0, 'Cooked sugars (1-9), second evaluation'); $ws7->write(42, 1, 'COOSU2');
    $ws7->write(43, 0, 'Cooked starch (1-9), second evaluation'); $ws7->write(43, 1, 'COOST2');
    $ws7->write(44, 0, 'Cooked taste (1-9), second evaluation'); $ws7->write(44, 1, 'COOT2');
    $ws7->write(45, 0, 'Cooked appearance (1-9), second evaluation'); $ws7->write(45, 1, 'COOAP2');
    $ws7->write(46, 0, 'Root sprouting (1-9)'); $ws7->write(46, 1, 'RSPR');
    $ws7->write(47, 0, 'Protein'); $ws7->write(47, 1, 'PROT');
    $ws7->write(48, 0, 'Fe'); $ws7->write(48, 1, 'FE');
    $ws7->write(49, 0, 'Zn'); $ws7->write(49, 1, 'ZN');
    $ws7->write(50, 0, 'Ca'); $ws7->write(50, 1, 'CA');
    $ws7->write(51, 0, 'Mg'); $ws7->write(51, 1, 'MG');
    $ws7->write(52, 0, 'Beta carotene'); $ws7->write(52, 1, 'BC');
    $ws7->write(53, 0, 'Total carotenoids'); $ws7->write(53, 1, 'TC');
    $ws7->write(54, 0, 'Starch'); $ws7->write(54, 1, 'STAR');
    $ws7->write(55, 0, 'Fructose'); $ws7->write(55, 1, 'FRUC');
    $ws7->write(56, 0, 'Glucose'); $ws7->write(56, 1, 'GLUC');
    $ws7->write(57, 0, 'Sucrose'); $ws7->write(57, 1, 'SUCR');
    $ws7->write(58, 0, 'Maltose'); $ws7->write(58, 1, 'MALT');
    $ws7->write(59, 0, 'Total root weight'); $ws7->write(59, 1, 'TRW');
    $ws7->write(60, 0, 'Commercial root yield t/ha'); $ws7->write(60, 1, 'CYTHA');
    $ws7->write(61, 0, 'Total root yield t/ha'); $ws7->write(61, 1, 'RYTHA');
    $ws7->write(62, 0, 'Average commercial root weight'); $ws7->write(62, 1, 'ACRW');
    $ws7->write(63, 0, 'Number of roots per plant'); $ws7->write(63, 1, 'NRPP');
    $ws7->write(64, 0, 'Yield per plant Kg'); $ws7->write(64, 1, 'YPP');
    $ws7->write(65, 0, 'Percent marketable roots (commercial index)'); $ws7->write(65, 1, 'CI');
    $ws7->write(66, 0, 'Harvest index'); $ws7->write(66, 1, 'HI');
    $ws7->write(67, 0, 'Harvest sowing index  (survival)'); $ws7->write(67, 1, 'SHI');
    $ws7->write(68, 0, 'Biomass yield'); $ws7->write(68, 1, 'BIOM');
    $ws7->write(69, 0, 'Foliage total yield t/ha'); $ws7->write(69, 1, 'FYTHA');
    $ws7->write(70, 0, 'Storage root dry matter content (%)'); $ws7->write(70, 1, 'DM');
    $ws7->write(71, 0, 'Dry matter foliage yield'); $ws7->write(71, 1, 'DMFY');
    $ws7->write(72, 0, 'Dry matter root  yield'); $ws7->write(72, 1, 'DMRY');
    $ws7->write(73, 0, 'Root foliage ratio'); $ws7->write(73, 1, 'RFR');


    # generate worksheet headers
    #

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
   #$ws->write(0, 0, 'Spreadsheet ID'); $ws->write('0', '1', 'ID'.$$.time());
   #$ws->write(0, 2, 'Spreadsheet format'); $ws->write(0, 3, "BasicExcel");
   #$ws->write(1, 0, 'Trial name'); $ws->write(1, 1, $trial->get_name(), $bold);
   #$ws->write(2, 0, 'Description'); $ws->write(2, 1, $trial->get_description(), $bold);
   #$ws->write(3, 0, "Trial location");  $ws->write(3, 1, $trial->get_location()->[1], $bold);
   #$ws->write(1, 2, 'Operator');       $ws->write(1, 3, "Enter operator here");
   #$ws->write(2, 2, 'Date');           $ws->write(2, 3, "Enter date here");
   #$ws->data_validation(2,3, { validate => "date" });
    
    my $num_col_before_traits;
    if ($self->data_level eq 'plots') {
        $num_col_before_traits = 6;
        my @column_headers = qw | plot_name accession_name plot_number block_number is_a_control rep_number |;
        for(my $n=0; $n<@column_headers; $n++) { 
            $ws->write(0, $n, $column_headers[$n]);
        }
        
        my @ordered_plots = sort { $a <=> $b} keys(%design);        
        for(my $n=0; $n<@ordered_plots; $n++) { 
            my %design_info = %{$design{$ordered_plots[$n]}};

            $ws->write($n+1, 0, $design_info{plot_name});
            $ws->write($n+1, 1, $design_info{accession_name});
            $ws->write($n+1, 2, $design_info{plot_number});
            $ws->write($n+1, 3, $design_info{block_number});
            $ws->write($n+1, 4, $design_info{is_a_control});
            $ws->write($n+1, 5, $design_info{rep_number});
        }
    } elsif ($self->data_level eq 'plants') {
        $num_col_before_traits = 7;
        my @column_headers = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number |;
        for(my $n=0; $n<@column_headers; $n++) { 
            $ws->write(0, $n, $column_headers[$n]);
        }
        
        my @ordered_plots = sort { $a <=> $b} keys(%design);
        my $line = 1;
        for(my $n=0; $n<@ordered_plots; $n++) { 
            my %design_info = %{$design{$ordered_plots[$n]}};

            my $plant_names = $design_info{plant_names};
            foreach (@$plant_names) {
                $ws->write($line, 0, $_);
                $ws->write($line, 1, $design_info{plot_name});
                $ws->write($line, 2, $design_info{accession_name});
                $ws->write($line, 3, $design_info{plot_number});
                $ws->write($line, 4, $design_info{block_number});
                $ws->write($line, 5, $design_info{is_a_control});
                $ws->write($line, 6, $design_info{rep_number});
                $line++;
            }
        }
    }
    

    # write traits and format trait columns
    #
    my $lt = CXGN::List::Transform->new();

    my $transform = $lt->transform($schema, "traits_2_trait_ids", \@trait_list);

    if (@{$transform->{missing}}>0) { 
        print STDERR "Warning: Some traits could not be found. ".join(",",@{$transform->{missing}})."\n";
    }
    my @trait_ids = @{$transform->{transform}};

    my %cvinfo = ();
    foreach my $t (@trait_ids) { 
        my $trait = CXGN::Trait->new( { bcs_schema=> $schema, cvterm_id => $t });
        $cvinfo{$trait->display_name()} = $trait;
    }

    for (my $i = 0; $i < @trait_list; $i++) { 
        #if (exists($cvinfo{$trait_list[$i]})) { 
            #$ws->write(0, $i+6, $cvinfo{$trait_list[$i]}->display_name());
            $ws->write(0, $i+$num_col_before_traits, $trait_list[$i]);
        #}
        #else { 
        #    print STDERR "Skipping output of trait $trait_list[$i] because it does not exist\n";
        #}

        my $plot_count = scalar(keys(%design));

        for (my $n = 1; $n < $plot_count; $n++) {
            if ($cvinfo{$trait_list[$i]}) {
                my $format = $cvinfo{$trait_list[$i]}->format();
                if ($format eq "numeric") { 
                    $ws->data_validation($n, $i+$num_col_before_traits, { validate => "any" });
                }
                elsif ($format =~ /\,/) {  # is a list
                    $ws->data_validation($n, $i+$num_col_before_traits, {
                        validate => 'list',
                        value    => [ split ",", $format ]
                    });
                }
            }
        }
    }
    $workbook->close();
    print STDERR "DataCollector File created!\n";
    return { message => "DataCollector File created!"};
}

1;
