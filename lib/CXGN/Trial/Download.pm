
=head1 NAME

CXGN::Trial::Download

=head1 SYNOPSIS

This module loads one of the plugins in /CXGN/Trial/Download/Plugin/
This module is used differently depending on the plugin.
Example usage for all plugins is listed here.

------------------------------------------------------------------

For downloading trial(s) xls spreadsheet for collecting phenotypes (as used
from SGN::Controller::AJAX::PhenotypesDownload->create_phenotype_spreadsheet):

my $rel_file = $c->tempfile( TEMPLATE => 'download/downloadXXXXX');
my $tempfile = $c->config->{basepath}."/".$rel_file.".xls";
my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_list => \@trial_id_list,
    trait_list => \@trait_list,
    filename => $tempfile,
    format => "ExcelBasic",
    data_level => $data_level,
    sample_number => $sample_number,
    predefined_columns => $predefined_columns,
});
$create_spreadsheet->download();
$c->stash->{rest} = { filename => $urlencode{$rel_file.".xls"} };

------------------------------------------------------------------

For downloading phenotypes in a matrix where columns contain the phenotypes
and rows contain the observation unit (as used from
SGN::Controller::BreedersToolbox::Download->download_phenotypes_action which
is used from the wizard, trial detail page, and manage trials page for
downlading phenotypes):

There a number of optional keys for filtering down the phenotypes
(trait_list, year_list, location_list, etc). Keys can be entirely ignored
if you don't need to filter by them.

As a CSV:
my $plugin = 'TrialPhenotypeCSV';

As a xls:
my $plugin = 'TrialPhenotypeExcel';

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
    has_header=>$has_header,
    include_pedigree_parents=>$include_pedigree_parents
}); 
my $error = $download->download();
my $file_name = "phenotype.$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);

--------------------------------------------------------------------------

For downloading a "DataCollector Spreadsheet" for collecting phenotypes (as
used in SGN::Controller::AJAX::DataCollectorDownload->create_DataCollector_spreadsheet_POST):

my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    trait_list => \@trait_list,
    filename => $file_path,
    format => 'DataCollectorExcel',
    data_level => $data_level,
});
my $spreadsheet_response = $create_spreadsheet->download();
if ($spreadsheet_response->{error}) {
    $c->stash->{rest} = { error => $spreadsheet_response->{error} };
    return;
}
my $file_name = basename($file_path);
$c->stash->{rest} = { filename => $urlencode{$tempfile.".xls"} };

-------------------------------------------------------------------------------

For downloading a trial's layout (as used from CXGN::Trial::Download->trial_download):

A trial's layout can optionally include treatment and phenotype summary
information, mapping to treatment_project_ids and trait_list.
These keys can be ignored if you don't need them in the layout.

As a XLS:

my $plugin = "TrialLayoutExcel";

As a CSV:

my $plugin = "TrialLayoutCSV";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    trait_list => \@trait_list,
    filename => $tempfile,
    format => $plugin,
    data_level => $data_level,
    treatment_project_ids => \@treatment_project_ids,
    selected_columns => $selected_cols,
});
my $error = $download->download();
my $file_name = $trial_id . "_" . "$what" . ".$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);
------------------------------------------------------------------------------

For downloading the IGD sequencing facility spreadsheet (as used from
SGN::Controller::BreedersToolbox::Download->download_sequencing_facility_spreadsheet):

my $td = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $trial_id,
    format => "IGDFacilitySpreadsheet",
    filename => $file_path,
    user_id => $c->user->get_object()->get_sp_person_id(),
    trial_download_logfile => $c->config->{trial_download_logfile},
});
$td->download();
my $file_name = basename($file_path);
$c->res->content_type('Application/xls');
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($file_path, binmode=>':raw');
$c->res->body($output);


-------------------------------------------------------------------------------


=head1 AUTHORS

Nick Morales

=cut

package CXGN::Trial::Download;

use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use Spreadsheet::WriteExcel;
use CXGN::Trait;
use CXGN::List::Transform;
use CXGN::People::Person;
use DateTime;

with 'MooseX::Object::Pluggable';


has 'bcs_schema' => (
    isa => "Bio::Chado::Schema",
    is => 'ro',
    required => 1,
    );

