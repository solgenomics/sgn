use strict;
use SGN::I18N ();
use HTML::Entities ();
use CatalystX::GlobalContext '$c';
my SGN::I18N $ui_vector_info_i18n = SGN::I18N::translate($c);

use CXGN::Genomic::Clone;
use CXGN::Tools::Text;
use CXGN::Page::FormattingHelpers qw(
				     page_title_html
				     html_break_string
				     blue_section_html
				     commify_number
				    );
use CXGN::Genomic::Tools qw/clone_annotation_sequence/;

my $page=CXGN::Page->new(SGN::I18N::translate($ui_vector_info_i18n, 'transformation.cloning_vector_information', 'Cloning Vector Information', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),'Robert Buels');
my($id)=$page->get_encoded_arguments('id');
$id =~ /^\d+$/
  or $page->error_page(SGN::I18N::translate($ui_vector_info_i18n, 'transformation.vector_not_found', 'Vector not found.', undef, { entities => '<>&', decode => 0 }));
my $vector = CXGN::CDBI::SGN::CloningVector->retrieve($id)
  or $page->error_page((SGN::I18N::translate($ui_vector_info_i18n, 'transformation.no_vector_found_with_id', 'No vector found with ID \'', undef, { entities => '<>&', decode => 0 }) . "$id" . "\'"));
my $sequence = $vector->seq
  or $page->error_page((SGN::I18N::translate($ui_vector_info_i18n, 'transformation.no_sequence_information_for_vector', 'No sequence information for vector ', undef, { entities => '<>&', decode => 0 }) . $vector->name));
my $length_string = commify_number(length($sequence));

$page->header;
print page_title_html((SGN::I18N::translate($ui_vector_info_i18n, 'transformation.cloning_vector', 'Cloning Vector ', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }) . "&ndash; " . $vector->name));
print blue_section_html(SGN::I18N::translate($ui_vector_info_i18n, 'global.est.sequence', 'Sequence', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
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
