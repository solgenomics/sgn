use CXGN::Page;
use CXGN::Tools::File;
my $page = CXGN::Page->new("Biofools Group Page", "Chris Carpita");

my ($left_bound, $record_size) = 
$page->get_arguments(
	qw/  left_bound  record_size /);

$left_bound ||= 1;
$record_size ||= 20;

my ($content, $size, $total) = CXGN::Tools::File::get_div_sections(
	"families.txt", 
	$record_size, 
	$left_bound - 1
);

my $navbar = nav_bar($left_bound, $size, $total);
my $navinfo = nav_info($left_bound, $size, $total);

my $wholebar = <<HTML;
<table width="100%">
<tr>
<td style="text-align:left">
$navinfo
</td>
<td style="text-align:right">
$navbar
</td></tr></table>
HTML

$page->header();


print <<HTML;
<center>
<h2>Biofools Home Page</h2>
$wholebar
<hr>
$content

$wholebar
</center>
HTML

$page->footer();


sub nav_bar {
	my ($lb, $size, $total) = @_;
	my $next_lb = $lb + $size;
	$next_lb = $total - $size + 1 if $next_lb >= $total;
	my $prev_lb = $lb - $size;
	$prev_lb = 1 if $prev_lb < 1;
	
	my $last_lb = $total - $size + 1;
	my $first_lb = 1;

	my $content = <<HTML;
	<a href="?left_bound=$first_lb&record_size=$size">&lt;&lt; First</a>&nbsp;&nbsp;
	<a href="?left_bound=$prev_lb&record_size=$size">&lt; Prev</a>&nbsp;&nbsp;
	<a href="?left_bound=$next_lb&record_size=$size">Next &gt;</a>&nbsp;&nbsp;
	<a href="?left_bound=$last_lb&record_size=$size">Last &gt;&gt;</a>
HTML
	return $content;

}

sub nav_info {
	my ($lb, $size, $total) = @_;
	my $last = $lb + $size - 1;
	return "Records $lb - $last out of $total";
}
