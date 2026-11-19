package CXGN::BrAPI::v2::Common;

=head1 NAME
 CXGN::BrAPI::v2::Common - parent class for BrAPI subclasses.
=head1 DESCRIPTION
 Defines the following properties:
=over 4
=item bcs_schema
 A Bio::Chado::Schema object
=item metadata_schema
 A CXGN::Metadata::Schema object
=item phenome_schema
 A CXGN::Phenome::Schema object
=item people_schema
 A CXGN::People::Schema
=item page
 The page to be retrieved
=item page_size
 The current page_size
=item status
 Current BrAPI status information
=back
=head1 AUTHORS
 Nicolas Morales <nm529@cornell.edu>
 Lukas Mueller <lam87@cornell.edu>
=cut

 use Moose;
 use File::Temp;
 use DateTime;

 has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
    );

 has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
    );

 has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
    );

 has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
    );
 
 has 'context' => (
   is => 'rw',
   required => 1,
);

 has 'page_size' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
    );

 has 'page' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
    );

 has 'status' => (
    isa => 'ArrayRef[Maybe[HashRef]]',
    is => 'rw',
    required => 1,
    );

# Builds the phenotype_store_config hashref expected by the CXGN::Trial methods that create child
# observation units (save_plant_entries, create_tissue_samples, save_tissue_sample_entries) so that
# they can store the treatments inherited from the parent.
 sub phenotype_store_config {
    my ($self, $c, $user_id, $user_name) = @_;

    my $temp_basedir = $c->config->{tempfiles_subdir};
    my $site_basedir = $c->config->{basepath};
    if (! -d "$site_basedir/$temp_basedir/delete_nd_experiment_ids/") {
        mkdir("$site_basedir/$temp_basedir/delete_nd_experiment_ids/");
    }
    my (undef, $tempfile) = File::Temp::tempfile("$site_basedir/$temp_basedir/delete_nd_experiment_ids/fileXXXX");
    my $time = DateTime->now();

    return {
        basepath => "$site_basedir/$temp_basedir",
        dbhost => $c->config->{dbhost},
        dbname => $c->config->{dbname},
        dbuser => $c->config->{dbuser},
        dbpass => $c->config->{dbpass},
        temp_file_nd_experiment_id => $tempfile,
        user_id => $user_id,
        metadata_hash => {
            archived_file => 'none',
            archived_file_type => 'new stock treatment auto inheritance',
            operator => $user_name,
            date => $time->ymd()."_".$time->hms()
        }
    };
 }

 1;
