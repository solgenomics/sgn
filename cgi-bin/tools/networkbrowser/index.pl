
use strict;
use warnings;

use File::Temp;
use File::Spec;
use CXGN::Page;
use CXGN::Sunshine::Browser;
use CXGN::Sunshine::Node;
use CXGN::Tools::WebImageCache;

my $page = CXGN::Page->new("Sunshine", "Lukas");

my ($name, $type, $level, $force, $hide_relationships, $hilite) = $page->get_encoded_arguments("name", "type", "level", "force", "hide", "hilite");

$name = $name || "0";
$type = $type || "0";
$level = $level || "0";

$page->jsan_use("MochiKit.DOM");
$page->jsan_use("MochiKit.Async");
$page->jsan_use("Prototype");
$page->jsan_use("CXGN.Sunshine.NetworkBrowser");

$page->header("SGN Sunshine Browser", "SGN Network Browser");

print <<JAVASCRIPT;

<table><tr><td height="450" width="450"><div id=\"network_browser\" >\[loading...\]</div></td><td width="250"><div id="relationships_legend">[Legend]</div><br /><div id="level_selector">[Levels]</div></td></tr></table>

    <script language="javascript" type="text/javascript">
    
//    document.write('HELLO FROM JAVASCRIPT');

 var nb = new CXGN.Sunshine.NetworkBrowser();
//nb = new CXGN.Sunshine.NetworkBrowser();

nb.setLevel($level);
nb.setType('$type');
nb.setName('$name');
nb.setHilite('$hilite');
nb.fetchRelationships();
//nb.setHiddenRelationshipTypes('$hide_relationships');
nb.initialize();

</script>

JAVASCRIPT

$page->footer();
