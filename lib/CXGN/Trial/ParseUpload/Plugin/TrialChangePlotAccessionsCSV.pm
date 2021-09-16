package CXGN::Trial::ParseUpload::Plugin::TrialChangePlotAccessionsCSV;

use Moose::Role;
use CXGN::Stock::StockLookup;
use Text::CSV;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use Scalar::Util qw(looks_like_number);

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_id = $self->get_trial_id();
    my @error_messages;
    my %errors;
    my %parse_errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!"."<br>";

    if (!$fh) {
        push @error_messages, "Could not read file."."<br>";
        print STDERR "Could not read file.\n";
        $parse_errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%parse_errors);
        return;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row."."<br>";
        print STDERR "Could not parse header.\n";
        $parse_errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%parse_errors);
        return;
    }

    my $num_cols = scalar(@columns);

    if ( $columns[0] ne "plot_name" ||
        $columns[1] ne "accession_name" ) {
            push @error_messages, 'File contents incorrect. Header row must contain:  "plot_name","accession_name"'."<br>";
            print STDERR "File contents incorrect.\n";
            $parse_errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%parse_errors);
            return;
    }

    my %seen_plot_names;
    my %seen_accession_names;
    my %seen_new_plot_names;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row."."<br>";
            print STDERR "Could not parse row $row.\n";
            return;
        }

        if (scalar(@columns) != $num_cols){
            push @error_messages, "All lines must have same number of columns as header! Error on row: $row"."<br>";
            print STDERR "Line $row does not have complete columns.\n";
            return;
        }

        $seen_plot_names{$columns[0]}++;
        $seen_accession_names{$columns[1]}++;
        if ($columns[2]) {
            $seen_new_plot_names{$columns[2]}++;
        }
    }
    if (@error_messages) {
        $parse_errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%parse_errors);
    }
    close($fh);

    my @plots = keys %seen_plot_names;
    my $plots_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plots_validator->validate($schema,'plots',\@plots)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        push @error_messages, "The following plots are not in the database as uniquenames or synonyms:<br>".join(", ",@plots_missing)."<br>";
    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms:<br>".join(", ",@accessions_missing)."<br>";
    }

    my @not_valid_names;
    if (keys %seen_new_plot_names) {
        my @new_plot_names = keys %seen_new_plot_names;
        my $new_plot_name_validator = CXGN::List::Validate->new();
        my @valid_new_plot_names = @{$new_plot_name_validator->validate($schema,'plots',\@new_plot_names)->{'missing'}};
        if (scalar(@valid_new_plot_names) != scalar(@new_plot_names)) {
            for (@new_plot_names) {
                my $validation = 0;
                my $current_name = $_;
                for (@valid_new_plot_names) {
                    if ($current_name == $_) {
                        $validation = 1;
                    }
                }  
                if (!$validation) {
                    push @not_valid_names, $current_name;
                }
            }
        }
    }

    if (@not_valid_names) {
        push @error_messages, "The following new plot names already exist in the database:<br>".join(", ", @not_valid_names)."<br>";
    }
    
    my @plots_in_different_trial;

    my $q = "SELECT * FROM plotsxtrials WHERE trial_id = ?";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($trial_id);
    my @plot_ids_in_current_trial;
    while(my ($trial_plot_id) = $h->fetchrow_array()){
        push @plot_ids_in_current_trial, $trial_plot_id;
    }

    my %stock_id_map;
    for (@plots) {
        my $stock_rs = $schema->resultset("Stock::Stock")->search({
            uniquename => {'-in' => \@plots}
        });
        while (my $r = $stock_rs->next()){
            $stock_id_map{$r->uniquename} = $r->stock_id;
        }
    }

    for (@plots) {
        my $current_name = $_;
        my $validation = 0;
        for (@plot_ids_in_current_trial) {
            if ($stock_id_map{$current_name} == $_) {
                $validation = 1;
            }
        }
        for (@plots_missing) {
            if ($current_name == $_) {
                $validation = 1;
            }
        }
        if (!$validation) {
            push @plots_in_different_trial, $current_name;
        }

    }

    if (@plots_in_different_trial) {
        push @error_messages, "The following plot names belong to a different trial:<br>".join(", ", @plots_in_different_trial)."<br>";
    }

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
    my %parsed_entries;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    my $header_row = <$fh>;

    my $counter = 1;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        }
        my $plot_name = $columns[0];
        my $accession_name = $columns[1];
        my $new_plot_name;
        if ($columns[2]) {
            $new_plot_name = $columns[2];
        }
        $parsed_entries{$counter} = {
            plot_name => $plot_name,
            accession_name => $accession_name,
            new_plot_name => $new_plot_name 
        };
        $counter++;
    }
    close($fh);

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
