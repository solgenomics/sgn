package SGN::Controller::Genomes;

=head1 NAME

SGN::Controller::Genomes - controller for genome portal pages

=cut

use Moose;
use namespace::autoclean;

use List::MoreUtils 'uniq';

BEGIN{ extends 'Catalyst::Controller' }

with 'Catalyst::Component::ApplicationAttribute';

=head1 PUBLIC ACTIONS

=head1 list_genomes

Public path: /genomes

=cut

sub list_genomes : Path( '/genomes' ) Args(0) {
    my ( $self, $c ) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado', $sp_person_id );

    $c->stash(

        genome_organisms => [
            $schema->resultset('Organism::Organismprop')
              ->search({ 'type.name' => 'genome_page' }, { join => 'type' })
              ->search_related('organism')
              ->all
        ],

        template         => '/genomes/index.mas',
    );
}

=head2 view_genome_data

Public path: /organism/<organism id or name>/genome

Queries for Biosource bs_sample records of type 'sequence_collection'
or 'genome_annotation_set', and displays them with file download
links.

=cut

sub view_genome_data : Chained('/organism/find_organism') PathPart('genome') {
    my ( $self, $c ) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $organism = $c->stash->{organism};
    $c->throw_404 unless $organism && $organism->search_related('organismprops',
                             { 'type.name' => 'genome_page', 'me.value' => 1 },
                             { join => 'type' },
                         )->count;

    $c->stash->{dbh} = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id)->storage()->dbh();
    
    (my $template_name = '/genomes/'.$organism->species.'.mas') =~ s/ /_/g;

    # find assemblies for this organism
    $c->stash->{assembly_list} = my $assembly_list = [
        map {
            my $s = $_;
            my $h = $self->_bs_sample_to_display_hashref( $c, $s );
            # also add the associated annotation_sets to it
            $h->{annotation_sets} =  [ $self->assembly_annotations( $s ) ];
            $h
        } $self->assemblies_for_organism( $organism )->all
      ];

    # find annotation sets for this organism
    $c->stash->{annotation_list} = [
        map {
            $self->_bs_sample_to_display_hashref( $c, $_ );
        }
        # annotation sets are the ones that were found related to the
        # assemblies, plus ones queried from the db by organism, made
        # unique, and sorted
        sort { $a->metadata && $a->metadata->create_date->epoch <=> $b->metadata && $b->metadata->create_date->epoch
               || $a->sample_name cmp $b->sample_name
             }
        $self->uniq_bs_samples(
            ( map { @{ $_->{annotation_sets} || [] } } @$assembly_list ),
            $self->annotation_sets_for_organism( $organism )->all
        )
      ];

    # choose which template we will use
    $c->stash->{template} =
        $c->view('Mason')->component_exists( $template_name )
            ? $template_name : '/genomes/default.mas';
}

=head2 view_inbred_genomes

Public path: /organism/Solanum_lycopersicum/inbred_genomes


=cut

sub view_inbred_genome : Path('/organism/Solanum_lycopersicum/inbred_genomes') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = '/genomes/Solanum_lycopersicum/inbreds.mas';
}

=head2 view_tomato_150

Public path: /organism/Solanum_lycopersicum/tomato_150


=cut

sub view_tomato_150 : Path('/organism/Solanum_lycopersicum/tomato_150') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = '/genomes/Solanum_lycopersicum/tomato150.mas';
}

=head2 view_tomato_360

Public path: /organism/Solanum_lycopersicum/tomato_360


=cut

sub view_tomato_360 : Path('/organism/Solanum_lycopersicum/tomato_360') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = '/genomes/Solanum_lycopersicum/tomato360.mas';
}

####### helper methods ##########

sub uniq_bs_samples {
    my $self = shift;
    my %seen;
    return grep !$seen{$_->sample_id}++, @_
}

sub _bs_sample_to_display_hashref {
    my ( $self, $c, $bs_sample ) = @_;

    return {
        name => $c->view('BareMason')->render( $c, '/biosource/sample_link.mas', { sample => $bs_sample } ),
        date => $bs_sample->metadata ? $bs_sample->metadata->create_date : undef,
        description => $bs_sample->description,
        files => [
            map +{ text        => $_->basename,
                   url         => '/metadata/file/'.$_->file_id.'/download',
                   description => $_->comment,
                 },
            $self->assembly_files( $bs_sample )
         ],
    };
}

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

sub annotation_sets_for_organism {
    my ( $self, $organism ) = @_;
    my $schema = $organism->result_source->schema;

    $schema->resultset('BsSample')
           ->search({
               type_id     => { -in => [ uniq map $_->cvterm_id, @{$self->_annotation_cvterms( $schema )}] },
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

sub _annotation_cvterms {
    my ( $self, $schema ) = @_;
    my $t = $schema->resultset('Cv::Cvterm')
           ->search({ 'name' => 'genome_annotation_set' });

    my @terms = $t->all;
    return [ @terms, map $_->recursive_children, @terms ];
}


=head2 view_sequenced_accessions

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub view_sequenced_accessions :Path('/genomes/sequenced_accessions') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/genomes/sequenced_accessions.mas';
}



1;
