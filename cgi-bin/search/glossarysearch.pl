use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw(tooltipped_text);
use CXGN::DB::Connection;
use CXGN::VHost;
use CXGN::Glossary qw(get_definitions create_tooltips_from_text);
my $dbh=CXGN::DB::Connection->new({dbschema=>"public"});
my $page=CXGN::Page->new("Glossary Search","johnathon");
my ($term)=$page->get_encoded_arguments("getTerm");
$page->header("Glossary Search","Glossary Search");

if($term){
    my @defs = get_definitions($term);
    if(@defs == 0){
	print "<p>Your term was not found. <br> The term you searched for was $term.</p>";
    }
    else{
	print "<hr /><dl><dt>$term</dt>";
	for my $arr(@defs){
	    print "<dd>$arr</dd><br />";
	}
	print "</dl>";
    }
}

    print <<GETINFO;
	<hr />
	<h2>Term:</h2>
	<form action = "#" method = 'get' name = 'glossary'>
	<b>Search the glossary by term:</b>
	<input type = 'text' name = 'getTerm' size = '50' tabindex='0' />
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
    <input type = 'submit' value = 'Lookup' /></form>
	<script type="text/javascript" language="javascript">
document.glossary.getTerm.focus();
</script>

GETINFO

$page->footer();
