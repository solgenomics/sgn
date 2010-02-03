use strict;
use CXGN::Genomic::Clone;
use CXGN::Tools::Text;
use CXGN::Page::FormattingHelpers qw(
				     page_title_html
				     html_break_string
				     blue_section_html
				     commify_number
				    );
use CXGN::Genomic::Tools qw/clone_annotation_sequence/;

my $page=CXGN::Page->new('Cloning Vector Information','Robert Buels');
my($id)=$page->get_encoded_arguments('id');
$id =~ /^\d+$/
  or $page->error_page('Vector not found.');
my $vector = CXGN::CDBI::SGN::CloningVector->retrieve($id)
  or $page->error_page("No vector found with ID '$id'");
my $sequence = $vector->seq
  or $page->error_page("No sequence information for vector ".$vector->name);
my $length_string = commify_number(length($sequence));

$page->header;
print page_title_html('Cloning Vector &ndash; '.$vector->name);
print blue_section_html('Sequence',
			"$length_string bases",
			join('', ("<span class=\"sequence\">&gt;",
				  $vector->name,
				  "<br />",
				  html_break_string($sequence,98),
				  "</span>",
				 )
			    )
		       );
$page->footer;
