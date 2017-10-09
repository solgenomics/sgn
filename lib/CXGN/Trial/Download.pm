
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
has 'trait_component_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'trial_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'accession_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'plot_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'plant_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'location_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'year_list' => (isa => 'ArrayRef[Int]|Undef', is => 'rw' );
has 'include_timestamp' => (isa => 'Bool', is => 'ro', default => 0);
has 'has_header' => (isa => 'Bool', is => 'ro', default => 1);
has 'trait_contains' => (isa => 'ArrayRef[Str]|Undef', is => 'rw');
has 'phenotype_min_value' => (isa => 'Str', is => 'rw');
has 'phenotype_max_value' => (isa => 'Str', is => 'rw');
has 'search_type' => (isa => 'Str', is => 'rw');
has 'treatment_project_ids' => (isa => 'ArrayRef[Int]|Undef', is => 'rw');
has 'selected_columns' => (isa => 'HashRef|Undef', is => 'rw');
has 'selected_trait_names' => (isa => 'ArrayRef|Undef', is => 'rw');

has 'filename' => (isa => 'Str', is => 'ro',
		   predicate => 'has_filename',
		   required => 1,
		  );

has 'file_metadata' => (isa => 'Str', is => 'rw', predicate => 'has_file_metadata');


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
