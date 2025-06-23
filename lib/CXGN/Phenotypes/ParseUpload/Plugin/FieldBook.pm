
package CXGN::Phenotypes::ParseUpload::Plugin::FieldBook;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '2015-06-16T00:53:26Z', 'person1', '']
#           varname2 => [120, '', 'person2', '']
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
use File::Slurp;
use Text::CSV;
use Data::Dumper;

sub name {
    return "field book";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;
    my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    ## Check that the file can be read
    my @file_lines = read_file($filename);

    # fix DOS-style line-endings!!!
    #
    foreach my $fl (@file_lines) {
	$fl =~ s/\r//g;
    }
    
    if (!@file_lines) {
        $parse_result{'error'} = "Could not read file.";
        print STDERR "Could not read file.\n";
        return \%parse_result;
    }
    ## Check that the file has at least 2 lines;
    if (scalar(@file_lines < 2)) {
        $parse_result{'error'} = "File has less than 2 lines.";
        print STDERR "File has less than 2 lines.\n";
        return \%parse_result;
    }

    my $header = shift(@file_lines);
    my $status  = $csv->parse($header);
    my @header_row = $csv->fields();

    if (!$header_row[1]) {
        $parse_result{'error'} = "File has no header row.";
        print STDERR "File has no header row.\n";
        return \%parse_result;
    }

    #  Check header row contents
    if ($header_row[0] ne 'plot_id' && $header_row[0] ne 'plot_name' && $header_row[0] ne 'plant_name' && $header_row[0] ne 'subplot_name'){
        $parse_result{'error'} = "File contents incorrect. First column in header is $header_row[0], but it must be plot_id, plot_name, plant_name, or subplot_name.";
        return \%parse_result;
    }

    if($data_level ne 'plots' && $data_level ne 'plants' && $data_level ne 'subplots'){
        $parse_result{'error'} = "You must specify if you are uploading plot, plant, or subplot level phenotypes.";
        return \%parse_result;
    }
    if($data_level eq 'plots' && ($header_row[0] ne "plot_id" && $header_row[0] ne "plot_name")){
        $parse_result{'error'} = "File contents incorrect. First column in header is $header_row[0] but must be plot_id or plot_name if you are uploading plot level phenotypes.";
        return \%parse_result;
    } elsif ($data_level eq 'plants' && $header_row[0] ne "plant_name"){
        $parse_result{'error'} = "File contents incorrect. First column in header is $header_row[0] but must be plot_id or plot_name if you are uploading plant level phenotypes.";
        return \%parse_result;
    } elsif ($data_level eq 'subplots' && $header_row[0] ne "subplot_name"){
        $parse_result{'error'} = "File contents incorrect. First column in header is $header_row[0] but must be plot_id or plot_name if you are uploading subplot level phenotypes.";
        return \%parse_result;
    }

    my %header_column_info;
    foreach my $header_cell (@header_row) {
        # $header_cell =~ s/\"//g; #substr($header_cell,1,-1);  #remove double quotes

        if ($header_cell eq "trait") {
            $header_column_info{'trait'}++;
        }
        if ($header_cell eq "value") {
            $header_column_info{'value'}++;
        }
    }
    if (!defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
        $parse_result{'error'} = "trait or value column not found. Make sure to use the database Fieldbook format.";
        print STDERR "trait or value column not found. Make sure to use the database Fieldbook format.";
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
    my $zipfile = shift; #not relevant for this plugin
    my $user_id = shift; #not relevant for this plugin
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;
    my @file_lines;
    my $header;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %plots_seen;
    my %traits_seen;
    my @plots;
    my @traits;
    my %data;

    my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    @file_lines = read_file($filename);

    # fix DOS-style line-endings!!!
    #
    foreach my $fl (@file_lines) {
	$fl =~ s/\r//g;
    }

    $header = shift(@file_lines);
    my $status  = $csv->parse($header);
    my @header_row = $csv->fields();

    ## Get column numbers (indexed from 1) of the plot_id, trait, and value.
    foreach my $header_cell (@header_row) {

        if ($header_cell eq "trait") {
            $header_column_info{'trait'} = $header_column_number;
        }
        if ($header_cell eq "value") {
            $header_column_info{'value'} = $header_column_number;
        }
        if ($header_cell eq "timestamp") {
            $header_column_info{'timestamp'} = $header_column_number;
        }
        if ($header_cell eq "person") {
            $header_column_info{'person'} = $header_column_number;
        }
        $header_column_number++;
    }
    if (!defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
        $parse_result{'error'} = "trait or value column not found. Make sure to use the database Fieldbook format.";
        print STDERR "trait or value column not found. Make sure to use the database Fieldbook format.";
        return \%parse_result;
    }


    for my $index (0..$#file_lines) {
        my $line = $file_lines[$index];
        my $line_number = $index + 2;
        my $status  = $csv->parse($line);
        my @row = $csv->fields();
        my $plot_id = $row[0];

        my $trait = $row[$header_column_info{'trait'}];

        my $value = $row[$header_column_info{'value'}];

        my $timestamp = $row[$header_column_info{'timestamp'}];

        my $collector = $row[$header_column_info{'person'}];

        if (!defined($plot_id) || !defined($trait) || !defined($value) || !defined($timestamp)) {
            $parse_result{'error'} = "Error parsing line $line_number: plot_name, trait, value, or timestamp is undefined.";
            print STDERR "line $line_number has value: $value\n";
            return \%parse_result;
        }
        if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
            $parse_result{'error'} = "Error parsing line $line_number: timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
            print STDERR "line $line_number has timestamp: $timestamp\n";
            return \%parse_result;
        }
        $plots_seen{$plot_id} = 1;
        $traits_seen{$trait} = 1;
        if (defined($value) && defined($timestamp)) {
	    print STDERR "KEEPING $trait with value $value for plot $plot_id...\n";
            push @{$data{$plot_id}->{$trait}}, [$value, $timestamp, $collector, ''];
        }
	else {
	    print STDERR "PROBLEM WITH value $value or TIMESTAMP $timestamp\n";
	}
    }

    foreach my $plot (sort keys %plots_seen) {
        push @plots, $plot;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@plots;
    $parse_result{'variables'} = \@traits;

    return \%parse_result;
}

1;
