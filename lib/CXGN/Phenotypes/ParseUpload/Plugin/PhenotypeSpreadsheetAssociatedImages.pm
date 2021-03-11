package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetAssociatedImages;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '', 'janedoe', '', 'image.png']
#           varname2 => [120, '', 'janedoe', '', 'image.png']
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use JSON;
use Data::Dumper;
use CXGN::ZipFile;
use SGN::Image;
use CXGN::List::Validate;
use File::Basename qw | basename dirname|;

sub name {
    return "phenotype spreadsheet associated_images";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $image_zipfile = shift;
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my @file_lines;
    my $header;
    my @header_row;
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;
    my %parse_result;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        $parse_result{'error'} = $parser->error();
        print STDERR "validate error: ".$parser->error()."\n";
        return \%parse_result;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least observationunit_name and one trait, as well as one row of phenotypes
        $parse_result{'error'} = "Spreadsheet is less than 2 columns or 2 rows.";
        print STDERR "Spreadsheet is missing header\n";
        return \%parse_result;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'observationunit_name' && $worksheet->get_cell(0,1)->value() ne 'observationvariable_name' && $worksheet->get_cell(0,2)->value() ne 'phenotype_value' && $worksheet->get_cell(0,3)->value() ne 'phenotype_timestamp' && $worksheet->get_cell(0,4)->value() ne 'image_name' && $worksheet->get_cell(0,5)->value() ne 'username') {
        $parse_result{'error'} = "Header row must be 'observationunit_name, observationvariable_name, phenotype_value, phenotype_timestamp, image_name, username'. It may help to recreate your spreadsheet from the website.";
        print STDERR "Header not correct\n";
        return \%parse_result;
    }

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$image_zipfile);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $parse_result{error} = 'Could not read your zipfile. Is it .zip format?';
    }
    my %image_zip_contents;
    foreach my $file_member (@$file_members) {
        my $filename = basename($file_member->fileName());
        $image_zip_contents{$filename}++;
    }
    #print STDERR Dumper \%image_zip_contents;

    #StorePhenotypes verify checks that observationunitnames and observationvariablenames are in database.
    my %observationunits_seen;
    for my $row ( 1 .. $row_max ) {
        my $observationunit_name;
        if ($worksheet->get_cell($row,0)) {
            $observationunit_name = $worksheet->get_cell($row,0)->value();
        }
        else {
            $parse_result{'error'} = "No observation unit name on row $row!";
            return \%parse_result;
        }
        my $observationvariable_name;
        if ($worksheet->get_cell($row,1)) {
            $observationvariable_name = $worksheet->get_cell($row,1)->value();
        }
        else {
            $parse_result{'error'} = "No observation variable name (trait) on row $row!";
            return \%parse_result;
        }
        my $phenotype_value;
        if ($worksheet->get_cell($row,2)) {
            $phenotype_value = $worksheet->get_cell($row,2)->value();
        }
        else {
            $parse_result{'error'} = "No phenotype value on row $row!";
            return \%parse_result;
        }
        my $phenotype_timestamp = $worksheet->get_cell($row,3) ? $worksheet->get_cell($row,3)->value() : '';
        my $image_name;
        if ($worksheet->get_cell($row,4)) {
            $image_name = $worksheet->get_cell($row,4)->value();
        }
        else {
            $parse_result{'error'} = "No image name on row $row!";
            return \%parse_result;
        }
        my $username = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : '';

        $observationunits_seen{$observationunit_name}++;

        if (!$image_zip_contents{$image_name}) {
            $parse_result{'error'} = "The image $image_name does not exist in the provided zipfile!";
            return \%parse_result;
        }

        if ($phenotype_timestamp && !$phenotype_timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
            $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
            return \%parse_result;
        }
    }

    my @observation_units = keys %observationunits_seen;
    my $observationunit_validator = CXGN::List::Validate->new();
    my @missing_observation_units = @{$observationunit_validator->validate($schema,'plots_or_subplots_or_plants_or_tissue_samples',\@observation_units)->{'missing'}};
    if (scalar(@missing_observation_units) > 0) {
        my $missing_observationunit_string = join ',', @missing_observation_units;
        $parse_result{'error'} = "The following observation unit names are not in the database: ".$missing_observationunit_string;
        return \%parse_result;
    }

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $image_zipfile = shift;
    my $user_id = shift;
    my $c = shift;
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;
    my %observationunits_seen;
    my %observationvariables_seen;
    my %data;
    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        $parse_result{'error'} = $parser->error();
        print STDERR "validate error: ".$parser->error()."\n";
        return \%parse_result;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my @fixed_columns = qw | observationunit_name observationvariable_name phenotype_value phenotype_timestamp image_name username|;

    my %image_observation_unit_hash;
    for my $row ( 1 .. $row_max ) {
        my $observationunit_name = $worksheet->get_cell($row,0)->value();
        my $observationvariable_name = $worksheet->get_cell($row,1)->value();
        my $phenotype_value = $worksheet->get_cell($row,2)->value();
        my $phenotype_timestamp = $worksheet->get_cell($row,3) ? $worksheet->get_cell($row,3)->value() : '';
        my $image_name = $worksheet->get_cell($row,4)->value();
        my $username = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : '';
        $observationunits_seen{$observationunit_name} = 1;
        $image_observation_unit_hash{$image_name} = $observationunit_name;
    }

    my @observation_units = sort keys %observationunits_seen;
    my %observationunit_lookup;
    my $field_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $tf = CXGN::List::Transform->new();
    my $stock_ids = $tf->transform($schema, 'stocks_2_stock_ids', \@observation_units)->{transform};
    my $stock_ids_sql  = join ("," , @$stock_ids);
    my $stock_q = "SELECT uniquename, stock_id, project_id FROM stock JOIN nd_experiment_stock USING(stock_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE nd_experiment.type_id=$field_experiment_type_id AND stock.stock_id IN ($stock_ids_sql);";
    my $h = $schema->storage->dbh()->prepare($stock_q);
    $h->execute();
    while (my ($uniquename, $stock_id, $project_id) = $h->fetchrow_array()) {
        $observationunit_lookup{$uniquename} = {
            stock_id => $stock_id,
            project_id => $project_id
        };
    }
    while (my ($image_name, $uniquename) = each %image_observation_unit_hash) {
        $image_observation_unit_hash{$image_name} = $observationunit_lookup{$uniquename};
    }

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $zipfile_return = $image->upload_phenotypes_associated_images_zipfile($image_zipfile, $user_id, \%image_observation_unit_hash, "phenotype_spreadsheet_associated_images");
    if ($zipfile_return->{error}) {
        $parse_result{'error'} = $zipfile_return->{error};
        return \%parse_result;
    }
    my $stock_id_image_id_lookup = $zipfile_return->{return};

    for my $row ( 1 .. $row_max ) {
        my $observationunit_name = $worksheet->get_cell($row,0)->value();
        my $observationvariable_name = $worksheet->get_cell($row,1)->value();
        my $phenotype_value = $worksheet->get_cell($row,2)->value();
        my $phenotype_timestamp = $worksheet->get_cell($row,3) ? $worksheet->get_cell($row,3)->value() : '';
        my $image_name = $worksheet->get_cell($row,4)->value();
        my $username = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : '';
        $observationvariables_seen{$observationvariable_name} = 1;
        my $timestamp = '';
        if ( defined($phenotype_value) && defined($timestamp) ) {
            if ($phenotype_value ne '.'){
                $data{$observationunit_name}->{$observationvariable_name} = [$phenotype_value, $timestamp, $username, '', $stock_id_image_id_lookup->{$observationunit_lookup{$observationunit_name}->{stock_id}}];
            }
        }
    }

    my @observation_variables = sort keys %observationvariables_seen;

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@observation_units;
    $parse_result{'variables'} = \@observation_variables;
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;
