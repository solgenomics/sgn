package CXGN::Stock::Seedlot::ParseUpload::Plugin::CreateMissingAccessionsForSeedlots;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

has 'missing_data_by_pedigree' => (
    isa => 'HashRef',  # keyed by pedigree
    is => 'rw',
    );

has 'missing_data_by_seedlot' => (
    isa => 'HashRef',  # keyed by pedigree
    is => 'rw',
    );

has 'pedigrees_not_in_db' => (
    isa => 'HasRef',
    is => 'rw',
    );

has 'seedlots_not_in_db' => (
    isa => 'HashRef',
    is => 'rw',
    );



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
    my %seen_ped_names;

    my %missing_data_by_pedigree; # keyed by Pedigree
    my %missing_data_by_seedlot;
    
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;

	my $inv_no;
	my $accession_name;
        my $seedlot_name;
        my $pedigree;
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
            $pedigree = $worksheet->get_cell($row,2)->value();
	    $pedigree =~ s/^\s+|\s+$//g;
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
        if ($worksheet->get_cell($row, 7)) {
            $original_wt_g = $worksheet->get_cell($row, 7)-> value();
	    $original_wt_g =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row, 8)) {
            $current_wt_g = $worksheet->get_cell($row, 8)-> value();
	    $current_wt_g =~ s/^\s+|\s+$//g;
        }

	if ($worksheet->get_cell($row, 9)) {
            $storage_location = $worksheet->get_cell($row, 9)-> value();
	    $storage_location =~ s/^\s+|\s+$//g;
        }

	if ($worksheet->get_cell($row, 10)) {
            $comments = $worksheet->get_cell($row, 10)-> value();
	    $comments =~ s/^\s+|\s+$//g;
        }

	if ($worksheet->get_cell($row, 11)) {
            $in_inv = $worksheet->get_cell($row, 11)-> value();
	    $in_inv =~ s/^\s+|\s+$//g;
        }

	if ($worksheet->get_cell($row, 12)) {
            $to_be_discarded = $worksheet->get_cell($row, 12)-> value();
	    $to_be_discarded =~  s/^\s+|\s+$//g;
        }

	if ($worksheet->get_cell($row, 14)) {
            $issues = $worksheet->get_cell($row, 14)-> value();
	    $issues =~ s/^\s+|\s+$//g;
        }

        if (!defined $seedlot_name && !defined $pedigree) {
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
	}
	
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

	if (!defined($comments) || $comments eq '') {
	    push @info_messages, "Cell K$row_name: comments missing";
	}

	if (!defined($in_inv) || $in_inv eq '') {
	    push @info_messages, "Cell L$row_name: InInv missing";
	}

	if (!defined($to_be_discarded) || $to_be_discarded eq '') {
	    push @info_messages, "Cell M$row_name: to be discarded missing";
	}

	if (!defined($issues) || $issues eq '') {
	    push @info_messages, "Cell N$row_name : issues missing";
	}

	my %data;
	if (! $accession_name && $pedigree && $inv_no) {  # we have no accession name, but a pedigree and seedlot name (inv_no)
	    $data{inv_no} = $inv_no;
	    $data{source} = $source;
	    $data{pedigree} = $pedigree;
	    $data{YL} = $YL;
	    $data{breeder}  = $breeder;
	    $data{original_wt_g} = $original_wt_g;
	    $data{current_wt_g} = $current_wt_g;
	    $data{storage_location} = $storage_location;
	    $data{comments} = $comments;
	    $data{in_inv} = $in_inv;
	    $data{to_be_discarded} = $to_be_discarded;
	    $data{issues} = $issues;
	    
	    $missing_data_by_pedigree{$pedigree}->{$inv_no} = \%data;
	    $missing_data_by_seedlot{$seedlot_name} = \%data;
	    
	}
    }
    
    
    
    print STDERR "Check pedigrees in database...\n";
    my %pedigrees_not_in_db;
    my %pedigrees_in_db;
    my %seedlots_not_in_db;

    my $pedigree_type_row = SGN::Cvterm::Model->get_cvterm_row($self->get_chado_schema(), "stock_property", "Pedigree");

    if (! $pedigree_type_row) {
	die "The stock property 'Pedigree' does not exist in this database. Please add it and then try again.";
    }

    my $pedigree_type_id = $pedigree_type_row->cvterm_id();

    my $seedlot_type_id = SGN::Cvterm::Model->get_cvterm_row($self->get_chado_schema(), "stock_property", "seedlot")->cvterm_id();
    
    my @peds = keys %seen_ped_names;
    ## to do: check if pedigrees are in database
    foreach my $p (@peds) { 
	my $rs = $self->get_chado_schema("Stock::Stockprop")->search( { value => $p, type_id => $pedigree_type_id } );
	if ($rs->count() > 1) {
	    die "$p occurs twice in the database. Please fix this and then continue.";
	}

	elsif ($rs->count() == 0) {
	    $pedigrees_not_in_db{$p}++;
	}
	else {
	    $pedigrees_in_db{$p}++;
	}   
    }

    ###@error_messages = (@error_messages, %pedigrees_not_in_db);
    
    # Check if Seedlot names already exist as other stock names
    my @seedlots = keys %seen_seedlot_names;

    foreach my $sl (@seedlots) { 
	my $rs = $schema->resultset("Stock::Stock")->search( {'uniquename' => $sl } );

	if ($rs->count() == 0) { $seedlots_not_in_db{$sl}++; }
	else { 
	    while (my $r=$rs->next) {
		if ( $r->type->name ne 'seedlot' ) {
		    push @error_messages, "Cell A".$seen_seedlot_names{$r->uniquename}.": stock name already exists in database: ".$r->uniquename.".  The seedlot name must be unique.";
		}
	    }
	}
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # info message don't invalidate parsing
    #
    if (scalar(@info_messages) >= 1) {
	$self->_set_info_messages( \@info_messages );
    }

    $self->pedigrees_in_db(\%pedigrees_in_db);
    $self->pedigrees_not_in_db(\%pedigrees_not_in_db);
    $self->missing_data_by_pedigree(\%missing_data_by_pedigree);
    $self->missing_data_by_seedlot(\%missing_data_by_seedlot);
    $self->seedlots_not_in_db(\%seedlots_not_in_db);
    
    return 1; #returns true if validation is passed
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my %parsed_seedlots;
    
    if ($self->_validate_with_plugin()) { 
	
	foreach my $seedlot (keys %{$self->seedlots_not_in_db()}) {
	    my $accession_name;
	    my $accession_stock_id;
	    
	    # check if the pedigree is in the database
	    #
	    if (exists($self->missing_data_by_seedlot->{$seedlot})) { 
		my $pedigree = $self->missing_data_by_seedlot->{$seedlot}->{pedigree};

		# if yes, fetch the corresponding accession and assign that
		# to the seedlot in the parsed_seedlots data structure
		#
		if ($self->pedigrees_in_db->{$pedigree}) {
		    my $sp = $self->get_chado_schema->resultset("Stock::Stockprop")->find( { value => $pedigree, 'type.value' => 'Pedigree' });
		    my $a =  CXGN::Stock->new( { schema => $self->get_chado_schema(), stock_id => $sp->stock_id() } );
		    
		    $accession_stock_id = $a->accession_id();
                }		    

		# if not, create the accession using the naming template
		# and assign it to the parsed seedlots data structure
		#
		else { 
		    $accession_name = CXGN::Stock->next_accession_name($self->get_chado_schema(), $self->accession_name_template);
		    
		    my $a = CXGN::Stock->new( { schema => $self->get_chado_schema() } );
		    $a->accession_name($accession_name);
		    $a->store();
		    
		    $accession_stock_id = $a->accession_id();
		}
		
	    
		$parsed_seedlots{$seedlot} = {
		    ####seedlot_id => $seedlot_lookup{$seedlot}, #If seedlot name already exists, this will allow us to update information for the seedlot
		    accession => $accession_name,
		    accession_stock_id => $accession_stock_id,
		    cross_name => undef,
		    cross_stock_id => undef,
		    weight_gram => $self->missing_data_by_seedlot->{$seedlot}->{current_weight_in_g},
		    description => $self->missing_data_by_seedlot->{$seedlot}->{comments},
		    box_name => $self->missing_data_by_seedlot->{$seedlot}->{storage_location},
		    operator_name => $self->missing_data_by_seedlot->{$seedlot}->{breeder},
		    quality => $self->missing_data_by_seedlot->{$seedlot}->{quality},
		    source => $self->missing_data_by_seedlot->{$seedlot}->{source},
		};
	    }
	}
    }
    print STDERR Dumper \%parsed_seedlots;

    $self->_set_parsed_data(\%parsed_seedlots);

    return 1;
}
    


1;