has 'trial_id'   => (
    isa => "Int",
    is => 'ro',
    );

# can be provided for logging purposes
has 'user_id' => (
    is => 'ro',
    isa => 'Int',
    );

has 'trial_download_logfile' => (
    is => 'ro',
    isa => 'Str',
    );

## defines the plugin with which the download will be processed
has 'format' => (isa => 'Str', is => 'ro', required => 1);
has 'data_level' => (isa => 'Str | Undef', is => 'ro', default => 'plots');
has 'sample_number' => (isa => 'Int | Undef', is => 'ro', default => 0);
has 'predefined_columns' => (isa => 'ArrayRef[HashRef] | Undef', is => 'ro');
has 'trait_list' => (isa => 'ArrayRef[Int|Str]|Undef', is => 'rw', predicate => 'has_trait_list' );
has 'include_measured'=> (is => 'rw', isa => 'Str', default => 'false');
has 'trait_component_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'trial_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'accession_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'plot_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'plant_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'location_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'year_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'include_timestamp' => (isa => 'Bool', is => 'ro', default => 0);
has 'include_pedigree_parents' => (isa => 'Bool', is => 'ro', default => 0);
has 'exclude_phenotype_outlier' => (isa => 'Bool', is => 'ro', default => 0);
has 'has_header' => (isa => 'Bool', is => 'ro', default => 1);
has 'trait_contains' => (isa => 'ArrayRef[Str]|Undef', is => 'rw');
has 'phenotype_min_value' => (isa => 'Str', is => 'rw');
has 'phenotype_max_value' => (isa => 'Str', is => 'rw');
has 'search_type' => (isa => 'Str', is => 'rw');
has 'treatment_project_ids' => (isa => 'ArrayRef[Int]|Undef', is => 'rw');
has 'selected_columns' => (isa => 'HashRef|Undef', is => 'rw');
has 'include_notes' => (isa => 'Str', is => 'rw');
has 'filename' => (isa => 'Str', is => 'ro',
		   predicate => 'has_filename',
		   required => 1,
		  );
has 'repetitive_measurements' => (isa => 'Str', is => 'rw' );
has 'file_metadata' => (isa => 'Str', is => 'rw', predicate => 'has_file_metadata');
has 'trial_stock_type' => (isa => 'Str', is => 'rw', predicate => 'has_trial_stock_type', required => 0);
has 'field_crossing_data_order' => (isa => 'ArrayRef[Str]|Undef', is => 'rw', required => 0);
has 'prop_id' => (isa => 'Int | Undef', is => 'rw', required => 0);
has 'people_schema' => ( isa => 'Ref', is => 'rw');
has 'dbh' => (is  => 'rw');
has 'start_date' => ( isa => 'Maybe[Str]', is => 'rw');
has 'end_date' => (isa => 'Maybe[Str]', is => 'rw');


sub BUILD {
    my $self = shift;
    $self->load_plugin($self->format());
}

# sub verify {
#     my $self = shift;

#     $self->load_plugin($self->format());

#     return $self->plugin_verify();
# }

# sub download {
#     my $self = shift;

#     print STDERR "Format: ".$self->format()."\n";
#     eval {
# 	$self->load_plugin($self->format());
#     };
#     if ($@) {
# 	die "The plugin specified (".$self->format().") for the download does not exist";
#     }

#     my $error = $self->plugin_download();

#     return $error;
# }

sub trial_download_log {
    my $self = shift;
    my $trial_id = shift;
    my $message = shift;

    if (! $self->user_id && !$self->trial_download_logfile()) {
	return;
    }
    else {
	print STDERR "Note: set config variable trial_download_logfile to obtain a log of downloaded trials.\n";
    }

    my $now = DateTime->now();

    open (my $F, ">>", $self->trial_download_logfile()) || die "Can't open ".$self->trial_download_logfile();
    my $username = CXGN::People::Person->new($self->bcs_schema->storage->dbh(), $self->user_id())->get_username();
    print $F join("\t", (
		      $username,
		      $trial_id,
		      $message,
		      $now->year()."-".$now->month()."-".$now->day()." ".$now->hour().":".$now->minute()));
    print $F "\n";

    close($F);


}


1;
