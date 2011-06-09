package SGN::Controller::Search;

use Moose;
use namespace::autoclean;
use CXGN::Genomic::Search::Clone;
use HTML::FormFu;
use YAML::Any qw/LoadFile/;
use CXGN::Search::CannedForms;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel/;
use CXGN::Page::Toolbar::SGN;
use CXGN::Glossary qw(get_definitions create_tooltips_from_text);

# this is suboptimal
use CatalystX::GlobalContext qw( $c );

BEGIN {extends 'Catalyst::Controller'; }

my @tabs = (
            ['/search/loci','Genes'],
            ['/search/qtl','QTLs & Phenotypes'],
            ['/search/unigene','Unigenes'],
            ['/search/family', 'Unigene Families' ],
            ['/search/markers','Markers'],
            ['/search/bacs','Genomic Clones'],
            ['/search/est_library','ESTs'],
            ['/search/images','Images'],
            ['/search/directory','People'],
            ['/search/template_experiment_platform', 'Expression'],
            ['/insitu/search.pl', 'Insitu' ],
            ['/organism/search/', 'Organism'],
#           Not ready for prime-time yet
#            ['/feature/search/', 'Feature'],
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
    loci                         => 0,
    phenotype                    => 1,
    phenotypes                   => 1,
    phenotype_qtl_trait          => 1,
    qtl                          => 1,
    trait                        => 1,
    unigene                      => 2,
    family                       => 3,
    families                     => 3,
    marker                       => 4,
    markers                      => 4,
    bacs                         => 5,
    est                          => 6,
    est_library                  => 6,
    images                       => 7,
    directory                    => 8,
    template                     => 9,
    experiment                   => 9,
    platform                     => 9,
    template_experiment_platform => 9,
};

=head1 NAME

SGN::Controller::Search - SGN Search Controller

=head1 DESCRIPTION

SGN Search Controller. Most, but not all, search code interacts with this
controller. This controller defines the general search interface that used to
live at direct_search.pl, and links to all other kinds of search.

=cut

=head2 index

=cut

sub glossary :Path('/search/glossary') :Args() {
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

    $c->forward_to_mason_view(
        '/search/controller.mas',
        content => $response,
    );

}

sub search :Path('/search/') :Args() {
    my ( $self, $c, $term, @args ) = @_;

    # make /search/index.pl show the list of all kinds of searches
    $term = '' if $term eq 'index.pl';

    $term = $c->req->param('search') if $term eq 'direct_search.pl';

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
  my $dbh   = CXGN::DB::Connection->new();
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
                    ['/search/template','Templates'],
                    ['/search/experiment','Experiments'],
                    ['/search/platform', 'Platforms']);
        my $tabfuncs = {
            template                     => \&template_tab,
            experiment                   => \&experiment_tab,
            platform                     => \&platform_tab,
            template_experiment_platform => \&template_tab,
        };

        my $term = $c->stash->{term} || 'template';

        my $tabs     = modesel(\@tabs, $tab_num->{template}); #print out the tabs
        my $response = sprintf "$tabs<div>%s</div>", $tabfuncs->{$term}();
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
                    ['/search/phenotypes','Mutants & Accessions'],
                    ['/search/qtl','QTLs'],
                    ['/search/trait', 'Traits']);
        my @tabfuncs = (\&phenotype_tab, \&qtl_tab, \&trait_tab);

        my $term = $c->stash->{term} || 'phenotype';

        $term = 'qt' if $term eq 'cvterm_name';

        my $tabsel =
            ($term =~ /phenotypes/i) ? 0
          : ($term =~ /qtl/i)        ? 1
          : ($term =~ /trait/i)      ? 2
          : -1 ;
        my $tabs = modesel(\@tabs, $tabsel); #print out the tabs
        my $response = sprintf "$tabs<div>%s</div>", $tabfuncs[$tabsel]();
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
