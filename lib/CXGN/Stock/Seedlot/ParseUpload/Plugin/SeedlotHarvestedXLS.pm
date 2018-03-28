package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotHarvestedXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $parser = Spreadsheet::ParseExcel->new();
    my @error_messages;
    my %errors;
    my %missing_accessions;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if (!$excel_obj) {
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $seedlot_name_head;
    my $source_plant_name_head;
    my $source_plot_name_head;
    my $source_accession_name_head;
    my $source_cross_name_head;
    my $operator_name_head;
    my $amount_head;
    my $weight_head;
    my $description_head;
    my $box_name_head;

    if ($worksheet->get_cell(0,0)) {
        $seedlot_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $source_plant_name_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $source_plot_name_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $source_accession_name_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $source_cross_name_head  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,5)) {
        $operator_name_head  = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,6)) {
        $amount_head  = $worksheet->get_cell(0,4)->value();
    }
    if ($worksheet->get_cell(0,7)) {
        $weight_head  = $worksheet->get_cell(0,5)->value();
    }
    if ($worksheet->get_cell(0,8)) {
        $description_head  = $worksheet->get_cell(0,6)->value();
    }
    if ($worksheet->get_cell(0,9)) {
        $box_name_head  = $worksheet->get_cell(0,7)->value();
    }

    if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name' ) {
        push @error_messages, "Cell A1: seedlot_name is missing from the header";
    }
    if (!$source_plant_name_head || $source_plant_name_head ne 'source_plant_name') {
        push @error_messages, "Cell B1: source_plant_name is missing from the header";
    }
    if (!$source_plot_name_head || $source_plot_name_head ne 'source_plot_name') {
        push @error_messages, "Cell C1: source_plot_name is missing from the header";
    }
    if (!$source_accession_name_head || $source_accession_name_head ne 'source_accession_name') {
        push @error_messages, "Cell D1: source_accession_name is missing from the header";
    }
    if (!$source_cross_name_head || $source_cross_name_head ne 'source_cross_name') {
        push @error_messages, "Cell E1: source_cross_name is missing from the header";
    }
    if (!$operator_name_head || $operator_name_head ne 'operator_name') {
        push @error_messages, "Cell F1: operator_name is missing from the header";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Cell G1: amount is missing from the header";
    }
    if (!$weight_head || $weight_head ne 'weight(g)') {
        push @error_messages, "Cell H1: weight(g) is missing from the header";
    }
    if (!$description_head || $description_head ne 'description') {
        push @error_messages, "Cell I1: description is missing from the header";
    }
    if (!$box_name_head || $box_name_head ne 'box_name') {
        push @error_messages, "Cell J1: box_name is missing from the header";
    }

    my %seen_seedlot_names;
    my %seen_plant_names;
    my %seen_plot_names;
    my %seen_accession_names;
    my %seen_cross_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot_name;
        my $plant_name;
        my $plot_name;
        my $accession_name;
        my $cross_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $plant_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $plot_name = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $accession_name = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $cross_name = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $operator_name = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $amount =  $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $weight =  $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $description =  $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $box_name =  $worksheet->get_cell($row,9)->value();
        }

        if (!$seedlot_name || $seedlot_name eq '' ) {
            push @error_messages, "Cell A$row_name: seedlot_name missing.";
        }
        elsif ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: seedlot_name must not contain spaces or slashes.";
        }
        else {
            #file must not contain duplicate plot names
            if ($seen_seedlot_names{$seedlot_name}) {
                push @error_messages, "Cell A$row_name: duplicate seedlot_name at cell A".$seen_seedlot_names{$seedlot_name}.": $seedlot_name";
            }
            $seen_seedlot_names{$seedlot_name}=$row_name;
        }

        if ( (!$plant_name || $plant_name eq '') && (!$plot_name || $plot_name eq '') && (!$accession_name || $accession_name eq '') && (!$cross_name || $cross_name eq '') ) {
            push @error_messages, "In row:$row_name: you must provide ONE OF: source_plant_name OR source_plot_name OR source_accession_name OR source_cross_name for the contents of the seedlot.";
        } elsif ( ($plant_name && $plant_name ne '' && $plot_name && $plot_name ne '') || ($plant_name && $plant_name ne '' && $accession_name && $accession_name ne '') || ($plant_name && $plant_name ne '' && $cross_name && $cross_name ne '') || ($plot_name && $plot_name ne '' && $accession_name && $accession_name ne '') || ($plot_name && $plot_name ne '' && $cross_name && $cross_name ne '') || ($accession_name && $accession_name ne '' && $cross_name && $cross_name ne '') ) {
            push @error_messages, "In row:$row_name: you must provide ONLY ONE: source_plant_name OR source_plot_name OR source_accession_name OR source_cross_name for the contents of the seedlot.";
        } else {
            if ($plant_name){
                $seen_plant_names{$plant_name}++;
            }
            if ($plot_name){
                $seen_plot_names{$plot_name}++;
            }
            if ($accession_name){
                $seen_accession_names{$accession_name}++;
            }
            if ($cross_name){
                $seen_cross_names{$cross_name}++;
            }
        }

        if (!defined($operator_name) || $operator_name eq '') {
            push @error_messages, "Cell F$row_name: operator_name missing";
        }

        if (!defined($amount) || $amount eq '') {
            push @error_messages, "Cell G$row_name: amount missing";
        }
        if (!defined($weight) || $weight eq '') {
            push @error_messages, "Cell H$row_name: weight(g) missing";
        }
        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "On row:$row_name you must provide either a weight in grams or a seed count amount.";
        }
    }

    my @plants = keys %seen_plant_names;
    my $plant_validator = CXGN::List::Validate->new();
    my @plants_missing = @{$plant_validator->validate($schema,'plants',\@plants)->{'missing'}};

    if (scalar(@plants_missing) > 0) {
        push @error_messages, "The following plant_names are not in the database as uniquenames: ".join(',', @plants_missing);
        $errors{'missing_plants'} = \@plants_missing;
    }

    my @plots = keys %seen_plot_names;
    my $plot_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plot_validator->validate($schema,'plots',\@plants)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        push @error_messages, "The following plot_names are not in the database as uniquenames: ".join(',', @plots_missing);
        $errors{'missing_plants'} = \@plots_missing;
    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
        $errors{'missing_accessions'} = \@accessions_missing;
    }

    my @crosses = keys %seen_cross_names;
    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',\@crosses)->{'missing'}};

    if (scalar(@crosses_missing) > 0) {
        push @error_messages, "The following crosses are not in the database: ".join(',',@crosses_missing);
        $errors{'missing_crosses'} = \@crosses_missing;
    }

    # Not checking if seedlot name already exists because the database will just update the seedlot entries
    # my @seedlots = keys %seen_seedlot_names;
    # my $rs = $schema->resultset("Stock::Stock")->search({
    #     'is_obsolete' => { '!=' => 't' },
    #     'uniquename' => { -in => \@seedlots }
    # });
    # while (my $r=$rs->next){
    #     push @error_messages, "Cell A".$seen_seedlot_names{$r->uniquename}.": seedlot name already exists in database: ".$r->uniquename;
    # }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;
    my %parsed_seedlots;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_plant_names;
    my %seen_plot_names;
    my %seen_accession_names;
    my %seen_cross_names;
    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $plant_name;
        my $plot_name;
        my $accession_name;
        my $cross_name;
        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
            $seen_seedlot_names{$seedlot_name}++;
        }
        if ($worksheet->get_cell($row,1)) {
            $plant_name = $worksheet->get_cell($row,1)->value();
            $seen_plant_names{$plant_name}++;
        }
        if ($worksheet->get_cell($row,2)) {
            $plot_name = $worksheet->get_cell($row,2)->value();
            $seen_plot_names{$plot_name}++;
        }
        if ($worksheet->get_cell($row,3)) {
            $accession_name = $worksheet->get_cell($row,3)->value();
            $seen_accession_names{$accession_name}++;
        }
        if ($worksheet->get_cell($row,4)) {
            $cross_name = $worksheet->get_cell($row,4)->value();
            $seen_cross_names{$cross_name}++;
        }
    }
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

    #If plants are being given as the source, we create a quick lookup to get the stock_ids
    my @plants = keys %seen_plant_names;
    my %seen_plant_stock_ids;
    my $plant_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plants },
        'type_id' => $plant_cvterm_id
    });
    my %plant_lookup;
    while (my $r=$plant_rs->next){
        $plant_lookup{$r->uniquename} = $r->stock_id;
        $seen_plant_stock_ids{$r->stock_id}++;
    }

    #If plants are being given as the source we still need to know the accession of the plant and link the seedlot to that same accession
    my @plant_stock_ids = keys %seen_plant_stock_ids;
    my $plant_accession_rs = $schema->resultset("Stock::StockRelationship")->search({
        type_id => $plant_of_cvterm_id,
        subject_id => { -in => \@plant_stock_ids }
    }, { join => 'object', '+select' => ['object.uniquename'], '+as' => ['accession_name'] } );
    my %plant_accession_lookup;
    while (my $r=$plant_accession_rs->next){
        $plant_accession_lookup{$r->subject_id} = [$r->object_id, $r->get_column('accession_name')];
    }

    #If plots are being given as the source, we create a quick lookup to get the stock_ids
    my @plots = keys %seen_plot_names;
    my %seen_plot_stock_ids;
    my $plot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plots },
        'type_id' => $plot_cvterm_id
    });
    my %plot_lookup;
    while (my $r=$plot_rs->next){
        $plot_lookup{$r->uniquename} = $r->stock_id;
        $seen_plot_stock_ids{$r->stock_id}++;
    }

    #If plots are being given as the source we still need to know the accession of the plot and link the seedlot to that same accession
    my @plot_stock_ids = keys %seen_plot_stock_ids;
    my $plot_accession_rs = $schema->resultset("Stock::StockRelationship")->search({
        type_id => $plot_of_cvterm_id,
        subject_id => { -in => \@plot_stock_ids }
    }, { join => 'object', '+select' => ['object.uniquename'], '+as' => ['accession_name'] } );
    my %plot_accession_lookup;
    while (my $r=$plot_accession_rs->next){
        $plot_accession_lookup{$r->subject_id} = [$r->object_id, $r->get_column('accession_name')];
    }

    my @accessions = keys %seen_accession_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@accessions },
        'type_id' => $accession_cvterm_id,
    });
    my %accession_lookup;
    while (my $r=$rs->next){
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@accessions},
        'me.type_id' => $accession_cvterm_id,
        'stockprops.type_id' => $synonym_cvterm_id
    },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
    my %acc_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }
    my @crosses = keys %seen_cross_names;
    my $cross_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@crosses },
        'type_id' => $cross_cvterm_id
    });
    my %cross_lookup;
    while (my $r=$cross_rs->next){
        $cross_lookup{$r->uniquename} = $r->stock_id;
    }
    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seedlots },
        'type_id' => $seedlot_cvterm_id
    });
    my %seedlot_lookup;
    while (my $r=$seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $plant_name;
        my $plot_name;
        my $accession_name;
        my $cross_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $plant_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $plot_name = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $accession_name = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $cross_name = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $operator_name =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $amount =  $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $weight =  $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $description =  $worksheet->get_cell($row,8)->value();
        }
        if ($worksheet->get_cell($row,9)) {
            $box_name =  $worksheet->get_cell($row,9)->value();
        }

        #skip blank lines
        if (!$seedlot_name && !$plant_name && !$plot_name && !$accession_name && !$cross_name && !$description) {
            next;
        }

        #Becuase the uploaded file should contain ONLY ONE OF: source_plant_name OR source_plot_name OR source_accession_name OR source_cross_name in the case that a plant_name or a plot_name is given we still need to find the source_accession of the plant or plot, so that the seedlot can be linked to the same accession.
        my $accession_stock_id;
        my $plant_stock_id;
        my $plot_stock_id;
        if ($accession_name){
            if ($acc_synonyms_lookup{$accession_name}){
                my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
                if (scalar(@accession_names)>1){
                    print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
                }
                $accession_name = $accession_names[0];
                $accession_stock_id = $acc_synonyms_lookup{$accession_name}->{$accession_name};
            } else {
                $accession_stock_id = $accession_lookup{$accession_name};
            }
        } elsif ($plant_name){
            $plant_stock_id = $plant_lookup{$plant_name};
            $accession_stock_id = $plant_accession_lookup{$plant_stock_id}->[0];
            $accession_name = $plant_accession_lookup{$plant_stock_id}->[1];
        } elsif ($plot_name){
            $plot_stock_id = $plot_lookup{$plot_name};
            $accession_stock_id = $plot_accession_lookup{$plot_stock_id}->[0];
            $accession_name = $plot_accession_lookup{$plot_stock_id}->[1];
        }

        $parsed_seedlots{$seedlot_name} = {
            seedlot_id => $seedlot_lookup{$seedlot_name}, #If seedlot name already exists, this will allow us to update information for the seedlot
            source_accession => $accession_name,
            source_accession_stock_id => $accession_stock_id,
            source_cross_name => $cross_name,
            source_cross_stock_id => $cross_lookup{$cross_name},
            source_plant => $plant_name,
            source_plant_stock_id => $plant_stock_id,
            source_plot => $plot_name,
            source_plot_stock_id => $plot_stock_id,
            amount => $amount,
            weight_gram => $weight,
            description => $description,
            box_name => $box_name,
            operator_name => $operator_name
        };
    }
    #print STDERR Dumper \%parsed_seedlots;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;
}


1;
