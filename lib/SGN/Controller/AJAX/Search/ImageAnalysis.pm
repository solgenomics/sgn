
package SGN::Controller::AJAX::Search::ImageAnalysis;

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

sub run_search : Path('/ajax/image_analysis/search_runs') : ActionClass('REST') { }

sub run_search_POST : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado', $sp_person_id);
    my $dbh    = $schema->storage->dbh();
    my $params = $c->req->params() || {};

    my $draw = $params->{draw};
    $draw =~ s/\D//g if $draw;

    my $limit  = $params->{length};
    my $offset = $params->{start};
    $limit  = 10 if !defined $limit || $limit < 0;
    $offset = 0  if !defined $offset;

    # filters
    my $f_run_name = $params->{run_name};
    my $f_image    = $params->{image_filename};
    my $f_stock    = $params->{stock_name};
    my $f_pipeline = $params->{pipeline_name};

    # cvterm ids
    my $design_id            = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $pipeline_name_id     = SGN::Model::Cvterm->get_cvterm_row($schema, 'image_analysis_pipeline_name', 'project_property')->cvterm_id();
    my $source_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'image_analysis_source_image', 'project_md_image')->cvterm_id();
    my $start_date_id        = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();

    my @where  = ("dp.type_id = ? AND dp.value = 'image_analysis_run'");
    my @bind   = ($design_id);

    if ($f_run_name) { push @where, "p.name ILIKE ?";               push @bind, '%'.$f_run_name.'%'; }
    if ($f_pipeline) { push @where, "pp_pipe.value ILIKE ?";        push @bind, '%'.$f_pipeline.'%'; }
    if ($f_image)    { push @where, "mi.original_filename ILIKE ?"; push @bind, '%'.$f_image.'%'; }
    if ($f_stock)    { push @where, "src_stock.uniquename ILIKE ?"; push @bind, '%'.$f_stock.'%'; }

    my $where_sql = join(" AND ", @where);

    my $base_from = qq{
        FROM project p
        JOIN projectprop dp
               ON dp.project_id = p.project_id
        LEFT JOIN projectprop pp_pipe
               ON pp_pipe.project_id = p.project_id AND pp_pipe.type_id = $pipeline_name_id
        LEFT JOIN projectprop pp_date
               ON pp_date.project_id = p.project_id AND pp_date.type_id = $start_date_id
        -- source image linked to this run project
        LEFT JOIN phenome.project_md_image pmi
               ON pmi.project_id = p.project_id AND pmi.type_id = $source_image_type_id
        LEFT JOIN metadata.md_image mi
               ON mi.image_id = pmi.image_id
        -- the stock that the source image is associated with
        LEFT JOIN phenome.stock_image si
               ON si.image_id = pmi.image_id
        LEFT JOIN stock src_stock
               ON src_stock.stock_id = si.stock_id
        WHERE $where_sql
    };

    my $count_sth = $dbh->prepare("SELECT COUNT(DISTINCT p.project_id) $base_from");
    $count_sth->execute(@bind);
    my ($records_total) = $count_sth->fetchrow_array();

    my $data_sql = qq{
        SELECT DISTINCT
            p.project_id,
            p.name                AS run_name,
            mi.original_filename  AS image_filename,
            src_stock.uniquename  AS stock_name,
            src_stock.stock_id    AS stock_id,
            pp_pipe.value         AS pipeline_name,
            pp_date.value         AS run_date
        $base_from
        ORDER BY p.project_id DESC
        LIMIT ? OFFSET ?
    };
    my $data_sth = $dbh->prepare($data_sql);
    $data_sth->execute(@bind, $limit, $offset);

    my @return;
    while (my $row = $data_sth->fetchrow_hashref()) {
        my $run_link = "<a href='/image_analysis/run/".$row->{project_id}."'>"
                     . ($row->{run_name} // '') . "</a>";

        my $stock_link = $row->{stock_id}
            ? "<a href='/stock/".$row->{stock_id}."/view'>".($row->{stock_name} // '')."</a>"
            : ($row->{stock_name} // '');

        push @return, [
            $run_link,
            ($row->{image_filename} // ''),
            $stock_link,
            ($row->{pipeline_name}  // ''),
            ($row->{run_date}       // ''),
        ];
    }

    $c->stash->{rest} = {
        data            => [ @return ],
        draw            => $draw,
        recordsTotal    => $records_total,
        recordsFiltered => $records_total,
    };
}

1;