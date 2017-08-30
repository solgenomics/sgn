
package CXGN::Phenotypes::ParseUpload::Plugin::FieldBook;

use Moose;
use File::Slurp;

sub name {
    return "field book";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my %parse_result;

    ## Check that the file could be read
    @file_lines = read_file($filename);
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

    $header = shift(@file_lines);
    chomp($header);
    @header_row = split($delimiter, $header);
    if (!$header_row[1]) {
        $parse_result{'error'} = "File has no header row.";
        print STDERR "File has no header row.\n";
        return \%parse_result;
    }

    #  Check header row contents
    if ($header_row[0] ne "\"plot_name\"" || $header_row[0] ne "\"plant_name\"" || $header_row[0] ne "\"subplot_name\""){
        $parse_result{'error'} = "File contents incorrect. First column in header must be plot_name, plant_name, or subplot_name.";
        return \%parse_result;
    }
    my $col_num;
    if($header_row[0] eq "\"plot_name\""){
        $col_num = 2;
        if ($header_row[1] ne "\"block_number\"" ){
            $parse_result{'error'} = "File contents incorrect. If your first column is plot_name, the second column must be block_number.";
            return \%parse_result;
        }
    } elsif ($header_row[0] eq "\"plant_name\""){
        if ($header_row[1] eq "\"plot_name\""){
            $col_num = 4;
            if ($header_row[2] ne "\"block_number\"" || $header_row[3] ne "\"plant_number\""){
                $parse_result{'error'} = "File contents incorrect. If your first column is plant_name and your second column is plot_name, then the third and fourth columns must be block_number and plant_number.";
                return \%parse_result;
            }
        } elsif ($header_row[1] eq "\"subplot_name\""){
            if ($header_row[2] ne "\"plot_name\"" || $header_row[3] ne "\"block_number\"" || $header_row[4] ne "\"subplot_number\"" || $header_row[5] ne "\"plant_number\""){
                $parse_result{'error'} = "File contents incorrect. If your first column is plant_name and your second column is subplot_name, then the third, fourth, fifth, and sixth columns must be plot_name, block_number, subplot_number, and plant_number.";
                return \%parse_result;
            }
            $col_num = 6;
        }
    } elsif ($header_row[0] eq "\"subplot_name\""){
        if ($header_row[1] ne "\"plot_name\"" || $header_row[2] ne "\"block_number\"" || $header_row[3] ne "\"subplot_number\""){
            $parse_result{'error'} = "File contents incorrect. If your first column is subplot_name, then the second, third, and fourth columns must be plot_name, block_number, and subplot_number.";
            return \%parse_result;
        }
        $col_num = 4;
    }

    if ($header_row[$col_num] ne "\"plot_number\"" || $header_row[$col_num+1] ne "\"rep_number\"" || $header_row[$col_num+2] ne "\"row_number\"" || $header_row[$col_num+3] ne "\"col_number\"" || $header_row[$col_num+4] ne "\"accession\"" || $header_row[$col_num+5] ne "\"is_a_control\""){
        $parse_result{'error'} = "File contents incorrect. Column @{[$col_num]} in header must be plot_number. Column @{[$col_num + 1]} in header must be rep_number. Column @{[$col_num + 2]} in header must be row_number. Column @{[$col_num + 3]} in header must be col_number. Column @{[$col_num + 4]} in header must be accession. Column @{[$col_num + 5]} in header must be is_a_control.";
        return \%parse_result;
    }
    if (!$header_row[$col_num+6]){
        $parse_result{'error'} = "File contents incorrect. Column @{[$col_num + 6]} must be either trait or a treatment";
        return \%parse_result;
    }
    my $has_treatment;
    if ($header_row[$col_num+6] ne "\"trait\""){
        $has_treatment = 1;
    }
    if($has_treatment){
        if($header_row[$col_num+7] ne "\"trait\"" || $header_row[$col_num+8] ne "\"value\"" || $header_row[$col_num+9] ne "\"timestamp\"" || $header_row[$col_num+10] ne "\"person\"" || $header_row[$col_num+11] ne "\"location\"" || $header_row[$col_num+12] ne "\"number\""){
            $parse_result{'error'} = "File contents incorrect. It seems you are uploading a treatment. Column @{[$col_num + 7]} must be trait. Column @{[$col_num + 8]} must be value. Column @{[$col_num + 9]} must be timestamp. Column @{[$col_num + 10]} must be person. Column @{[$col_num + 11]} must be location. Column @{[$col_num + 12]} must be number.";
            return \%parse_result;
        }
    } else {
        if($header_row[$col_num+6] ne "\"trait\"" || $header_row[$col_num+7] ne "\"value\"" || $header_row[$col_num+8] ne "\"timestamp\"" || $header_row[$col_num+9] ne "\"person\"" || $header_row[$col_num+10] ne "\"location\"" || $header_row[$col_num+11] ne "\"number\""){
            $parse_result{'error'} = "File contents incorrect. Column @{[$col_num + 6]} must be trait. Column @{[$col_num + 7]} must be value. Column @{[$col_num + 8]} must be timestamp. Column @{[$col_num + 9]} must be person. Column @{[$col_num + 10]} must be location. Column @{[$col_num + 11]} must be number.";
            return \%parse_result;
        }
    }

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my %parse_result;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %plots_seen;
    my %traits_seen;
    my @plots;
    my @traits;
    my %data;

    @file_lines = read_file($filename);
    $header = shift(@file_lines);
    chomp($header);
    @header_row = split($delimiter, $header);

    ## Get column numbers (indexed from 1) of the plot_id, trait, and value.
    foreach my $header_cell (@header_row) {
        $header_cell =~ s/\"//g; #substr($header_cell,1,-1);  #remove double quotes

        if ($header_cell eq "trait") {
            $header_column_info{'trait'} = $header_column_number;
        }
        if ($header_cell eq "value") {
            $header_column_info{'value'} = $header_column_number;
        }
        if ($header_cell eq "timestamp") {
            $header_column_info{'timestamp'} = $header_column_number;
        }
        $header_column_number++;
    }
    if (!defined($header_column_info{'trait'}) || !defined($header_column_info{'value'})) {
        $parse_result{'error'} = "trait or value column not found. Make sure to use the database Fieldbook format.";
        print STDERR "trait or value column not found. Make sure to use the database Fieldbook format.";
        return \%parse_result;
    }

    my $treatment_col;
    if($header_row[0] eq "\"plot_name\""){
        $treatment_col = 9;
    } elsif ($header_row[0] eq "\"plant_name\""){
        if ($header_row[1] eq "\"plot_name\""){
            $treatment_col = 7;
        } elsif ($header_row[1] eq "\"subplot_name\""){
            $treatment_col = 9;
        }
    } elsif ($header_row[0] eq "\"subplot_name\""){
        $treatment_col = 7;
    }

    my $treatment_col;
    if($header_row[2] eq "plot"){
        $treatment_col = 6;
    }
    if($header_row[2] eq "plant"){
        $treatment_col = 7;
    }
    if($header_row[$treatment_col] ne "trait"){
        $header_column_info{'treatment'} = [$treatment_col, $header_row[$treatment_col]];
    }

    foreach my $line (sort @file_lines) {
        chomp($line);
        my @row =  split($delimiter, $line);
        my $plot_id = $row[0];
        $plot_id =~ s/\"//g;
        #substr($row[$header_column_info{'plot_id'}],1,-1);
        my $trait = $row[$header_column_info{'trait'}];
        $trait =~ s/\"//g;
        #substr($row[$header_column_info{'trait'}],1,-1);
        my $value = $row[$header_column_info{'value'}];
        $value =~ s/\"//g;
        #substr($row[$header_column_info{'value'}],1,-1);
        my $timestamp = $row[$header_column_info{'timestamp'}];
        $timestamp =~ s/\"//g;

        my @treatments;
        if(exists($header_column_info{'treatment'})){
            my $treatment_val = $row[$header_column_info{'treatment'}->[0]];
            $treatment_val =~ s/\"//g;
            if($treatment_val eq "1"){
                push @treatments, $header_column_info{'treatment'}->[1];
            }
        }

        if (!defined($plot_id) || !defined($trait) || !defined($value) || !defined($timestamp)) {
            $parse_result{'error'} = "Error getting value from file";
            print STDERR "value: $value\n";
            return \%parse_result;
        }
        if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
            $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
            print STDERR "value: $timestamp\n";
            return \%parse_result;
        }
        $plots_seen{$plot_id} = 1;
        $traits_seen{$trait} = 1;
        if (defined($value) && defined($timestamp)) {
            $data{$plot_id}->{$trait} = [$value, $timestamp, \@treatments];
        }
    }

    foreach my $plot (sort keys %plots_seen) {
        push @plots, $plot;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    return \%parse_result;
}

1;
