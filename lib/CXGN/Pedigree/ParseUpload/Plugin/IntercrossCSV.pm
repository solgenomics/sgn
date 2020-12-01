package CXGN::Pedigree::ParseUpload::Plugin::Intercross;

use Moose;
use File::Slurp;
use Text::CSV;

use Moose::Role;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;


sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my %parse_result;
    my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

    ## Check that the file can be read
    my @file_lines = read_file($filename);
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

        #  Check headers
        if ($header_row[0] ne 'crossDbId'){
            $parse_result{'error'} = "File contents incorrect. The first column must be crossDbId.";
            return \%parse_result;
        }

        if ($header_row[1] ne 'femaleObsUnitDbId'){
            $parse_result{'error'} = "File contents incorrect. The second column must be femaleObsUnitDbId.";
            return \%parse_result;
        }

        if ($header_row[2] ne 'maleObsUnitDbId'){
            $parse_result{'error'} = "File contents incorrect. The third column must be maleObsUnitDbId.";
            return \%parse_result;
        }

        if ($header_row[3] ne 'timestamp'){
            $parse_result{'error'} = "File contents incorrect. The fourth must be timestamp.";
            return \%parse_result;
        }

        if ($header_row[4] ne 'person'){
            $parse_result{'error'} = "File contents incorrect. The fifth column must be person.";
            return \%parse_result;
        }

        if ($header_row[5] ne 'experiment'){
            $parse_result{'error'} = "File contents incorrect. The sixth column must be experiment.";
            return \%parse_result;
        }

        if ($header_row[6] ne 'type'){
            $parse_result{'error'} = "File contents incorrect. The seventh column must be type.";
            return \%parse_result;
        }

        if ($header_row[7] ne 'fruits'){
            $parse_result{'error'} = "File contents incorrect. The eighth column must be fruits.";
            return \%parse_result;
        }

        if ($header_row[8] ne 'flowers'){
            $parse_result{'error'} = "File contents incorrect. The ninth column must be flowers.";
            return \%parse_result;
        }

        if ($header_row[8] ne 'seeds'){
            $parse_result{'error'} = "File contents incorrect. The tenth column must be seeds.";
            return \%parse_result;
        }


        if($female_type ne 'accession' && $data_level ne 'plot' && $data_level ne 'plant'){
            $parse_result{'error'} = "You must specify if the femaleObsUnitDbId information is accession, plot or plant level.";
            return \%parse_result;
        }

        if($male_type ne 'accession' && $data_level ne 'plot' && $data_level ne 'plant'){
            $parse_result{'error'} = "You must specify if the maleObsUnitDbId information is accession, plot or plant level.";
            return \%parse_result;
        }






            return 1;
        }
