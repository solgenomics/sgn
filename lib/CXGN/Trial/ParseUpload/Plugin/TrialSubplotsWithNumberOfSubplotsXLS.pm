package CXGN::Trial::ParseUpload::Plugin::TrialSubplotsWithNumberOfSubplotsXLS;

use Moose::Role;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my SGN::I18N $ui_trialsubplotswithnumberofsubplotsxls_i18n = $c && $c->can('i18n') ? $c->i18n : undef;

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
        push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "seedlot_maintenance_upload.parse.first_sheet", "Spreadsheet must be on 1st tab in Excel (.xls) file"));
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.upload.multi.excel.header_or_rows", "Spreadsheet is missing header or contains no rows"));
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $plot_name_head;
    my $num_subplots_per_plot_head;

    if ($worksheet->get_cell(0,0)) {
        $plot_name_head  = $worksheet->get_cell(0,0)->value();
        $plot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $num_subplots_per_plot_head  = $worksheet->get_cell(0,1)->value();
        $num_subplots_per_plot_head =~ s/^\s+|\s+$//g;
    }
    if (!$plot_name_head || $plot_name_head ne 'plot_name' ) {
        push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.header_cell", "Cell %{cell}: %{field} is missing from the header", {cell => "A1", field => "plot_name"}));
    }
    if (!$num_subplots_per_plot_head || $num_subplots_per_plot_head ne 'num_subplots_per_plot') {
        push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.header_cell", "Cell %{cell}: %{field} is missing from the header", {cell => "B1", field => "num_subplots_per_plot"}));
    }

    my %seen_plot_names;
    my %seen_subplot_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $plot_name;
        my $num_subplots_per_plot;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            $plot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $num_subplots_per_plot = $worksheet->get_cell($row,1)->value();
        }

        if (!$plot_name || $plot_name eq '' ) {
            push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.cell_missing_dot", "Cell %{cell}: %{field} missing.", {cell => "A$row_name", field => "plot_name"}));
        }
        elsif ($plot_name =~ /\s/ || $plot_name =~ /\// || $plot_name =~ /\\/ ) {
            push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.cell_spaces", "Cell %{cell}: %{field} must not contain spaces or slashes.", {cell => "A$row_name", field => "plot_name"}));
        }
        else {
            $seen_plot_names{$plot_name}=$row_name;
        }

        if (!$num_subplots_per_plot || $num_subplots_per_plot eq '') {
            push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.cell_missing", "Cell %{cell}: %{field} missing", {cell => "B$row_name", field => "num_subplots_per_plot"}));
        } if (!($num_subplots_per_plot =~ /^\d+?$/)) {
            push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.cell_number", "Cell %{cell}: %{field} must be a number", {cell => "B$row_name", field => "num_subplots_per_plot"}));
        } else {
            #file must not contain duplicate subplot names
            for my $i (1 .. $num_subplots_per_plot) {
                my $subplot_name = $plot_name."_subplot_".$i;
                if ($seen_subplot_names{$subplot_name}) {
                    push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.duplicate_cell", "Cell %{cell}: duplicate %{field} at cell %{previous}: %{name}", {cell => "B$row_name", field => "subplot_name", previous => "A".$seen_subplot_names{$subplot_name}, name => "$subplot_name"}));
                }
                if (!$subplot_name){
                    push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.subplot_name_unavailable", "CellB%{row}: No subplot name could be made!", {row => "$row_name"}));
                }
                $seen_subplot_names{$subplot_name}++;
            }
        }

    }

    my @plots = keys %seen_plot_names;
    my $plots_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plots_validator->validate($schema,'plots',\@plots)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.parent_names_missing", "The following %{field} are not in the database: %{names}", {field => "plot_name", names => join(',',@plots_missing)}));
        $errors{'missing_plots'} = \@plots_missing;
    }

    my @subplots = keys %seen_subplot_names;
    my $subplot_rs = $schema->resultset('Stock::Stock')->search({ 'uniquename' => {-in => \@subplots} });
    while (my $r = $subplot_rs->next){
        push @error_messages, (SGN::I18N::translate($ui_trialsubplotswithnumberofsubplotsxls_i18n, "trial.parse.name_not_unique", "The following %{field} is already in the database and is not unique %{name}", {field => "subplot_name", name => "" . ($r->uniquename)}));
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
    my %parsed_entries;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_plot_names;
    for my $row ( 1 .. $row_max ) {
        my $plot_name;
        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            $plot_name =~ s/^\s+|\s+$//g;
            $seen_plot_names{$plot_name}++;
        }
    }
    my @plots = keys %seen_plot_names;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plots },
        'type_id' => $plot_cvterm_id
    });
    my %plot_lookup;
    while (my $r=$rs->next){
        $plot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $plot_name;
        my $num_subplots_per_plot;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            $plot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $num_subplots_per_plot = $worksheet->get_cell($row,1)->value();
        }

        for my $i (1 .. $num_subplots_per_plot) {
            my $subplot_name = $plot_name."_subplot_".$i;

            #skip blank lines
            if (!$plot_name && !$subplot_name) {
                next;
            }

            push @{$parsed_entries{'data'}}, {
                plot_name => $plot_name,
                plot_stock_id => $plot_lookup{$plot_name},
                subplot_name => $subplot_name,
                subplot_index_number => $i
            };
        }
    }

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
