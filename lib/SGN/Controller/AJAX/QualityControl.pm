
package SGN::Controller::AJAX::QualityControl;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;
use SGN::Controller::AJAX::Dataset;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );


sub prepare: Path('/ajax/qualitycontrol/prepare') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');

    if (! $c->user()) {
        $c->stash->{rest} = {error=>'You must be logged in first!'};
        $c->detach;
    }

    $c->tempfiles_subdir("qualitycontrol");

    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"qualitycontrol/qc_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;

    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);
    $ds->retrieve_phenotypes();
    my $pf = CXGN::Phenotypes::File->new( { file => $temppath."_phenotype.txt" });

    # my @traits_select = ();
    my $traits = $pf->traits();

    my $trait_options = "trait_options";
    my $trait_html ="";

    foreach my $trait (@$traits) {
       if ($trait =~ m/.+\d{7}/){
        $trait_html .= '<input type="checkbox" class= "trait_box" name="'.$trait_options.'" value="'.$trait.'">'.$trait.'</input> </br>';
       }
    }


    $c->stash->{rest} = {
        selected_variable => $trait_html,
        tempfile => $tempfile."_phenotype.txt",
    };

}

sub extract_trait_data :Path('/ajax/qualitycontrol/grabdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/qualitycontrol/".$file);

    my $F;
    if (! open($F, "<", $temppath)) {
    $c->stash->{rest} = { error => "Can't find data." };
    return;
    }

    my $header = <$F>;
    chomp($header);

    my @keys = split("\t", $header);

    my @data = ();

    while (<$F>) {
        chomp;
        my @fields = split "\t";
        my %line = ();
        
        for (my $n = 0; $n < @keys; $n++) {
            if (exists($fields[$n]) && defined($fields[$n])) {
                $line{$keys[$n]} = $fields[$n];
            }
        }
        if (defined $line{$trait} && $line{$trait} ne '') {
            push @data, \%line;
        }
    }

    $c->stash->{rest} = { data => \@data, trait => $trait};
}

sub store_outliers : Path('/ajax/qualitycontrol/storeoutliers') Args(0) {
    my ($self, $c) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
 
    # Retrieve and decode the outliers from the request
    my $outliers_string = $c->req->param('outliers');

    print STDERR $outliers_string;


    my $outliers_data = decode_json($outliers_string);
    
    # Map to store trait names and their corresponding cvterm_id
    my %trait_ids;  # Declare the hash before use
    foreach my $entry (@$outliers_data) { 
        my $trait = $entry->{trait};  # Directly use the trait from the entry
        $trait_ids{$trait} = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait)->cvterm_id;
    }

    my $experiment_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    # Extract plot names from the outliers data
    my @plot_names = map { $_->{plotName} } @$outliers_data;
    
    # Ensure plot names and traits are not empty
    if (@plot_names && %trait_ids) {
        # Convert plot names and traits into comma-separated lists for SQL
        my $plot_names_sql = join(", ", map { $schema->storage->dbh()->quote($_) } @plot_names);
        my $trait_ids_sql = join(", ", values %trait_ids); # Use trait IDs from the hash

        # Build the SQL query
        my $outlier_data_sql = "
            INSERT INTO phenotypeprop (phenotype_id, type_id, value)
            SELECT phenotype.phenotype_id, 
                   (SELECT cvterm_id FROM cvterm WHERE name = 'phenotype_outlier'), 
                   phenotype.value 
            FROM phenotype
            JOIN nd_experiment_phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id 
            JOIN nd_experiment_stock ON nd_experiment_stock.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id 
            WHERE nd_experiment_stock.stock_id IN (
                SELECT stock.stock_id FROM stock WHERE uniquename IN ($plot_names_sql)
            )
            AND nd_experiment_stock.type_id = $experiment_type
            AND phenotype.observable_id IN ($trait_ids_sql)
            AND NOT EXISTS (
                SELECT 1 FROM phenotypeprop 
                WHERE phenotypeprop.phenotype_id = phenotype.phenotype_id
                AND phenotypeprop.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'phenotype_outlier')
            );";


        # Execute the SQL query
        eval {
            my $h_outliers = $schema->storage->dbh()->prepare($outlier_data_sql);
            $h_outliers->execute();
        };
        if ($@) {
            $c->response->body("Failed to store outliers: $@");
            return;
        }
        
        $c->response->body('Outliers stored successfully');
    } else {
        $c->response->body('No plot names or traits found.');
    }
}


1;
