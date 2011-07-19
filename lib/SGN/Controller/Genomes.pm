package SGN::Controller::Genomes;
use Moose;
use namespace::autoclean;

use List::MoreUtils 'uniq';

BEGIN{ extends 'Catalyst::Controller' }

with 'Catalyst::Component::ApplicationAttribute';

sub view_genome_data : Chained('/organism/find_organism') PathPart('genome') {
    my ( $self, $c ) = @_;

    my $organism = $c->stash->{organism};
    $c->throw_404 unless $organism->search_related('organismprops',
                             { 'type.name' => 'genome_page', 'me.value' => 1 },
                             { join => 'type' },
                         )->count;

    (my $template_name = '/genomes/'.$organism->species.'.mas') =~ s/ /_/g;

    # find assemblies for this organism
    $c->stash->{assembly_list} = [
        map {
            my $bs_sample = $_;
            { name =>  $bs_sample->sample_name,
              date => $bs_sample->metadata ? $bs_sample->metadata->create_date : undef,
              description => $bs_sample->description,
              annotation_sets => [ $self->assembly_annotations( $bs_sample ) ],
              files =>
                [ map +{ text    => $_->basename,
                         url     => '/metadata/file/'.$_->file_id.'/download',
                         tooltip => $_->comment,
                       },
                  $self->assembly_files( $bs_sample )
                ],
            },
        } $self->assemblies_for_organism( $organism )->all
      ];

    $c->stash->{template} =
        $c->view('Mason')->component_exists( $template_name )
            ? $template_name : '/genomes/default.mas';
}

####### helper methods ##########

sub _annotates_cvterms_rs {
    my ( $self, $row ) = @_;
    my $schema = $row ? $row->result_source->schema : $self->_app->dbic_schema('CXGN::Biosource::Schema');

    return $schema->resultset('Cv::Cvterm')
                  ->search_rs({ name => 'annotates' });
}

sub assembly_annotations {
    my ( $self, $sample_row ) = @_;
    return
        $sample_row->search_related('bs_sample_relationship_objects',
                       { 'me.type_id' =>
                             { -in => $self->_annotates_cvterms_rs( $sample_row )
                                           ->get_column('cvterm_id')
                                           ->as_query,
                             },
                       },
                     )
                   ->search_related('subject')
                   ->all
    ;
}

sub assembly_files {
    my ( $self, $sample_row ) = @_;

    return
        $sample_row->search_related('bs_sample_files')
                   ->search_related('file')
                   ->all
    ;
}

sub assemblies_for_organism {
    my ( $self, $organism ) = @_;

    my $schema = $organism->result_source->schema;

    $schema->resultset('BsSample')
           ->search({
               type_id     => { -in => [ uniq map $_->cvterm_id, @{$self->_assembly_cvterms( $schema )}] },
               organism_id => $organism->organism_id,
             });
}

# get the RS of types (i.e. cvterms) that would indicate that we
# should list a certain biosource
# currently defined as 'all SO children '
sub _assembly_cvterms {
    my ( $self, $schema ) = @_;
    my $sc = $schema->resultset('Cv::Cv')
           ->search({ 'me.name' => ['sequence','SO'] })
           ->search_related('cvterms', {
               'cvterms.name' => 'sequence_collection',
             });

    my @terms = $sc->all;
    return [ @terms, map $_->recursive_children, @terms ];
}

1;
