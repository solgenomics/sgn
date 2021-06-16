
package SGN::Controller::AJAX::Search::Image;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON;
use CXGN::Image::Search;
use SGN::Image;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub image_search :Path('/ajax/search/images') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "Image search AJAX\n";
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $params = $c->req->params() || {};
    #print STDERR Dumper $params;

    my @descriptors;
    if (exists($params->{image_description_filename_composite}) && $params->{image_description_filename_composite}) {
        push @descriptors, $params->{image_description_filename_composite};
    }

    my @tags;
    if (exists($params->{image_tag}) && $params->{image_tag}) {
        push @tags, $params->{image_tag};
    }

    my @stock_name_list;
    if (exists($params->{image_stock_uniquename}) && $params->{image_stock_uniquename}) {
        push @stock_name_list, $params->{image_stock_uniquename};
    }

    my @project_name_list;
    if (exists($params->{image_project_name}) && $params->{image_project_name}) {
        push @project_name_list, $params->{image_project_name};
    }

    my @first_names;
    my @last_names;
    if (exists($params->{image_person} ) && $params->{image_person} ) {
        my @split = split ',' , $params->{image_person};
        my $first_name = $split[0];
        my $last_name = $split[1];
        $first_name =~ s/\s+//g;
        $last_name =~ s/\s+//g;
        if ($first_name) {
            push @first_names, $first_name;
        }
        if ($last_name) {
            push @last_names, $last_name;
        }
    }

    my $limit = $params->{length};
    my $offset = $params->{start};

    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        submitter_first_name_list=>\@first_names,
        submitter_last_name_list=>\@last_names,
        image_name_list=>\@descriptors,
        original_filename_list=>\@descriptors,
        description_list=>\@descriptors,
        stock_name_list=>\@stock_name_list,
        project_name_list=>\@project_name_list,
        tag_list=>\@tags,
        limit=>$limit,
        offset=>$offset
    });
    my ($result, $records_total) = $image_search->search();

    my $draw = $params->{draw};
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    #print STDERR Dumper $result;
    my @return;
    foreach (@$result){
        my $image = SGN::Image->new($schema->storage->dbh, $_->{image_id}, $c);
        my $associations = $_->{stock_id} ? "Stock (".$_->{stock_type_name}."): <a href='/stock/".$_->{stock_id}."/view' >".$_->{stock_uniquename}."</a>" : "";
        my $observations = $_->{observations_array} ? join("\n", map { $_->{observationvariable_name} . " : " . $_->{value} } @{$_->{observations_array}}) : "";
        if ($_->{project_name}) {
            $associations = $_->{stock_id} ? $associations."<br/>Project (".$_->{project_image_type_name}."): <a href='/breeders/trial/".$_->{project_id}."' >".$_->{project_name}."</a>" : "Project (".$_->{project_image_type_name}."): <a href='/breeders/trial/".$_->{project_id}."' >".$_->{project_name}."</a>";
        }
        my @tags;
        foreach my $t (@{$_->{tags_array}}) {
            push @tags, $t->{name};
        }
        my $image_id = $image->get_image_id;
        my $image_name = $image->get_name() || '';
        my $image_description = $image->get_description() || '';
        my $image_img = $image->get_image_url("medium");
        my $original_img = $image->get_image_url("large");
        my $small_image = $image->get_image_url("tiny");
        my $image_page = "/image/view/$image_id";
        my $colorbox = qq|<a href="$image_img"  title="<a href=$image_page>Go to image page ($image_name)</a>" class="image_search_group" rel="gallery-figures"><img src="$small_image" width="40" height="30" border="0" alt="$image_description" /></a>|;

        my @line;
        if ($params->{html_select_box}) {
            push @line, "<input type='checkbox' name='".$params->{html_select_box}."' value='".$_->{image_id}."'>";
        }
        push @line, (
            $colorbox,
            "<a href='/image/view/".$_->{image_id}."' >".$_->{image_original_filename}."</a>",
            $_->{image_description},
            "<a href='/solpeople/personal-info.pl?sp_person_id=".$_->{image_sp_person_id}."' >".$_->{image_username}."</a>",
            $associations,
            $observations,
            (join ', ', @tags)
        );

        push @return, \@line;
    }

    #print STDERR Dumper \@return;
    $c->stash->{rest} = { data => [ @return ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}

1;
