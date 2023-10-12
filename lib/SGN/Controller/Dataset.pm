
package SGN::Controller::Dataset;

use Moose;
use CXGN::Dataset;
use strict;
use warnings;

BEGIN { extends 'Catalyst::Controller'; }

sub dataset :Chained('/') Path('dataset') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $html = "";
    
    my $dataset = CXGN::Dataset->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_dataset_id => $dataset_id
    });
    my $info = $dataset->get_dataset_data();

    my $dataset_info = {
        id => $dataset_id,
	name => $dataset->name(),
	description => $dataset->description,
	info => $info
    };

    my $lt = CXGN::List::Transform->new();
    my %transform_dict = (
        'plots' => 'stock_ids_2_stocks',
        'accessions' => 'stock_ids_2_stocks',
        'traits' => 'trait_ids_2_trait_names',
        'locations' => 'locations_ids_2_location',
        'plants' => 'stock_ids_2_stocks',
        'trials' => 'project_ids_2_projects',
        'trial_types' => 'cvterm_ids_2_cvterms',
        'breeding_programs' => 'project_ids_2_projects',
        'genotyping_protocols' => 'nd_protocol_ids_2_protocols'
    );
    $html .= '<table class="table-bordered"><thead><tr>' . "\n";
    foreach my $cat (@{$dataset_info->{info}->{category_order}}) {
        $html .= '<th>' . $cat . '</th>';
    }
    $html .= '</tr></thead><tbody><tr>' . "\n";
    foreach my $cat (@{$dataset_info->{info}->{category_order}}) {
	my $ids = $dataset_info->{info}->{categories}->{$cat};
	my @items;
	if (exists($transform_dict{$cat})) {
                my $transform = $lt->transform($schema, $transform_dict{$cat}, $ids);
                @items = @{$transform->{transform}};
        } else {
                if (defined($ids)) {
                    @items = @$ids;
		}
        }
	$html .= "<td><div class='well well-sm'>";
        $html .= "<select class='form-control' multiple>";
        foreach (@items) {
             $html .= "<option value='$_' disabled>$_</option>";
        }
        $html .= "</select>";
        $html .= "</td></div>\n";
    }
    $html .= "</table>";

    $c->stash->{dataset_name} = $dataset->name();
    $c->stash->{dataset_id} = $dataset_id;
    $c->stash->{dataset_description} = $dataset->description;
    $c->stash->{dataset_contents} = $html;
    print STDERR "dataset name $dataset->name()\n";
    $c->stash->{template} = '/dataset/index.mas';
    
}

1;
