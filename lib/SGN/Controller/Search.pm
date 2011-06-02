package SGN::Controller::Search;

use Moose;
use namespace::autoclean;
use CXGN::Genomic::Search::Clone;
use HTML::FormFu;
use YAML::Any qw/LoadFile/;
use CXGN::Search::CannedForms;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel/;
use CXGN::Page::Toolbar::SGN;

# this is suboptimal
use CatalystX::GlobalContext qw( $c );

BEGIN {extends 'Catalyst::Controller'; }

my @tabs = (
            ['?search=loci','Genes'],
            ['?search=phenotype_qtl_trait','QTLs & Phenotypes'],
            ['?search=unigene','Unigenes'],
            ['?search=family', 'Unigene Families' ],
            ['?search=markers','Markers'],
            ['?search=bacs','Genomic Clones'],
            ['?search=est_library','ESTs'],
            ['?search=images','Images'],
            ['?search=directory','People'],
            ['?search=template_experiment_platform', 'Expression']
           );

my @tabfuncs = (
                \&gene_tab,
                \&phenotype_submenu,
                \&unigene_tab,
                \&family_tab,
                \&marker_tab,
                \&bac_tab,
               # \&est_library_submenu,
                \&est_tab,
                \&images_tab,
                \&directory_tab,
                \&template_experiment_platform_submenu,
    );

my $tab_num = {
    loci        => 0,
    phenotype   => 1,
    qtl         => 1,
    trait       => 1,
    unigene     => 2,
    family      => 3,
    families    => 3,
    markers     => 4,
    bacs        => 5,
    est         => 6,
    est_library => 6,
    images      => 7,
    directory   => 8,
    template    => 9,
    experiment  => 9,
    platform    => 9,
};

=head1 NAME

SGN::Controller::DirectSearch - Catalyst Controller

=head1 DESCRIPTION

Direct search catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub search :Path('/search/') :Args(1) {
    my ( $self, $c, $term, @args ) = @_;

    $c->stash->{term} = $term;

    my $response;
    if ($term) {
        $response = modesel(\@tabs,$tab_num->{$term}); # tabs
        $response   .= $tabfuncs[$tab_num->{$term}]();

        $c->forward_to_mason_view(
            '/search/controller.mas',
            content => $response,
        );
    } else {
        my $tb = CXGN::Page::Toolbar::SGN->new();
        $response = $tb->index_page('search');
    }
    $c->forward_to_mason_view(
        '/search/controller.mas',
        content => $response,
    );
}

sub annotation_tab {
    return CXGN::Search::CannedForms->annotation_search_form();
}

#display a second level of tabs, allowing the user to choose between EST and library searches
sub est_library_submenu {
        my @tabs = (
                    ['?search=est','ESTs'],
                    ['?search=library','Libraries']);
        my @tabfuncs = (\&est_tab, \&library_tab);

        my $term = $c->stash->{term} || 'est';
        my $tabsel =
            ($term=~ /est/i)        ? 0
          : ($term =~ /library/i)   ? 1
          : 0 ;

        my $tabs = modesel(\@tabs, $tabsel); #print out the tabs
        my $response = sprintf "$tabs<div>%s</div>", $tabfuncs[$tab_num->{$term}]();
        return $response;
}

sub est_tab {
    return CXGN::Search::CannedForms->est_search_form();
}

sub library_tab {
    return CXGN::Search::CannedForms->library_search_form();
}

sub unigene_tab {
    return CXGN::Search::CannedForms->unigene_search_form();
}

sub family_tab {
    return CXGN::Search::CannedForms->family_search_form();
}

sub marker_tab {

  return <<MARKERTAB;
<h3><b>Marker search</b></h3>
MARKERTAB

  my $dbh = CXGN::DB::Connection->new();
  my $mform = CXGN::Search::CannedForms::MarkerSearch->new($dbh);
  return   '<form action="/search/markers/markersearch.pl">'
    . $mform->to_html() .
      '</form>';

}

sub bac_tab {
    return CXGN::Search::CannedForms->clone_search_form();
}

sub directory_tab {
    return CXGN::Search::CannedForms->people_search_form();
}

sub gene_tab {
    return CXGN::Search::CannedForms->gene_search_form();
}
sub phenotype_tab {
    my $form = HTML::FormFu->new(LoadFile($c->path_to(qw{forms stock stock_search.yaml})));
    return $c->render_mason('/stock/search.mas' ,
        form   => $form,
        schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado'),
    );
}
sub qtl_tab {
    return CXGN::Search::CannedForms->qtl_search_form();
}
sub trait_tab {
    return $c->render_mason('/ontology/traits.mas' );
}

sub images_tab {
    return CXGN::Search::CannedForms->image_search_form();
}

sub template_experiment_platform_submenu {
        my @tabs = (
                    ['?search=template','Templates'],
                    ['?search=experiment','Experiments'],
                    ['?search=platform', 'Platforms']);
        my @tabfuncs = (\&template_tab, \&experiment_tab, \&platform_tab);

        my $term = $c->stash->{term} || 'template';

        my $tabs = modesel(\@tabs, $tab_num->{$term}); #print out the tabs
        my $response = sprintf "$tabs<div>%s</div>", $tabfuncs[$tab_num->{$term}]();
        return $response;
}

sub template_tab {
    return CXGN::Search::CannedForms->expr_template_search_form();
}

sub experiment_tab {
    return CXGN::Search::CannedForms->expr_experiment_search_form();
}

sub platform_tab {
    return CXGN::Search::CannedForms->expr_platform_search_form();
}

sub phenotype_submenu {
        my @tabs = (
                    ['?search=phenotypes','Mutants & Accessions'],
                    ['?search=qtl','QTLs'],
                    ['?search=trait', 'Traits']);
        my @tabfuncs = (\&phenotype_tab, \&qtl_tab, \&trait_tab);

        my $term = $c->stash->{term} || 'phenotype';

        $term = 'qt' if $term eq 'cvterm_name';

        my $tabsel =
          ($term=~ /phenotypes/i)          ? 0
          : ($term =~ /qtl/i)   ? 1
          : ($term =~ /trait/i)     ? 2
          : -1 ;
        my $tabs = modesel(\@tabs, $tabsel); #print out the tabs
        my $response = sprintf "$tabs<div>%s</div>", $tabfuncs[$tab_num->{$term}]();
        return $response;
}


=head1 AUTHOR

Converted to Catalyst by Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
