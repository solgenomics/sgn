package SGN::Controller::Genomes;
use Moose;
use namespace::autoclean;

use List::MoreUtils 'uniq';

BEGIN{ extends 'Catalyst::Controller' }

sub view_genome_data : Chained('/organism/find_organism') PathPart('genome') {
    my ( $self, $c ) = @_;

    my $organism = $c->stash->{organism};

    (my $template_name = '/genomes/'.$organism->species.'.mas') =~ s/ /_/g;

    # find assemblies for this organism
    $c->stash->{assembly_list} = [
        map {
            my $bs_sample = $_;
            [
                $bs_sample->name,
                $bs_sample->metadata->create_date,
                $bs_sample->description || '-',
                '-',
                '-',
            ],
        } $self->assemblies_for_organism( $organism )->all
      ];

    $c->stash->{template} =
        $c->view('Mason')->component_exists( $template_name )
            ? $template_name : '/genomes/default.mas';
}

####### helper methods ##########

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
