#!/usr/bin/perl


use CGI;
my $cgi = new CGI;

my $mode = $cgi->param('mode');


my $PROCESSORS = 16*4;
my $THRESHOLD = 80;  #Percent CPU to consider processor "used"

my @services = ();

for(my $i=1; $i<=8; $i++){
	push(@services, "/var/lib/spong/database/blade$i.cluster.sgn/services");
	push(@services, "/var/lib/spong/database/shiv$i.cluster.sgn/services");
}


my %cpu_files = ();
foreach(@services){
	my ($cpu_file) = `ls $_/cpu*`;
	my ($machine) = /(shiv\d+)/;
	($machine) = /(blade\d+)/ unless $machine;
	chomp $cpu_file;
	$cpu_files{$machine} = $cpu_file;
}	

my $total_used = 0;
my $web_html = "<table border=\"0\" cellspacing=\"5\">";

foreach my $mach ( sort keys %cpu_files ) {
	my $cpu_file = $cpu_files{$mach};
	$web_html .= "<tr> <td style=\"vertical-align:top\">";
	print "\n$mach" unless $mode eq "html";
	$web_html .= "$mach</td><td style=\"vertical-align:top;width:100px\">";
	open(FH, $cpu_file);
	my $used = 0;
	my $content = "";
	my $row_html = "";
	while(<FH>){
		my ($pid, $cpu, $status, $time, $command) =
			/(\d+)\s+([0-9\.]+)\s+(\w+)\s+\S+\s+([0-9\:\-]+)\s+(.*)$/;
		next unless $pid;
		if($cpu >= $THRESHOLD){
			$content .= "\n\t$pid\t$cpu\t$time\t$command";
		
			#Style command for web display:
			$command =~ s/^(\S*?)([^\/\s]+)\s/$1<span style="color:black;font-weight:bold">$2<\/span> /;  #embolden the name of the program
			$command = "<span style=\"font-size:0.9em;color:#555\">$command</span>"; #default stylin'
			
			$row_html .= "$pid&nbsp;&nbsp;$cpu&nbsp;&nbsp;$time&nbsp;&nbsp;$command<br />";
			$used++;
			$total_used++;
		}
	}
	$row_html .= "<span style=\"color:#555\">Available</span>" unless $used;
	$web_html .= "&nbsp;$used&nbsp;in&nbsp;use&nbsp;&nbsp;</td><td style=\"vertical-align:top\">$row_html</td></tr>";	
#	$content .= "\n" unless $used;
	print "\t$used/4 processors in use" unless $mode eq "html";
	print $content unless $mode eq "html";
}
$web_html .= "</table>";


my $available = ($PROCESSORS - $total_used);

$web_html = <<HTML;

<html>
<head>
<title>Cluster QuickView</title>

</head>
<body>
<h2>Cluster QuickView</h2>
<!--
<a href="http://rubisco.sgn.cornell.edu/spong-cgi/www-spong.cgi">&lt;&lt;Back to Spong</a><br />
-->
<span style="font-size:1.05em; color:#222">
Total processors used: <b style="color:#411">$total_used</b> &nbsp;&nbsp;&nbsp; Available: <b style="color:#141">$available</b>
<br />
</span>
<br />
$web_html
<br />
<a href="server_room.pl" target="_TOP">&lt;&lt; Back</a>
</body>
</html>
HTML


if($mode eq "html"){
	print $web_html;
}
else{
	print "\n";
	print "\nTotal Processors used: $total_used\tAvailable: $available";
	print "\n";
}



