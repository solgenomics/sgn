package CXGN::Stock::Seedlot::ParseUpload::Plugin::CreateMissingAccessionsForSeedlots;

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

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my @error_messages;
    my @info_messages;
    my %errors;
    my %missing_accessions;

    ## header in the seedlot file:
    ## (empty-accession name would go here)	InvNo	Ped	Source	YL	Descr	Breeder	Original Wt (g)	Current Wt (g)	Storage Location	Comments	InInv	To be discarded	Issues

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

    my $accession_name_header;
    my $inv_no_header;
    my $ped_header;

    if ($worksheet->get_cell(0,0)) {
        $accession_name_header  = $worksheet->get_cell(0,0)->value();
        $accession_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $inv_no_header = $worksheet->get_cell(0,1)->value();
        $inv_no_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $ped_header  = $worksheet->get_cell(0,2)->value();
        $ped_header =~ s/^\s+|\s+$//g;
    }

    if ($accession_name_header) {
	print STDERR "The accession column should have an empty header, not $accession_name_header\n";	
    }
    if (!$inv_no_header || $inv_no_header ne 'InvNo') {
        push @error_messages, "Cell B1: InvNo is missing from the header";
    }
    if (!$ped_header || $ped_header ne 'Ped') {
        push @error_messages, "Cell C1: Ped is missing from the header";
    }

    my %seen_seedlot_names;
    my %seen_accession_names;
    my %seen_source_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;

	my $accession_name;
        my $seedlot_name;
        my $ped_name;
	my $source;
	my $YL;
	my $desc;
	my $breeder;
	my $original_wt_g;
	my $current_wt_g;
	my $storage_location;
	my $comments;
	my $in_inv;
	my $to_be_discarded;
	my $issues;
	
        if ($worksheet->get_cell($row,0)) {
            $accession_name = $worksheet->get_cell($row,0)->value();
	    $accession_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $seedlot_name = $worksheet->get_cell($row,1)->value();
	    $seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $ped_name = $worksheet->get_cell($row,2)->value();
	    $ped_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $source =  $worksheet->get_cell($row,3)->value();
	    $source =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $YL =  $worksheet->get_cell($row,4)->value();
	    $YL =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $desc =  $worksheet->get_cell($row,5)->value();
	    $desc =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $breeder =  $worksheet->get_cell($row,6)->value();
	    $breeder =~ s/^\s+|\s+$//g;
        }
        if ($seedlot_quality && $worksheet->get_cell($row, 7)) {
            $original_wt_g = $worksheet->get_cell($row, 7)-> value();
	    $original_wt_g =~ s/^\s+|\s+$//g;
        }
        if ($seedlot_quality && $worksheet->get_cell($row, 8)) {
            $current_wt_g = $worksheet->get_cell($row, 8)-> value();
	    $current_wt_g =~ s/^\s+|\s+$//g;
        }

	if ($seedlot_quality && $worksheet->get_cell($row, 9)) {
            $storage_location = $worksheet->get_cell($row, 9)-> value();
	    $storage_location =~ s/^\s+|\s+$//g;
        }

	if ($seedlot_quality && $worksheet->get_cell($row, 10)) {
            $comments = $worksheet->get_cell($row, 10)-> value();
	    $comments =~ s/^\s+|\s+$//g;
        }

	if ($seedlot_quality && $worksheet->get_cell($row, 11)) {
            $in_inv = $worksheet->get_cell($row, 11)-> value();
	    $in_inv =~ s/^\s+|\s+$//g;
        }

	if ($seedlot_quality && $worksheet->get_cell($row, 12)) {
            $to_be_discarded = $worksheet->get_cell($row, 12)-> value();
	    $to_be_discarded =~  s/^\s+|\s+$//g;
        }

	if ($seedlot_quality && $worksheet->get_cell($row, 14)) {
            $issues = $worksheet->get_cell($row, 14)-> value();
	    $issues =~ s/^\s+|\s+$//g;
        }

        if (!defined $seedlot_name && !defined $ped_name) {
            last;
        }

        if (!$seedlot_name || $seedlot_name eq '' ) {
            push @error_messages, "Cell B$row_name: seedlot_name missing.";
        }
        elsif ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Cell B$row_name: seedlot_name must not contain spaces or slashes.";
        }
        else {
            #file must not contain duplicate plot names
            if ($seen_seedlot_names{$seedlot_name}) {
                push @error_messages, "Cell B$row_name: duplicate seedlot_name at cell A".$seen_seedlot_names{$seedlot_name}.": $seedlot_name";
            }
            $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_seedlot_names{$seedlot_name}=$row_name;
        }

        if ($accession_name || $accession_name ne '') {  ### OR JUST CHECK IF IT IS LEGAL IN THE DATABASE?
            push @error_messages, "Cell A:$row_name: the accession name field must be empty as it will be generated by the database.";
        }

	if (!defined($desc) || $desc eq '') {
	    push @info_messages, "Cell F$row_name: description missing";

        if (!defined($breeder) || $breeder eq '') {
            push @info_messages, "Cell G$row_name: breeder missing";
        }

        if (!defined($original_wt_g) || $original_wt_g eq '') {
            push @info_messages, "Cell H$row_name: original_wt_g missing";
        }
        if (!defined($current_wt_g) || $current_wt_g eq '') {
            push @info_messages, "Cell I$row_name: current weight(g) missing";
        }
        
        if (!defined($storage_location) || $storage_location eq '') {
            push @error_messages, "Cell J$row_name: storage_location missing";
        }

	if ($source) {
	    $seen_source_names{$source}++;
	}
    }

    my @sources = keys %seen_source_names;
    my $source_validator = CXGN::List::Validate->new();
    my @sources_missing = @{$source_validator->validate($schema,'seedlots_or_plots_or_crosses_or_accessions',\@sources)->{'missing'}};

    if (scalar(@sources_missing) > 0) {
	push @error_messages, "The following source seedlots could not be found in the database: ".join(',',@sources_missing);
	$errors{'missing_sources'} = \@sources_missing;
    }

    # Check if Seedlot names already exist as other stock names
    my @seedlots = keys %seen_seedlot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => \@seedlots }
    });
    while (my $r=$rs->next) {
        if ( $r->type->name ne 'seedlot' ) {
            push @error_messages, "Cell A".$seen_seedlot_names{$r->uniquename}.": stock name already exists in database: ".$r->uniquename.".  The seedlot name must be unique.";
        }
    }

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
    my %parsed_seedlots;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_accession_names;
    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $accession_name;
        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
            $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_seedlot_names{$seedlot_name}++;
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
	    if ($accession_name) { die "Accession name present in row $row, can't continue"; }
        }

        if (!defined $seedlot_name) {
            next;
        }

    }

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

    
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
        my $accession_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;
        my $quality;
        my $source;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $operator_name =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $amount =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $description =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $box_name =  $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $quality = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $source = $worksheet->get_cell($row, 8)->value();
        }

        if (!defined $seedlot_name && !defined $accession_name) {
            last;
        }

        $seedlot_name =~ s/^\s+|\s+$//g; #trim whitespace from front and end...

	$accession_name = CXGN::Stock->next_accession_name();
	
	$source =~ s/^\s+|\s+$//g; # also trim

        my $accession_stock_id;
        if ($acc_synonyms_lookup{$accession_name}){
            my @accession_names = keys %{$acc_synonyms_lookup{$accession_name}};
            if (scalar(@accession_names)>1){
                print STDERR "There is more than one uniquename for this synonym $accession_name. this should not happen!\n";
            }
            $accession_stock_id = $acc_synonyms_lookup{$accession_name}->{$accession_names[0]};
            $accession_name = $accession_names[0];
        } else {
            $accession_stock_id = $accession_lookup{$accession_name};
        }

        my $source_id;

        if ($source) {
            my $source_row = $self->get_chado_schema->resultset("Stock::Stock")->find( { uniquename => $source });
            if ($source_row) {
                $source_id = $source_row->stock_id();
            }
        }

        $parsed_seedlots{$seedlot_name} = {
            seedlot_id => $seedlot_lookup{$seedlot_name}, #If seedlot name already exists, this will allow us to update information for the seedlot
            accession => $accession_name,
            accession_stock_id => $accession_stock_id,
            cross_name => undef,
            cross_stock_id => undef,
            amount => $amount,
            weight_gram => $weight,
            description => $description,
            box_name => $box_name,
            operator_name => $operator_name,
	    quality => $quality,
	    source => $source,
	    source_id => $source_id,
        };

    }
    #print STDERR Dumper \%parsed_seedlots;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;
}


1;
