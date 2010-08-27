#!/usr/bin/perl
use strict;
use warnings;
use GD::Graph::lines;
use CXGN::Page;
use CatalystX::GlobalContext '$c';

my $page = CXGN::Page->new();

# get from url
my ($deg) = $page->get_encoded_arguments('deg') || 'F';
my ($mode) = $page->get_encoded_arguments('mode');
my ($detail) = $page->get_encoded_arguments('detail');
$detail||=1;
my ($days) = $page->get_encoded_arguments('days');
$days ||= 7;
my ($imgsize) = $page->get_encoded_arguments('imgsize');

# Get the digitemp data
my $data_file = $c->config->{"pucebaboon_file"};

open (my $fh, $data_file) or barf("Can't open file $data_file: $!");
my @lines = <$fh>;
close $fh;

# get only the last X days' worth
@lines = splice(@lines,(-576*$days));
my $l = @lines;
warn "using last $l days of data\n$lines[0]\n$lines[-1]\n";

# Parse it into something we can graph
my (@times, @temp_C, @temp_F);
for my $i (0..$#lines){
   	next unless ($i%$detail==0); 
    my @fields = split(/ /,$lines[$i]);
	push(@times, $fields[2]);
	push(@temp_C, $fields[6]);
	push(@temp_F, $fields[8]);
#     $times[$i] = $fields[2];
#     $temp_C[$i] = $fields[6];
#     $temp_F[$i] = $fields[8];
}

barf("Hey, where's the data?") unless @times && @temp_C;

my $random = "&r=" . int(rand(1)*1000000000);
my $current_C = $temp_C[-1];
my $current_F = $temp_F[-1];

sub _last_mod { (stat $_[0])[9] }
my $file_ts = _last_mod($data_file);
my $time = localtime($file_ts);

my $time_diff = time() - $file_ts;

my $day_diff = sprintf("%.1f", $time_diff/60/60/24);

my $temp_disp =<<HTML;
<font size="10">$current_C C  ($current_F F)</font>
HTML

if($time_diff > 1800) {  #30 minutes
	$temp_disp=<<HTML;
<font style="color:#555" size="5">$current_C C  ($current_F F)</font><br />
<font size="6">  OUT-OF-DATE: $day_diff days</font>
HTML
}

if ($mode eq "current") { 
  $page->send_content_type_header();
  print <<HTML;
<html>
<head>
</head>
<body>
<!--
<table width="100%"><tr><td width="150">
<img src="/documents/img/sgn_logo_icon.png" border="0" />
</td>
<td style="text-align:center;vertical-align:middle">
<h2>Server Room Status</h2>
</td>
<td width="150" style="text-align:right">
<img src="/documents/img/sgn_logo_icon.png" border="0" />
</td>
</tr>
</table>
<hr>
-->
<table width="1200">
<tr>
<td width="600">
Temperature as of $time:<br />
$temp_disp<br /><br />
<span style="font-size:0.9em">
<a target="spong" href="cluster_services.pl?mode=html">Cluster QuickView</a>
</span>
</td>
<td width="600">
<a href="temp.pl" target="_TOP">
<img border="0" src="temp.pl?&imgsize=small&detail=10$random&days=$days" width="600" height="100"/>
</a>
</td>
</tr></table>
</body>
</html>

HTML

    exit;
}

# graph settings
my $graph;
if ($imgsize eq 'small'){
    $graph = GD::Graph::lines->new(600,100);
} else {
    $graph = GD::Graph::lines->new(1000,300);
};
my $current = $current_F;
if ($deg eq "C") { 
    $current = $current_C;
}
chomp $current;

$graph->set(
	    'x_label' => 'time',
	    'y_label' => "degrees $deg",
	    'title' => "Temperature in the server room - currently $current$deg - Last $days days",
	    'y_max_value' => ($deg eq 'C' ? 32 : 90),
	    'y_min_value' => ($deg eq 'C' ? 21 : 70),
	    'x_label_skip' => @times/5,
	    'transparent' => 0
	    ) or barf($graph->error());



# assemble the array and make the graph
my $data;
if ($deg eq "C") { 
    $data = [\@times, \@temp_C ];
}
else  {
$data = [\@times, \@temp_F];
}
my $gd = $graph->plot($data) or barf($graph->error());
print "Content-type: image/png\n\n".$gd->png();

sub barf {

    my $message = shift;

    print "Content-type: text/plain\n\n$message\n";

    exit;

}
