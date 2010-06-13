#!/usr/bin/perl

$c->forward_to_mason_view('/breeders_toolbox/index.mas');

=head1 Name

phenome/quick_start.pl

=head1 Description

Displays a html page with links to SGN pages that are useful for the breeders community.

=head1 Author

Naama Menda (nm249@cornell.edu)

=cut

# use strict;
# use CXGN::Page;
# use CXGN::Page::FormattingHelpers qw/ info_section_html page_title_html /;
# use CXGN::DB::Connection;
# use CXGN::VHost;

# my $vhost_conf=CXGN::VHost->new();
# my $documents_folder=$vhost_conf->get_conf('basepath').$vhost_conf->get_conf('documents_subdir');
# my $page=CXGN::Page->new("SGN quick start page for breeders");
# $page->header("SGN breeders quick start");

# #print qq |<img src= "/documents//img/tomato_breeders_toolbox.jpg" width = 160 />|; 
# print page_title_html(qq | <img src= "/documents//img/tomato_breeders_toolbox.jpg" width = 80 />Breeders toolbox|);


# print <<HTML;

# <div class="boxbgcolor2">The purpose of this page is to give breeders direct links to breeder-relevant tools and data on SGN. It is a work in progress and your feedback or suggestions are welcome to build this into a comprehensive, easy to use and breeder-friendly resource.<br /><br />Please contact <a href="mailto:jv27\@cornell.edu">Joyce van Eck</a> for suggestions. <br /><br /></div><br />

# HTML


# # Show a blue section for gene-related links
# #
# my $dbh = CXGN::DB::Connection->new();

# my $gene_links = "<ul>";
# $gene_links .= qq{ <li>Search the SGN <a href="/search/direct_search.pl?search=loci">Locus database</a> for your favorite gene</li> };

# $gene_links .= qq{<li> Search the SGN <a href="/search/direct_search.pl?search=phenotypes">Phenotype database</a> for Solanaceae accessions</li> };

# $gene_links .= qq{<li> Search the SGN <a href="/search/direct_search.pl?search=cvterm_name">Traits/QTLs database</a> for phenotype and QTL data</li> };
# $gene_links .= qq{ <li>SGN gene and phenotype <a href="/phenome/">submission guide</a> </li></ul> };

# print info_section_html(title=>"Gene and phenotype information", contents=>$gene_links);


# # Tools section

# my $tool_links="<ul>";
# $tool_links .= qq{<li>Browse the SGN <a href="/search/direct_search.pl?search=markers/">Markers database</a></li> };
# $tool_links .= qq{<li>Browse available controlled vocabularies using the SGN <a href="/tools/onto/">Ontology browser</a></li> };
# $tool_links .= qq{<li>Develop CAPS markers using the <a href="/tools/caps_designer/caps_input.pl">CAPS Designer</a></li>};
# $tool_links .= qq{<li>Check intron locations in transript data using the <a href="/tools/intron_detection/find_introns.pl">Intron Finder</a></li>};
# $tool_links .= qq{<li><a href="/phenome/qtl_form.pl">QTL data submssion</a> and on-the-fly QTL analysis <a href="/search/direct_search.pl?search=cvterm_name/">for Solanaceae traits</a></li> };
# $tool_links .="<ul>";

# print info_section_html(title=>"SGN tools", contents=>$tool_links);

# # wish list
# my $wish_links;

# $wish_links .= qq {<ul><li>SNP discovery tool. This will be part of the <a href="https://www.msu.edu/~douchesd/solcapwebpage.htm">SolCAP</a> project.</li></ul> };



# print info_section_html(title=>"Breeder tools under construction", contents=>$wish_links);

# #links
# my $links;

# $links = <<HTML;

# <ul>
# <li><a href="http://www.tomatomap.net/">TomatoMap.Net</a> - a site for Tomato Genetics at Ohio State University.</li>
# <li><a href="http://solcap.msu.edu/">SolCAP</a> - the official SolCAP website at Michigan State University.</li>
# <li><a href="http://www.oardc.ohio-state.edu/vanderknaap/tomato_analyzer.htm">Tomato Analyzer</a> - software for scoring fruit shape and other shapes.</li>
# <li><a href="/help/index.pl#submit">Submitting data to SGN</a> - instruction for data submissions to SGN.</li>
# </ul>

# HTML

# print info_section_html(title=>"Links" , contents=>$links);



# $page->footer();

