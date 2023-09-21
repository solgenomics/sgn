package SGN::Controller::Search;
use Moose;
use URI::FromHash 'uri';
use namespace::autoclean;
use Data::Dumper;

use CXGN::Search::CannedForms;
use CXGN::Page::Toolbar::SGN;
use CXGN::Glossary qw(get_definitions create_tooltips_from_text);

# this is suboptimal
use CatalystX::GlobalContext qw( $c );

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::Search - SGN Search Controller

=head1 DESCRIPTION

SGN Search Controller. Most, but not all, search code interacts with this
controller. This controller defines the general search interface that used to
live at direct_search.pl, and links to all other kinds of search.

=cut

sub auto : Private {
    $_[1]->stash->{template} = '/search/stub.mas';
}

=head1 PUBLIC ACTIONS

=cut

=head2 glossary

Public path: /search/glossary

Runs the glossary search.

=cut

sub glossary : Path('/search/glossary') :Args() {
    my ( $self, $c, $term ) = @_;
    my $response;
    if($term){
        my @defs = get_definitions($term);
        unless (@defs){
            $response = "<p>Your term was not found. <br> The term you searched for was $term.</p>";
        } else {
            $response = "<hr /><dl><dt>$term</dt>";
            for my $d (@defs){
                $response .= "<dd>$d</dd><br />";
            }
            $response .= "</dl>";
        }
    } else {
        $response =<<DEFAULT;
<hr />
<h2>Glossary search</h2>
<form action="#" method='get' name='glossary'>
<b>Search the glossary by term:</b>
<input type = 'text' name = 'getTerm' size = '50' tabindex='0' />
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type = 'submit' value = 'Lookup' /></form>
<script type="text/javascript" language="javascript">
document.glossary.getTerm.focus();
</script>

DEFAULT
    }

    $c->stash(
        content  => $response,
    );

}

=head2 old_direct_search

Public path: /search/direct_search.pl

Redirects to the new search functionality.

=cut

sub old_direct_search : Path('/search/direct_search.pl') {
    my ( $self, $c ) = @_;

    my $term = $c->req->param('search');

    $term =~ s/[{}\n\r;'"]//g;
    
    # map the old direct_search param to the new scheme
    $term = {
        cvterm_name => 'qtl',

        qtl         => 'phenotypes/qtl',
        marker      => 'markers',

        # expression
        platform    => 'expression/platform',
        template    => 'expression/template',
        experiment  => 'expression/experiment',

        # transcripts
        est_library => 'transcripts/est_library',
        est         => 'transcripts/est',
        unigene     => 'transcripts/unigene',
        library     => 'transcripts/est_library',

        template_experiment_platform => 'expression',

        bacs        => 'genomic/clones',

        phenotype_qtl_trait => 'phenotypes',


    }->{$term} || $term;
    $c->res->redirect('/search/'.$term, 301 );
}

=head2 search_index

Public path: /search/index.pl, /search/

Display a search index page.

=cut

sub search_index : Path('/search/index.pl') Path('/search') Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = '/search/advanced_search.mas';
}

sub family_search : Path('/search/family') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->family_search_form();
}

sub marker_search : Path('/search/markers') Args(0) {
    my ( $self, $c ) = @_;
    my $dbh   = $c->dbc->dbh;
    my $mform = CXGN::Search::CannedForms::MarkerSearch->new($dbh);
    $c->stash->{content} =
        '<form action="/search/markers/markersearch.pl">'
        . $mform->to_html()
        . '</form>';

}

sub bac_search : Path('/search/genomic/clones') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->clone_search_form();
}

sub directory_search : Path('/search/directory') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->people_search_form();
}

#sub gene_search : Path('/search/loci') Args(0) {
#    $_[1]->stash->{content} = CXGN::Search::CannedForms->gene_search_form();
#}

sub images_search : Path('/search/images') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/images.mas';
    #$_[1]->stash->{content} = CXGN::Search::CannedForms->image_search_form(); ####DEPRECATED CGIBIN CODE
}

sub bulk_search : Path('/search/bulk') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    $c->stash->{template} = '/search/bulk.mas';
}

=head1 AUTHOR

Converted to Catalyst by Jonathan "Duke" Leto, then heavily refactored
by Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
