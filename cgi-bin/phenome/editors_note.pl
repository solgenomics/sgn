use strict;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
				     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     html_alternate_show
                                     tooltipped_text
                                    /;

my $page = CXGN::Page->new();

 $page->header();

print page_title_html ('Note to Locus Editors');
my $annotation_link = qq | <a href="http://docs.google.com/View?docid=ddhncntn_0cz2wj6">annotation guidelines</a> |;

print  "<b>Locus editors</b> are experts with a research focus, and generally authors, on the locus. If you are interested in becoming an editor for a locus,  please make a request by clicking the 'Request editor privileges' link under the 'Locus details' subsection of the locus page.<br />
<br>&nbsp;<br />
 <b>Editors:</b><br/>

    \t* have the privilege to edit the contents of the locus page.<br />
     \t* can add data on the locus page as new knowledge on the locus emerges. Each subsection on the locus page can be modified by clicking the edit/annotation links .<br />
    \t* initiate discussion on accuracy of data submitted by other editors, submitters and SGN curators.<br />
   \t* can suggest ideas to in-house curators on improving the data display, annotation tools, additional subsections etc.<br />
   \t* can create new webpages for their newly identified and documented loci.<br />
   \t* can list all relevant publications on their locus of interest.<br />
<br>&nbsp;<br />
 <b>Reference</b> on how to annotate a locus can be found here: $annotation_link.<br />

<br>&nbsp;<br />
<b>Contact</b> SGN staff by emailing to <a href=mailto:sgn-feedback\@sgn.cornell.edu>sgn-feedback\@sgn.cornell.edu</a> <br />";


$page->footer();

exit();




