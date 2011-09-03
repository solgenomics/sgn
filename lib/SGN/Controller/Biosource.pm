=head1 NAME

SGN::Controller::Biosource - controller for working with Biosource data, which is metadata about datasets

=cut

package SGN::Controller::Biosource;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

use CXGN::Biosource::Sample;
use CXGN::GEM::Target;

=head1 PUBLIC ACTIONS

=head2 view_sample

Public path: /data_source/<ident>/view

View a biosource sample detail page.

=cut

sub view_sample : Chained('get_sample') PathPart('view') Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('get_sample_targets');
    $c->forward('get_sample_files');

    $c->stash(
        sample_relations_href => { $c->stash->{sample}->get_relationship },
        pub_list              => [ $c->stash->{sample}->get_publication_list ],

        template => '/biosource/sample_detail.mas',
      );

}

### helper actions ###

# chain root for retrieving a biosource sample, URL beginning with
# /data_source/<ident>.  supports either an ID number or a sample name as
# the identifier
sub get_sample : Chained('/') CaptureArgs(1) PathPart('data_source') {
    my ( $self, $c, $ident ) = @_;

    $ident or $c->throw_client_error('invalid arguments');

    my $schema = $c->stash->{schema} = $c->dbic_schema('CXGN::Biosource::Schema','sgn_chado');

    no strict 'refs';
    my $method_name = $ident =~ /\D/ ? 'new_by_name' : 'new';
    $c->stash->{sample} = CXGN::Biosource::Sample->$method_name( $schema, $ident )
        or $c->throw_404;
}

sub get_sample_files : Private {
    my ( $self, $c ) = @_;

    $c->stash->{files} = [
            $c->stash->{sample}->get_bssample_row
                               ->search_related('bs_sample_files')
                               ->search_related('file')
                               ->all
     ];
}

# The sample can be associated expression data (search sample_id in
# gem.ge_target_element table)
sub get_sample_targets : Private {
    my ( $self, $c ) = @_;

    my $sample = $c->stash->{sample};

    return unless $sample->get_sample_id;

    my $gemschema = $c->dbic_schema('CXGN::GEM::Schema','sgn_chado');

    $c->stash->{target_list} = [
        map { CXGN::GEM::Target->new( $gemschema, $_ ) }
        $gemschema->resultset('GeTargetElement')
                  ->search({ sample_id => $sample->get_sample_id })
                  ->get_column('target_id')
                  ->all
    ];
}


1;
