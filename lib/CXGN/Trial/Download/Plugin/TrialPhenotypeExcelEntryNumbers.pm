
package CXGN::Trial::Download::Plugin::TrialPhenotypeExcelEntryNumbers;

use CXGN::Trial;

=head1 NAME

CXGN::Trial::Download::Plugin::TrialPhenotypeExcelEntryNumbers

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

This plugin extends the base TrialPhenotypeExcel plugin to include 
an additional column for trial-level accession entry numbers.

As a CSV:
my $plugin = 'TrialPhenotypeCSVEntryNumbers';

As a xls:
my $plugin = 'TrialPhenotypeExcelEntryNumbers';

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trait_list => \@trait_list_int,
    year_list => \@year_list,
    location_list => \@location_list_int,
    trial_list => \@trial_list_int,
    accession_list => \@accession_list_int,
    plot_list => \@plot_list_int,
    plant_list => \@plant_list_int,
    filename => $tempfile,
    format => $plugin,
    data_level => $data_level,
    include_timestamp => $timestamp_option,
    exclude_phenotype_outlier => $exclude_phenotype_outlier,
    trait_contains => \@trait_contains_list,
    phenotype_min_value => $phenotype_min_value,
    phenotype_max_value => $phenotype_max_value,
    has_header=>$has_header
});
my $error = $download->download();
my $file_name = "phenotype.$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);


=head1 AUTHORS

=cut

use Moose::Role;

use Spreadsheet::WriteExcel;
use CXGN::Trial;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Phenotypes::MetaDataMatrix;
use Data::Dumper;

sub verify {
    1;
}

sub download {
    my $self = shift;

    #
    # COLUMN INDICES
    #
    my $TRIAL_ID_COLUMN = 4;        # column to retrieve the trial id
    my $STOCK_ID_COLUMN = 17;       # column to retrieve the stock id
    my $ENTRY_NUMBER_COLUMN = 20;   # column to insert the entry number

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my $trait_list = $self->trait_list();
    my $trait_contains = $self->trait_contains();
    my $data_level = $self->data_level();
    my $include_timestamp = $self->include_timestamp();
    my $trial_list = $self->trial_list();
    if (!$trial_list) {
        push @$trial_list, $trial_id;
    }
    my $accession_list = $self->accession_list;
    my $plot_list = $self->plot_list;
    my $plant_list = $self->plant_list;
    my $location_list = $self->location_list;
    my $year_list = $self->year_list;
    my $phenotype_min_value = $self->phenotype_min_value();
    my $phenotype_max_value = $self->phenotype_max_value();
    my $exclude_phenotype_outlier = $self->exclude_phenotype_outlier;
    my $search_type = $self->search_type();
    $self->trial_download_log($trial_id, "trial phenotypes");

    my @data;
    if ($self->data_level() eq 'metadata'){
        my $metadata_search = CXGN::Phenotypes::MetaDataMatrix->new(
            bcs_schema=>$schema,
            search_type=>'MetaData',
            data_level=>$data_level,
            trial_list=>$trial_list,
        );
        @data = $metadata_search->get_metadata_matrix();
    }
    else {
        my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
            bcs_schema=>$schema,
            search_type=>$search_type,
            data_level=>$data_level,
            trait_list=>$trait_list,
            trial_list=>$trial_list,
            year_list=>$year_list,
            location_list=>$location_list,
            accession_list=>$accession_list,
            plot_list=>$plot_list,
            plant_list=>$plant_list,
            include_timestamp=>$include_timestamp,
            exclude_phenotype_outlier=>$exclude_phenotype_outlier,
            trait_contains=>$trait_contains,
            phenotype_min_value=>$phenotype_min_value,
            phenotype_max_value=>$phenotype_max_value,
        );
        @data = $phenotypes_search->get_phenotype_matrix();
    }
    #print STDERR Dumper \@data;

    print STDERR "Print Excel Start:".localtime."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my $header_offset = 0;
    if ($self->has_header){
        $header_offset = 3;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        $ws->write(0, 0, "Date of Download:");
        $ws->write(0, 1, $timestamp);
        $ws->write(1, 0, "Search Parameters:");
        my $trait_list_text = $trait_list ? join ("," , @$trait_list) : '';
        my $trial_list_text = $trial_list ? join ("," , @$trial_list) : '';
        my $accession_list_text = $accession_list ? join(",", @$accession_list) : '';
        my $plot_list_text = $plot_list ? join(",", @$plot_list) : '';
        my $plant_list_text = $plant_list ? join(",", @$plant_list) : '';
        my $trait_contains_text = $trait_contains ? join(",", @$trait_contains) : '';
        my $min_value_text = $phenotype_min_value ? $phenotype_min_value : '';
        my $max_value_text = $phenotype_max_value ? $phenotype_max_value : '';
        my $location_list_text = $location_list ? join(",", @$location_list) : '';
        my $year_list_text = $year_list ? join(",", @$year_list) : '';
        if ($data_level eq 'metadata'){ $ws->write(1, 1, "metadata"); }
        else {
            $ws->write(1, 1, "Data Level:$data_level  Trait List:$trait_list_text  Trial List:$trial_list_text  Accession List:$accession_list_text  Plot List:$plot_list_text  Plant List:$plant_list_text  Location List:$location_list_text  Year List:$year_list_text  Include Timestamp:$include_timestamp  Trait Contains:$trait_contains_text  Minimum Phenotype: $min_value_text  Maximum Phenotype: $max_value_text Exclude Phenotype Outliers: $exclude_phenotype_outlier");
        }
    }

    #
    # GET ENTRY NUMBERS FOR EACH TRIAL
    #
    my %trial_entry_numbers;
    foreach my $trial_id (@$trial_list) {
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
        $trial_entry_numbers{$trial_id} = $trial->get_entry_numbers();
    }


    #
    # WRITE EACH ROW, WITH INSERTED ENTRY NUMBERS
    #
    for (my $line=0; $line< scalar(@data); $line++) {
        my $columns = $data[$line];
        if ( $line == 0 ) {
            splice(@$columns, $ENTRY_NUMBER_COLUMN, 0, 'germplasmEntryNumber');
        }
        else {
            my $trial_id = $columns->[$TRIAL_ID_COLUMN];
            my $stock_id = $columns->[$STOCK_ID_COLUMN];
            my $entry_number = $trial_entry_numbers{$trial_id}{$stock_id};
            splice(@$columns, $ENTRY_NUMBER_COLUMN, 0, $entry_number);
        }
        $ws->write_row($line+$header_offset, 0, $columns);
    }
    $ss ->close();
    print STDERR "Print Excel End:".localtime."\n";
}

1;
