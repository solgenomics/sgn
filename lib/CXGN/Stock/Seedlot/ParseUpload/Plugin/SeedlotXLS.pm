package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;

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
    my $accession_name_head;
    my $amount_head;
    my $description_head;

    if ($worksheet->get_cell(0,0)) {
        $seedlot_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $accession_name_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $amount_head  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $description_head  = $worksheet->get_cell(0,3)->value();
    }

    if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name' ) {
        push @error_messages, "Cell A1: seedlot_name is missing from the header";
    }
    if (!$accession_name_head || $accession_name_head ne 'accession_name') {
        push @error_messages, "Cell B1: accession_name is missing from the header";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Cell C1: amount is missing from the header";
    }
    if (!$description_head || $description_head ne 'description') {
        push @error_messages, "Cell D1: description is missing from the header";
    }

    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');

    my $rs = $schema->resultset('Stock::Stock')->search(
      { 'me.is_obsolete' => { '!=' => 't' } },
      {
       '+select'=> ['me.uniquename', 'me.type_id'],
       '+as'=> ['uniquename', 'stock_type_id']
      }
    );

    my %seedlot_check;
    while (my $s = $rs->next()) {
        $seedlot_check{$s->get_column('uniquename')} = 1;
    }

    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot_name;
        my $accession_name;
        my $amount;
        my $description;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
        } else {
            $amount = 0;
        }
        if ($worksheet->get_cell($row,3)) {
            $description =  $worksheet->get_cell($row,3)->value();
        }

        if (!$seedlot_name || $seedlot_name eq '' ) {
            push @error_messages, "Cell A$row_name: seedlot_name missing.";
        }
        elsif ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: seedlot_name must not contain spaces or slashes.";
        }
        else {
            if ($seedlot_check{$seedlot_name}) {
                push @error_messages, "Cell A$row_name: seedlot_name already exists: $seedlot_name";
            }

            #file must not contain duplicate plot names
            if ($seen_seedlot_names{$seedlot_name}) {
                push @error_messages, "Cell A$row_name: duplicate seedlot_name at cell A".$seen_seedlot_names{$seedlot_name}.": $seedlot_name";
            }
            $seen_seedlot_names{$seedlot_name}=$row_name;
        }

        #accession name must not be blank
        if (!$accession_name || $accession_name eq '') {
            push @error_messages, "Cell B$row_name: accession name missing";
        } else {
            #accession name must exist in the database
            if (!$self->_get_accession($accession_name)) {
                push @error_messages, "Cell B$row_name: accession name does not exist as a stock or as synonym: $accession_name";
                $missing_accessions{$accession_name} = 1;
            }
        }

        #amount must not be blank
        if (!$amount || $amount eq '') {
            push @error_messages, "Cell C$row_name: amount missing";
        }
    }

    if (scalar( keys %missing_accessions) > 0) {
        my @missing_accessions_list = keys %missing_accessions;
        $errors{'missing_accessions'} = \@missing_accessions_list;
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

    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $accession_name;
        my $accession_stock;
        my $amount;
        my $description;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $accession_name = $worksheet->get_cell($row,1)->value();
            $accession_stock = $self->_get_accession($accession_name);
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
        } else {
            $amount = 0;
        }
        if ($worksheet->get_cell($row,3)) {
            $description =  $worksheet->get_cell($row,3)->value();
        }

        #skip blank lines
        if (!$seedlot_name && !$accession_name && !$description && !$amount) {
            next;
        }

        $parsed_seedlots{$seedlot_name} = {
            accession => $accession_stock->uniquename(),
            accession_stock_id => $accession_stock->stock_id(),
            amount => $amount,
            description => $description
        };
    }

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;
}


sub _get_accession {
    my $self = shift;
    my $accession_name = shift;
    my $schema = $self->get_chado_schema();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $stock = $schema->resultset('Stock::Stock')->search(
      {
          'me.is_obsolete' => { '!=' => 't' },
          'me.type_id' => $accession_cvterm,
          -or => [
              'lower(me.uniquename)' => lc($accession_name),
              -and => [
                  'lower(type.name)' => { like => '%synonym%' },
                  'lower(stockprops.value)' => lc($accession_name),
              ],
          ],
      },
      {
          join => {'stockprops' => 'type'},
          distinct => 1
      }
    );

    if (!$stock) {
        print STDERR "$accession_name is not an accession\n";
        return;
    }
    if ($stock->count != 1){
        print STDERR "Accession name ($accession_name) is not a unique stock unqiuename or synonym\n";
        return;
    }

    return $stock->first();
}

1;
