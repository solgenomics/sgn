package CXGN::Pedigree::ParseUpload::Plugin::CIPcross;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my %errors;
    my %supported_cross_types;

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        push @error_messages,  $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 4 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of crosses
        push @error_messages, "Spreadsheet is missing header or contains no row";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $inventory_id_head;
    my $female_order_head;
    my $female_accession_number_head;
    my $female_code_breeder_head;
    my $female_attributes_head;
    my $male_order_head;
    my $male_accession_number_head;
    my $male_code_breeder_head;
    my $male_attributes_head;
    my $number_of_flowers_head;
    my $crossing_date_head;
    my $cross_user_head;
    my $number_of_fruits_head;
    my $fruit_harvest_date_head;
    my $fruit_size_head;
    my $harvest_user_head;
    my $fruit_maceration_date_head;
    my $maceration_user_head;
    my $seed_with_spot_markers_head;
    my $seed_without_spot_markers_head;
    my $total_number_of_seeds_head;
    my $seed_stock_head;
    my $seed_count_date_head;
    my $seed_count_user_head;


    if ($worksheet->get_cell(0,0)) {
        $inventory_id_head  = $worksheet->get_cell(0,0)->value();
        $inventory_id_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $female_order_head  = $worksheet->get_cell(0,5)->value();
        $female_order_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $female_accession_number_head  = $worksheet->get_cell(0,6)->value();
        $female_accession_number_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
        $female_code_breeder_head  = $worksheet->get_cell(0,7)->value();
        $female_code_breeder_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,8)) {
        $female_attributes_head  = $worksheet->get_cell(0,8)->value();
        $female_attributes_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,9)) {
        $male_order_head  = $worksheet->get_cell(0,9)->value();
        $male_order_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,10)) {
        $male_accession_number_head  = $worksheet->get_cell(0,10)->value();
        $male_accession_number_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,11)) {
        $male_code_breeder_head  = $worksheet->get_cell(0,11)->value();
        $male_code_breeder_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,12)) {
        $male_attributes_head  = $worksheet->get_cell(0,12)->value();
        $male_attributes_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,13)) {
        $number_of_flowers_head  = $worksheet->get_cell(0,13)->value();
        $number_of_flowers_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,14)) {
        $crossing_date_head  = $worksheet->get_cell(0,14)->value();
        $crossing_date_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,15)) {
        $cross_user_head  = $worksheet->get_cell(0,15)->value();
        $cross_user_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,16)) {
        $number_of_fruits_head  = $worksheet->get_cell(0,16)->value();
        $number_of_fruits_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,17)) {
        $fruit_harvest_date_head  = $worksheet->get_cell(0,17)->value();
        $fruit_harvest_date_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,18)) {
        $fruit_size_head  = $worksheet->get_cell(0,18)->value();
        $fruit_size_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,19)) {
        $harvest_user_head  = $worksheet->get_cell(0,19)->value();
        $harvest_user_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,20)) {
        $fruit_maceration_date_head  = $worksheet->get_cell(0,20)->value();
        $fruit_maceration_date_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,21)) {
        $maceration_user_head  = $worksheet->get_cell(0,21)->value();
        $maceration_user_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,39)) {
        $seed_with_spot_markers_head  = $worksheet->get_cell(0,39)->value();
        $seed_with_spot_markers_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,40)) {
        $seed_without_spot_markers_head  = $worksheet->get_cell(0,40)->value();
        $seed_without_spot_markers_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,41)) {
        $total_number_of_seeds_head  = $worksheet->get_cell(0,41)->value();
        $total_number_of_seeds_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,42)) {
        $seed_stock_head  = $worksheet->get_cell(0,42)->value();
        $seed_stock_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,43)) {
        $seed_count_date_head  = $worksheet->get_cell(0,43)->value();
        $seed_count_date_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,44)) {
        $seed_count_user_head  = $worksheet->get_cell(0,44)->value();
        $seed_count_user_head =~ s/^\s+|\s+$//g;
    }

    if (!$inventory_id_head || $inventory_id_head ne 'Inventory ID' ) {
        push @error_messages, "Cell A1: Inventory ID is missing from the header";
    }
    if (!$female_order_head || $female_order_head ne 'Female Order' ) {
        push @error_messages, "Cell F1: Female Order is missing from the header";
    }
    if (!$female_accession_number_head || $female_accession_number_head ne 'Female Accession Number') {
        push @error_messages, "Cell G1: Female Accession Number is missing from the header";
    }
    if (!$female_code_breeder_head || $female_code_breeder_head ne 'Female Code Breeder' ) {
        push @error_messages, "Cell H1: Female Code Breeder is missing from the header";
    }
    if (!$female_attributes_head || $female_attributes_head ne 'Female Attributes' ) {
        push @error_messages, "Cell I1: Female Attributes is missing from the header";
    }
    if (!$male_order_head || $male_order_head ne 'Male Order' ) {
        push @error_messages, "Cell J1: Male Order is missing from the header";
    }
    if (!$male_accession_number_head || $male_accession_number_head ne 'Male Accession Number') {
        push @error_messages, "Cell K1: Male Accession Number is missing from the header";
    }
    if (!$male_code_breeder_head || $male_code_breeder_head ne 'Male Code Breeder' ) {
        push @error_messages, "Cell L1: Male Code Breeder is missing from the header";
    }
    if (!$male_attributes_head || $male_attributed_head ne 'Male Attributes' ) {
        push @error_messages, "Cell M1: Male Attributes is missing from the header";
    }
    if (!$number_of_flowers_head || $number_of_flowers_head ne 'Number of Flowers' ) {
        push @error_messages, "Cell N1: Number of Flowers is missing from the header";
    }
    if (!$crossing_date_head || $crossing_date_head ne 'Crossing Date' ) {
        push @error_messages, "Cell O1: Crossing Date is missing from the header";
    }
    if (!$cross_user_head || $cross_user_head ne 'Cross User' ) {
        push @error_messages, "Cell P1: Cross User is missing from the header";
    }
    if (!$number_of_fruits_head || $number_of_fruits_head ne 'Number of Fruits' ) {
        push @error_messages, "Cell Q1: Number of Fruits is missing from the header";
    }
    if (!$fruit_harvest_date_head || $fruit_harvest_date_head ne 'Fruit Harvest Date' ) {
        push @error_messages, "Cell R1: Fruit Harvest Date is missing from the header";
    }
    if (!$fruit_size_head || $fruit_size_head ne 'Fruit Size' ) {
        push @error_messages, "Cell S1: Fruit Size is missing from the header";
    }
    if (!$harvest_user_head || $harvest_user_head ne 'Harvest User' ) {
        push @error_messages, "Cell T1: Harvest User is missing from the header";
    }
    if (!$fruit_maceration_date_head || $fruit_maceration_date_head ne 'Fruit Maceration Date' ) {
        push @error_messages, "Cell U1: Fruit Maceration Date is missing from the header";
    }
    if (!$maceration_user_head || $maceration_user_head ne 'Maceration User' ) {
        push @error_messages, "Cell V1: Maceration User is missing from the header";
    }
    if (!$seed_with_spot_markers_head || $seed_with_spot_markers_head ne 'Seed with Spot Markers' ) {
        push @error_messages, "Cell AN1: Seed with Spot Markers is missing from the header";
    }
    if (!$seed_without_spot_markers_head || $seed_without_spot_markers_head ne 'Seed without Spot Markers' ) {
        push @error_messages, "Cell AO1: Seed without Spot Markers is missing from the header";
    }
    if (!$total_number_of_seeds_head || $total_number_of_seeds_head ne 'Total Number of Seeds' ) {
        push @error_messages, "Cell AP1: Total Number of Seeds is missing from the header";
    }
    if (!$seed_stock_head || $seed_stock_head ne 'Seed Stock' ) {
        push @error_messages, "Cell AQ1: Seed Stock is missing from the header";
    }
    if (!$seed_count_date_head || $seed_count_date_head ne 'Seed Count Date' ) {
        push @error_messages, "Cell AR1: Seed Count Date is missing from the header";
    }
    if (!$seed_count_user_head || $seed_count_user_head ne 'Seed Count User' ) {
        push @error_messages, "Cell AS1: Seed Count User is missing from the header";
    }


    my %seen_inventory_ids;
    my %seen_accession_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $inventory_id;
        my $female_accession_number;
        my $male_accession_number;

        if ($worksheet->get_cell($row,0)) {
            $inventory_id = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $female_accession_number =  $worksheet->get_cell($row,6)->value();
            $female_accession_number =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $male_accession_number = $worksheet->get_cell($row,10)->value();
            $male_accession_number =~ s/^\s+|\s+$//g;
        }

        if (!$inventory_id || $inventory_id eq '') {
            push @error_messages, "Cell A$row_name: Inventory ID missing";
        } else {
            $inventory_id =~ s/^\s+|\s+$//g;
        }

        if ($seen_inventory_id{$inventory_id}) {
            push @error_messages, "Cell A$row_name: duplicate Inventory ID: $inventory_id";
        }

        if (!$female_accession_number || $female_accession_number eq '') {
            push @error_messages, "Cell G$row_name: Female Accession Number missing";
        } else {
            $female_accession_number =~ s/^\s+|\s+$//g;
            $seen_accession_names{$female_accession_number}++;
        }

        if (!$male_accession_number || $male_accession_number eq '') {
            push @error_messages, "Cell K$row_name: Male Accession Number missing";
        } else {
            $male_accession_number =~ s/^\s+|\s+$//g;
            $seen_accession_names{$male_accession_number}++;
        }

    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
    }

    my @all_inventory_ids = keys %seen_inventory_ids;
    my $inventory_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@all_inventory_ids }
    });
    while (my $r=$inventory_rs->next){
        push @error_messages, "Inventory ID already exists in database: ".$r->uniquename;
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;
    my %female_info;
    my %male_info;
    my @pedigrees;
    my %cross_info;
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $inventory_id;
        my $female_order;
        my $female_accession_number;
        my $female_code_breeder;
        my $female_attributes;
        my $male_order;
        my $male_accession_number;
        my $male_code_breeder;
        my $male_attributes;
        my $number_of_flowers;
        my $crossing_date;
        my $cross_user;
        my $number_of_fruits;
        my $fruit_harvest_date;
        my $fruit_size;
        my $harvest_user;
        my $fruit_maceration_date;
        my $maceration_user;
        my $seed_with_spot_markers;
        my $seed_without_spot_markers;
        my $total_number_of_seeds;
        my $seed_stock;
        my $seed_count_date;
        my $seed_count_user;


        if ($worksheet->get_cell($row,0)) {
            $inventory_id = $worksheet->get_cell($row,0)->value();
            $inventory_id =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $female_order = $worksheet->get_cell($row,5)->value();
            $female_order =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $female_accession_number =  $worksheet->get_cell($row,6)->value();
            $female_accession_number =~ s/^\s+|\s+$//g;
            $female_info{$female_accession_number}{'female_order'}{$female_order}++;
        }
        if ($worksheet->get_cell($row,7)) {
            $female_code_breeder = $worksheet->get_cell($row,7)->value();
            $female_code_breeder =~ s/^\s+|\s+$//g;
            $female_info{$female_accession_number}{'female_code_breeder'}{$female_code_breeder}++;
        }
        if ($worksheet->get_cell($row,8)) {
            $female_attributes = $worksheet->get_cell($row,8)->value();
            $female_attributes =~ s/^\s+|\s+$//g;
            $female_info{$female_accession_number}{'female_attributes'}{$female_attributes}++;
        }
        if ($worksheet->get_cell($row,9)) {
            $male_order = $worksheet->get_cell($row,9)->value();
            $male_order =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $male_accession_number = $worksheet->get_cell($row,10)->value();
            $male_accession_number =~ s/^\s+|\s+$//g;
            $male_info{$male_accession_number}{'male_order'}{$male_order}++;
        }
        if ($worksheet->get_cell($row,11)) {
            $male_code_breeder = $worksheet->get_cell($row,11)->value();
            $male_code_breeder =~ s/^\s+|\s+$//g;
            $male_info{$male_accession_number}{'male_code_breeder'}{$male_code_breeder}++;
        }
        if ($worksheet->get_cell($row,12)) {
            $male_attributes = $worksheet->get_cell($row,12)->value();
            $male_attributes =~ s/^\s+|\s+$//g;
            $male_info{$male_accession_number}{'male_attributes'}{$male_attributes}++;
        }
        if ($worksheet->get_cell($row,13)) {
            $number_of_flowers  = $worksheet->get_cell($row,13)->value();
            $number_of_flowers =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'number_of_flowers'} = $number_of_flowers;
        }
        if ($worksheet->get_cell($row,14)) {
            $crossing_date  = $worksheet->get_cell($row,14)->value();
            $crossing_date =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'crossing_date'} = $crossing_date;
        }
        if ($worksheet->get_cell($row,15)) {
            $cross_user  = $worksheet->get_cell($row,15)->value();
            $cross_user =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'cross_user'} = $cross_user;
        }
        if ($worksheet->get_cell($row,16)) {
            $number_of_fruits  = $worksheet->get_cell($row,16)->value();
            $number_of_fruits =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'number_of_fruits'} = $number_of_fruits;
        }
        if ($worksheet->get_cell($row,17)) {
            $fruit_harvest_date  = $worksheet->get_cell($row,17)->value();
            $fruit_harvest_date =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'fruit_harvest_date'} = $fruit_harvest_date;
        }
        if ($worksheet->get_cell($row,18)) {
            $fruit_size  = $worksheet->get_cell($row,18)->value();
            $fruit_size =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'fruit_size'} = $fruit_size;
        }
        if ($worksheet->get_cell($row,19)) {
            $harvest_user  = $worksheet->get_cell($row,19)->value();
            $harvest_user =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'harvest_user'} = $harvest_user;
        }
        if ($worksheet->get_cell($row,20)) {
            $fruit_maceration_date  = $worksheet->get_cell($row,20)->value();
            $fruit_maceration_date =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'fruit_maceration_date'} = $fruit_maceration_date;
        }
        if ($worksheet->get_cell($row,21)) {
            $maceration_user  = $worksheet->get_cell($row,21)->value();
            $maceration_user =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'maceration_user'} = $maceration_user;
        }
        if ($worksheet->get_cell($row,39)) {
            $seed_with_spot_markers  = $worksheet->get_cell($row,39)->value();
            $seed_with_spot_markers =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'seed_with_spot_markers'} = $seed_with_spot_markers;
        }
        if ($worksheet->get_cell($row,40)) {
            $seed_without_spot_markers  = $worksheet->get_cell($row,40)->value();
            $seed_without_spot_markers =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'seed_without_spot_markers'} = $seed_without_spot_markers;
        }
        if ($worksheet->get_cell($row,41)) {
            $total_number_of_seeds  = $worksheet->get_cell($row,41)->value();
            $total_number_of_seeds =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'total_number_of_seeds'} = $total_number_of_seeds;
        }
        if ($worksheet->get_cell($row,42)) {
            $seed_stock  = $worksheet->get_cell($row,42)->value();
            $seed_stock =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'seed_stock'} = $seed_stock;
        }
        if ($worksheet->get_cell($row,43)) {
            $seed_count_date  = $worksheet->get_cell($row,43)->value();
            $seed_count_date =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'seed_count_date'} = $seed_count_date;
        }
        if ($worksheet->get_cell($row,44)) {
            $seed_count_user  = $worksheet->get_cell($row,44)->value();
            $seed_count_user =~ s/^\s+|\s+$//g;
            $cross_info{$inventory_id}{'seed_count_user'} = $seed_count_user;
        }

        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$inventory_id, cross_type=>'biparental');
        if ($female_accession_number) {
            my $female_parent = Bio::GeneticRelationships::Individual->new(name => $female_accession_number);
            $pedigree->set_female_parent($female_parent);
        }
        if ($male_accession_number) {
            my $male_parent = Bio::GeneticRelationships::Individual->new(name => $male_accession_number);
            $pedigree->set_male_parent($male_parent);
        }

        push @pedigrees, $pedigree;

    }

    $parsed_result{'female_info'} = \%female_info;
    $parsed_result{'male_info'} = \%male_info;
    $parsed_result{'crosses'} = \@pedigrees;
    $parsed_result{'cross_info'} = \%cross_info

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}




1;
