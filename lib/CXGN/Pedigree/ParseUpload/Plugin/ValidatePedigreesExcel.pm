package CXGN::Pedigree::ParseUpload::Plugin::ValidatePedigreesExcel;

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

    #currently supported cross types
    $supported_cross_types{'biparental'} = 1; #both parents required
    $supported_cross_types{'self'} = 1; #only female parent required
    $supported_cross_types{'open'} = 1; #only female parent required
    $supported_cross_types{'sib'} = 1; #both parents required but can be the same
    $supported_cross_types{'bulk'} = 1; #both female population and male accession required
    $supported_cross_types{'bulk_self'} = 1; #only female population required
    $supported_cross_types{'bulk_open'} = 1; #only female population required, male parent can be a population or unknown
    $supported_cross_types{'doubled_haploid'} = 1; #only female parent required
    $supported_cross_types{'dihaploid_induction'} = 1; # ditto
    $supported_cross_types{'polycross'} = 1; #both parents required
    $supported_cross_types{'backcross'} = 1; #both parents required, parents can be cross or accession stock type

    #try to open the excel file and report any errors
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
    if (($col_max - $col_min)  < 3 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of pedigree
        push @error_messages, "Spreadsheet is missing header or contains no row";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $progeny_name_header;
    my $female_parent_header;
    my $male_parent_header;
    my $type_header;

    if ($worksheet->get_cell(0,0)) {
        $progeny_name_header  = $worksheet->get_cell(0,0)->value();
        $progeny_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $female_parent_header  = $worksheet->get_cell(0,1)->value();
        $female_parent_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $male_parent_header  = $worksheet->get_cell(0,2)->value();
        $male_parent_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $type_header  = $worksheet->get_cell(0,3)->value();
        $type_header =~ s/^\s+|\s+$//g;
    }

    if (!$progeny_name_header || $progeny_name_header ne 'progeny name' ) {
        push @error_messages, "Cell A1: progeny name is missing from the header";
    }
    if (!$female_parent_header || $female_parent_header ne 'female parent' ) {
        push @error_messages, "Cell B1: female parent is missing from the header";
    }
    if (!$male_parent_header || $male_parent_header ne 'male parent') {
        push @error_messages, "Cell C1: male parent is missing from the header";
    }
    if (!$type_header || $type_header ne 'type') {
        push @error_messages, "Cell D1: type is missing from the header";
    }

    my %seen_accession_names;
    my %seen_population_names;
    my %seen_backcross_parents;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $progeny_name;
        my $female_parent;
        my $male_parent;
        my $type;

        if ($worksheet->get_cell($row,0)) {
            $progeny_name = $worksheet->get_cell($row,0)->value();
            $progeny_name =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)) {
            $female_parent =  $worksheet->get_cell($row,1)->value();
            $female_parent =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,2)) {
            $male_parent = $worksheet->get_cell($row,2)->value();
            $male_parent =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,3)) {
            $type =  $worksheet->get_cell($row,3)->value();
            $type =~ s/^\s+|\s+$//g;
        }

        if (!defined $progeny_name && !defined $female_parent && !defined $male_parent) {
            last;
        }

        #cross name must not be blank
        if (!$progeny_name || $progeny_name eq '') {
            push @error_messages, "Cell A$row_name: progeny name missing";
        }

        if (!$female_parent || $female_parent eq '') {
            push @error_messages, "Cell B$row_name: female parent missing";
        }

        #cross type must not be blank
        if (!$type || $type eq '') {
            push @error_messages, "Cell D$row_name: type missing";
        } elsif (!$supported_cross_types{$type}){
            push @error_messages, "Cell D$row_name: type not supported: $type";
        }

        if (!$male_parent || $male_parent eq '') {
            if ($type eq ( 'biparental' || 'bulk' || 'sib' || 'polycross' || 'backcross' )) {
                push @error_messages, "Cell C$row_name: male parent required for biparental, sib, polycross, backcross and bulk cross types";
            }
        }

        if ($progeny_name){
            $seen_accession_names{$progeny_name}++;
        }

        if (($type eq 'bulk') || ($type eq 'bulk_self') || ($type eq 'bulk_open')) {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_population_names{$female_parent}++;
            if ($type eq 'bulk_open') {
                if ($male_parent) {
                    $male_parent =~ s/^\s+|\s+$//g;
                    $seen_population_names{$male_parent}++;
                }
            } elsif ($type eq 'bulk') {
                $male_parent =~ s/^\s+|\s+$//g;
                $seen_accession_names{$male_parent}++;
            }
        } elsif (($type eq 'polycross') || ($type eq 'open')) {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_accession_names{$female_parent}++;
            if ($male_parent) {
                $male_parent =~ s/^\s+|\s+$//g;
                $seen_population_names{$male_parent}++;
            }
        } elsif ($type eq 'backcross') {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_backcross_parents{$female_parent}++;
            $male_parent =~ s/^\s+|\s+$//g;
            $seen_backcross_parents{$male_parent}++;
        } else {
            $female_parent =~ s/^\s+|\s+$//g;
            $seen_accession_names{$female_parent}++;

            if ($male_parent){
                $male_parent =~ s/^\s+|\s+$//g;
                $seen_accession_names{$male_parent}++;
            }
        }

    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames',\@accessions)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following parents or progenies are not in the database, or are not in the database as accession uniquenames: ".join(',',@accessions_missing);
        $errors{'missing_accessions'} = \@accessions_missing;
    }

    my @populations = keys %seen_population_names;
    my $population_validator = CXGN::List::Validate->new();
    my @populations_missing = @{$population_validator->validate($schema,'populations',\@populations)->{'missing'}};
    if (scalar(@populations_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as population uniquenames: ".join(',',@populations_missing);
    }

    my @backcross_parents = keys %seen_backcross_parents;
    my $backcross_parent_validator = CXGN::List::Validate->new();
    my @backcross_parents_missing = @{$backcross_parent_validator->validate($schema,'accessions_or_crosses',\@backcross_parents)->{'missing'}};
    if (scalar(@backcross_parents_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as uniquenames: ".join(',',@backcross_parents_missing);
        $errors{'missing_accessions_or_crosses'} = \@backcross_parents_missing;
    }

    print STDERR "ERROR MESSAGES =".Dumper(\@error_messages)."\n";

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
    my @pedigrees;
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $progeny_name;
        my $female_parent;
        my $male_parent;
        my $type;
        my $female_parent_individual;
        my $male_parent_individual;

        if ($worksheet->get_cell($row,0)) {
            $progeny_name = $worksheet->get_cell($row,0)->value();
            $progeny_name =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)) {
            $female_parent =  $worksheet->get_cell($row,1)->value();
            $female_parent =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,2)) {
            $male_parent = $worksheet->get_cell($row,2)->value();
            $male_parent =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,3)) {
            $type =  $worksheet->get_cell($row,3)->value();
            $type =~ s/^\s+|\s+$//g;
        }

        if (!defined $progeny_name && !defined $female_parent && !defined $type) {
            last;
        }

        if ($female_parent) {
            $female_parent_individual = Bio::GeneticRelationships::Individual->new(name => $female_parent);
        }
        if ($male_parent) {
            $male_parent_individual = Bio::GeneticRelationships::Individual->new(name => $male_parent);
        }

        my $pedigree_info = {
            cross_type => $type,
            female_parent => $female_parent_individual,
            name => $progeny_name,
        };

        if ($male_parent) {
            $pedigree_info->{male_parent} = $male_parent_individual;
        }

        my $pedigree = Bio::GeneticRelationships::Pedigree->new($pedigree_info);
        push @pedigrees, $pedigree;
    }

    $parsed_result{'pedigrees'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
