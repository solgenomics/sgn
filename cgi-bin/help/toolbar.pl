use strict;
use CXGN::Page;
use CXGN::Page::Toolbar::SGN;
my $page=CXGN::Page->new('SGN navigation toolbar help','john');
$page->header('SGN navigation toolbar help','Toolbar help');
print<<END_HEREDOC;
The toolbar is located on the upper portion of the screen on almost
every page on the SGN site and provides an easy way to navigate the
site. The toolbar consists of the SGN logo and a row of links that link
to the main portions of the site. When the mouse passes over a link, a
pull down menu is displayed (assuming you have JavaScript turned on). 
You can either click the main link or scroll down the menu to choose a 
menu item. If you are having problems with the toolbar, you may want to
bookmark this page, and use it instead.
<br /><br />
END_HEREDOC
my $tb=CXGN::Page::Toolbar::SGN->new();
for my $heading($tb->headings())
{
    my $heading_link=$tb->heading_link($heading);
    my $heading_desc=$tb->heading_desc($heading);
    print"<b><a href=\"$heading_link\">$heading</a></b> - $heading_desc<br />\n";
    print"<ul style=\"list-style-type: none;\">\n";
    for my $menu_option($tb->menu_options($heading))
    {
        my $option_link=$tb->option_link($heading,$menu_option);
        my $option_desc=$tb->option_desc($heading,$menu_option);
        print"<li><a href=\"$option_link\">$menu_option</a> - $option_desc<br /></li>\n";
    }
    print"</ul>\n";
}
$page->footer();
