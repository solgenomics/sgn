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
    my @error_messages;
    my %errors;
    my %parse_result;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        $parse_result{'error'} = "Could not parse header row.";
        print STDERR "Could not parse header.\n";
        return \%parse_result;
    }

    my $num_cols = scalar(@columns);

    if ( $columns[0] ne "plot_name" &&
        $columns[1] ne "accession_name" ) {
            $parse_result{'error'} = 'File contents incorrect. Header row must contain:  "plot_name","accession_name"';
            print STDERR "File contents incorrect.\n";
            return \%parse_result;
    }

    my %seen_plot_names;
    my %seen_accession_names;
    my %seen_new_plot_names;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            $parse_result{'error'} = "Could not parse row $row.";
            print STDERR "Could not parse row $row.\n";
            return \%parse_result;
        }

        if (scalar(@columns) != $num_cols){
            $parse_result{'error'} = 'All lines must have same number of columns as header! Error on row: '.$row;
            print STDERR "Line $row does not have complete columns.\n";
            return \%parse_result;
        }

        $seen_plot_names{$columns[0]}++;
        $seen_accession_names{$columns[1]}++;
        if ($columns[2]) {
            $seen_new_plot_names{$columns[2]}++;
        }
    }
    close($fh);

    my @plots = keys %seen_plot_names;
    my $plots_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plots_validator->validate($schema,'plots',\@plots)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        $errors{'missing_plots'} = \@plots_missing;
        push @error_messages, "The following plots are not in the database as uniquenames or synonyms: ".join(',',@plots_missing);
    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        $errors{'missing_stocks'} = \@accessions_missing;
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
    }

    if (keys %seen_new_plot_names) {
        my @new_plot_names = keys %seen_new_plot_names;
        my $new_plot_name_validator = CXGN::List::Validate->new();
        my @valid_new_plot_names = @{$new_plot_name_validator->validate($schema,'plots',\@new_plot_names)->{'missing'}};
        my @not_valid_names;
        if (scalar(@valid_new_plot_names) != scalar(@new_plot_names)) {
            for (@new_plot_names) {
                if (!exists($valid_new_plot_names[$_])) {
                    push @not_valid_names, $_;
                }  
            }
            $errors{'not_valid_names'} = \@not_valid_names;
            push @error_messages, "The following new plot names already exist in the database.: ".join(',', @not_valid_names);
        }
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
