#!/usr/bin/perl
use strict;
use CXGN::DB::Connection;
use CXGN::Page::Secretary;
use CXGN::UserPrefs;
use CXGN::Secretary::Query;
use CXGN::Secretary::Gene;
use HTML::Entities;

my $page = CXGN::Page::Secretary->new("Secretary", "Chris");
my $dbh = $page->{dbh};
CXGN::Secretary::Gene->setDBH($dbh);

my $query = $page->{searchQuery};
my $referenceGene = $page->{referenceGene};
my $noCheck = $page->{noCheck};
my $lb = $page->{leftBound};
my $querySize = $page->{querySize};
my $physicalMode = $page->{physicalMode};

if(defined $querySize && (!($querySize =~ /^\d+$/) || $querySize<=0)) { undef $querySize }

my $htmlQuery = $query;
$htmlQuery =~ s/\\(['"\\])/$1/g;
$htmlQuery =~ s/'/&#39/g;

my %EviDefs = %{$page->{evicode2definition}}; 

my $prefh = CXGN::UserPrefs->new($dbh);
my $searchHighlight = $prefh->get_pref('searchHighlight');
unless($searchHighlight){
	$searchHighlight = 0;
	$prefh->set_pref('searchHighlight', 0); 
	$prefh->store();
}

### SENDING HEADERS ####################################
$page->header("Secretary", "Query");
######################################################


print "\n<!--SearchQuery: $htmlQuery -->";

my $fileOpen = 0;
my $fileSize;
my $fh;
my $filename;

my $upload = $page->get_upload();
if($upload){
	$fh = $upload->fh;
	$filename=$upload->filename;
	$fileSize = $upload->size;	
}
if(defined $filename) { 
	$fileOpen = 1; 
}

print<<HTML;
<!-- SearchHighlight: $searchHighlight -->
<table width='100%'>
<tr>
<td style='vertical-align:bottom; text-align:left'>
<a href='index.pl' style='text-decoration:none'><span style='font-size: 36px;'><span style='color:#ff3366;'>Secret</span><span style='color:green'>ary</span></span></a>
</td>
HTML

if($fileOpen){
	print<<HTML;
<td style='text-align:left'>
<span id='loading_notice'>
<span style='font-size:20px; font-weight:bold; color:#333333'>Parsing File for AGIs
<span id='dots0'>&nbsp;&nbsp;&nbsp;</span>
<span id='dots1' style='display:none'>.&nbsp;&nbsp;</span>
<span id='dots2' style='display:none'>..&nbsp;</span>
<span id='dots3' style='display:none'>...</span>
</span>
</span>
</td>
<script language='javascript'>animateDots();</script>
HTML
}

my $userConfirm = 0;

my $queryFail = 0;
my $queryFailText = "";
my $queryWarning = 0;
my $queryWarningText = "";
my $uploadFail = 0;
my $uploadFailText = "";
my @IDs = ();
my @AGIs = (); #array of explicitly queried AGIs
my %AGIscores = (); #associative array: AGI=>score  (0.00-1.00)
my $resultdisplay = "";
my @searchWords = ();	#holds individual words of ts_query for useful endeavors like query highlighting
my $nextPrefix = "";
my $nextPrefixCount = 0;
my $prevPrefix = "";
my $prevPrefixCount = 0;

if(defined $filename && $fileSize > 6000000){
	$uploadFail =1;
	$uploadFailText = "Maximum Filesize Exceeded (6MB Limit)";
	$queryFail = 1;
	$fileOpen = 0;
}

if($fileOpen){
	print "\n<!--UFL defined -->";
	binmode($fh);
	my $offset = 0;
	@AGIs = ();
	%AGIscores = {};
	my $buffer = "";
	my $byte;
	my %seen = ();

	while(sysread($fh, $byte, 1) && @AGIs < 500){
		my $int = unpack 'U', $byte;	
		my $hex = sprintf('%x', $int);
 		if(length($hex) == 1) {$hex = '0' . $hex};
     	$hex = '0x' . uc($hex);

		if($hex eq "0x00" || $hex eq "0xFF") {
			#skip following procedure, and advance a byte, this allows us to read MS.doc's,
			#which have 0x00 or 0xFF-spersed textual storage  A.T.1.G.etc... Why?
		}
		elsif($byte =~ /[ATMCG0-9.]/i){
			$buffer .= $byte;
		}
		elsif(length($buffer) > 8 && $buffer =~ /[ATMCG0-9.]{9,}/i){
			$buffer = uc($buffer);
			while($buffer){
				my ($agi) = $buffer =~ /(AT[1-5MC]G\d{5}\.\d+)/;
				my ($locus) = $buffer =~ /(AT[1-5MC]G\d{5})/;

				if(defined $agi){
					my $check_agi_q = $dbh->prepare("SELECT agi FROM ara_properties WHERE agi='$agi'");
					$check_agi_q->execute();
					if($check_agi_q->fetchrow_array()) { 
						push(@AGIs, $agi) unless $seen{$agi}; 
						$seen{$agi}++;
					}
					$buffer =~ s/AT[1-5MC]G\d{5}\.\d+//;
				}
				elsif($locus){
					my $check_locus_q = $dbh->prepare("SELECT agi FROM ara_properties WHERE locus='$locus'");
					$check_locus_q->execute();
					while(my @array = $check_locus_q->fetchrow_array()){
						push(@AGIs, $array[0])	unless $seen{$array[0]};
						$seen{$array[0]}++;
					}
					$buffer =~ s/AT[1-5MC]G\d{5}//;
				}
				else { $buffer = '' }
			}
			$buffer = '';
		} 
		else {  ##impossible that we have an AGI in the buffer, so flush it 
			$buffer = '';
		}
		#end if byte is non-alphanumeric or period
	}

	#Unique-ifies AGI list
# 	my %seen = ();
# 	@AGIs = grep { ! $seen{$_} ++ } @AGIs;

	$querySize = @AGIs;
	if($querySize >= 500) { 
		$queryWarning = 1;
		$queryWarningText = "AGI parsing limited to the first 500 found";
	}
	elsif($querySize < 1) {
		$queryFail = 1;
		$queryFailText = "No AGIs found in the file: <b>$filename</b><br>";
		$queryFailText .= "If you reloaded this page after sending the file, you may need to send it again";
	}
	foreach(@AGIs){
		$AGIscores{$_} = 1;
	}
	sysseek($fh, 0, 0);
} #end if file sucessfully uploaded
###QUERY############################################################################################
###display results of a QUERY#######################################################################
elsif($query){
	
	@AGIs = (); #array of explicitly queried AGIs
	%AGIscores = (); #associative array: AGI=>score  (0.00-1.00)

	if(my ($locus) = $query =~ /^(AT[1-5MC]G\d{0,5})$/i){  #The whole query has to be a locus prefix and only a locus prefix for physical mode to happen
			$locus = uc($locus);
			my %lowerbounds = (1=>10, 2=>10, 3=>10,4=>0,5=>10,M=>0,C=>0);
			my %upperbounds = (1=>809, 2=>481, 3=>666, 4=>401, 5=>676, M=>14, C=>13);
			$page->{physicalMode} = $physicalMode = 1;
			my ($chrom) = $locus =~ /(AT[1-5MC]G)\d*/;
			my ($position) = $locus =~ /AT[1-5MC]G(\d*)/;
			my ($chromchar) = $locus =~ /AT([1-5MC])G/;
			if(length($position)>3) { $position = substr($position, 0, 3) }
			elsif(length($position)==2) { $position .= "0" }
			elsif(length($position)==1) { $position .= "00" }
			elsif(!defined $position || length($position)<1) { $position = "000" }
			my $num_pos = int($position);
			if($num_pos < $lowerbounds{$chromchar}) { $num_pos = $lowerbounds{$chromchar} }
			if($num_pos > $upperbounds{$chromchar}) { $num_pos = $upperbounds{$chromchar} }
			$position = zeropadleft($num_pos);
			$locus = $chrom . $position;

			$page->{searchQuery} = $query = $locus;
			
			print "<!-- QUERYQUERYQUERY: $query -->";	
			$htmlQuery = $locus;
			my $check_q = $dbh->prepare("SELECT agi FROM ara_properties WHERE locus LIKE '$locus%' ORDER BY locus, agi");
			$check_q->execute();	
			while (my @row = $check_q->fetchrow_array){
				push(@AGIs, $row[0]);
			}
			if(@AGIs<1){
				my $find_next_q = $dbh->prepare("SELECT prefix, genecount FROM ara_prefix_info WHERE prefix > '$locus' LIMIT 1");
				$find_next_q->execute();
				my @result = $find_next_q->fetchrow_array();
				($nextPrefix, $nextPrefixCount) = @result;
				my $find_prev_q = $dbh->prepare("SELECT prefix, genecount FROM ara_prefix_info WHERE prefix < '$nextPrefix' ORDER BY prefix DESC LIMIT 1");
				$find_prev_q->execute();
				@result = $find_prev_q->fetchrow_array();
				($prevPrefix, $prevPrefixCount) = @result;
			}
			$page->{querySize} = scalar(@AGIs);
	}
	else {	
		my $secretary_query = CXGN::Secretary::Query->new({dbh => $dbh, left_bound => $lb, search_query => $query});
		$secretary_query->prepare;
		$secretary_query->execute;	
		@AGIs = $secretary_query->results;
		my $agi2score = $secretary_query->scores;
		@searchWords = $secretary_query->getSearchWords;
		%AGIscores = %$agi2score;
		if(!$querySize) {
			$secretary_query->execute_count;
			$querySize = $secretary_query->resultSize;
			$page->{querySize} = $querySize;
#			die $secretary_query->{db_query};
		}
	}

	if(@AGIs < 1) {
		$queryFail=1;
		$queryFailText = "Your query is either too specific, or all of its terms are too broad";
	}
}
else { 
	$queryFail = 1;
	$queryFailText = "No query specifications";
}

my $agilist = join ":", @AGIs;

if($fileOpen || $uploadFail){
print <<HTML;
<script language='javascript'>
document.getElementById("loading_notice").style.display="none";
killAnimateDots();
</script>
HTML
}

print <<HTML;
<td>
<center><div style="text-align:center"><br>
<form action='query.pl' method="GET" name='fqtop' style="margin:0;white-space:nowrap">
<input type="textbox" name='query' size=40 id='query_focus' value='$htmlQuery'>
<input type="submit" value="Search">
</form></div></center></td>
<td style='width:250;vertical-align:bottom'>
HTML


if($queryFail && !$physicalMode) {
	print <<HTML;
<div style='float:right'>
<span style='text-align:right; font-size:14px'>
No Results
</span>
</div>
HTML
}
elsif($fileOpen) {
	print "<div style='float:right; font-size:14px'><b>$querySize</b> AGIs Found in File</div>";
}
else {
	print "<div style='float:right'>";
	print $page->navigation_control($prevPrefix, $nextPrefix);
	print "</div>";
	$resultdisplay = $page->navigation_info();
	$resultdisplay ||= "";
}



##########################
### Top Bar Display: #######################################################
##########################

# Style/Color of top bar:
print<<HTML; 

</td></tr></table>
<div style='clear:both; height:4px; width:100%;'></div>
<div style='margin:0px;padding-left:3px; clear:both;
HTML

if($physicalMode){
	print "border-top: 1px solid purple; border-bottom: 1px dotted purple; background-color:#f8d0f8; ";
}
elsif($fileOpen || $uploadFail){
	print "border-top: 1px solid #009900; border-bottom: 1px dotted #009900; background-color:#ddffcc;";
}
else {
	print "border-top: 1px solid blue; border-bottom: 1px dotted blue; background-color:#ddddff; ";
}

print <<HTML;
width:100%; font-size:14px; margin-bottom:3px'>
<table style='width:100%;padding:0px'>
<tr>
<td>
HTML
if(defined $querySize && $page->{validUser}){
	print<<HTML;
<span id='hotlistqp'>
<a href='#' onclick='return false;' style='text-decoration:none; font-size:14px; display:none'>
<img border=0 src='/documents/img/secretary/hotlist_add.png'> Add All Results on this Page to Hotlist</a></span>
HTML
}
print <<HTML;
</td>
<td style='text-align:left; margin-left:6px'>
HTML

#physical mode bar contents, left side
if($physicalMode) { 
	print "<span style='color:#990099'>Physical View</span>";
	my $prevQuery = $page->{prevQuery};
	my $prevLB = $page->{prevLB};
	if(defined $prevQuery && defined $prevLB && length $prevQuery > 0 && $prevLB =~ /^\d+$/ && $prevLB > 0){
	 	print "&nbsp;&nbsp;&nbsp;<a style='white-space:nowrap' href='query.pl?query=$prevQuery&lb=$prevLB'>&laquo; Back to Query</a>&nbsp;&nbsp;";
	}
}

unless(($physicalMode && @searchWords < 1) || $fileOpen || $uploadFail){
	print <<HTML;
	<a href='#' id='unhighlightSelector' onclick='toggleSearchHighlight()' style='white-space:nowrap;text-decoration:none; color:white; background-color:#000099;
HTML
	if(!$searchHighlight) { print "display:none" }
	print <<HTML;
	'>&nbsp;Highlight Search Terms&nbsp;</a>
	<a href='#' id='highlightSelector' onclick='toggleSearchHighlight()' style='white-space:nowrap;text-decoration:none;
HTML
	if($searchHighlight) { print "display:none" }
	print<<HTML;
	'>&nbsp;Highlight Search Terms&nbsp;</a>
HTML
}
else {print "<span id='highlightSelector'></span><span id='unhighlightSelector'></span>"} #prevent JS errors

if($fileOpen || $uploadFail){
	print<<HTML;
	<span style='color:006600'>AGI parse for the file: <b>$filename</b></span>
HTML
}

print<<HTML;
</td>
<td style='text-align:right'>
$resultdisplay
</td>
</tr>
</table>
</div>
<br>
<div style='clear:both; width:100%; text-align:left'>
HTML
                                                               #################
### END Top Bar Display ########################################################
                                                               #################



#Stuff to show if query fails or there is a warning ##########
if($queryFail || $queryWarning){
	print <<HTML;
	<center>
	<div style='border:2px solid #990000; padding:3px; width:500px'>
	<div style='background-color:#ffe0e0; padding:2px'>
HTML
	if($queryFail && !$physicalMode && !$uploadFail){
		print<<HTML;
		<span style='size:14px; font-weight:bold'>No Results</span><br>
		<span style='font-size:14px;'>$queryFailText</span>
HTML
	}
	elsif($uploadFail){
		print<<HTML;
		<span style='size:14px; font-weight:bold'>$uploadFailText</span><br>
HTML
	}
	elsif($queryWarning) {
		print <<HTML;
		<span style='size:13px; font-weight:bold'>$queryWarningText</span><br>
HTML
	}
	elsif($physicalMode) {
		my $prevQuery = $page->{prevQuery};
		my $prevLB = $page->{prevLB};
		print "<span style='font-size:14px;font-weight:bold'>No genes at this local prefix<br></span>";
	# 	print navigation_control($querySize, $lb, $htmlQuery, $noCheck, $referenceGene, $physicalMode);
		print "<a href='query.pl?query=$prevPrefix&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=$prevLB'>";
		print "&laquo; Prev: $prevPrefix ($prevPrefixCount)";
		print "</a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
		print "<a href='query.pl?query=$nextPrefix&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=$prevLB'>";
		print "Next: $nextPrefix ($nextPrefixCount) &raquo;";
		print "</a>";
	}

	print <<HTML;
	</div>
	</div>
	</center>
	<br>
HTML
	if($queryFail && !$physicalMode && !$fileOpen && !$uploadFail){
		print <<HTML;
		<center>
		<!--<span style='font-size:1.1em'>
		Try <a href='dbquery.pl' style='font-size:1.2em; text-decoration:none; color:#444444'>
		<span style='color:#ff3366'>Secret</span><span style='color:green'>ary</span> Database Query</a>
		 for fine-tuned search parameters
		</span>-->
		</center>
HTML
	}

}
###############################################################


#otherwise, query is successful:
if(!$queryFail){
print "\n<!--Display Results: " . join(", ", @AGIs) . "-->";
#$AGIs = array_slice($AGIs, $lb - 1, 20);
foreach my $agi(@AGIs) {
	my $gene = CXGN::Secretary::Gene->new($agi, $page, $dbh);
	$gene->fetch;
	$gene->setRelevancy($AGIscores{$agi});
	$gene->setHighlight($searchHighlight);
	$gene->setSearchWords(@searchWords);
	print $gene->queryView();
} #end tairloop


print "</div>";
print "<div style='clear:both; width:100%;";
if($physicalMode){
	print "border-top: 1px dotted purple;";
}
else {
	print "border-top: 1px dotted blue;";
}
print "background-color:white; font-size:6px'>&nbsp;</div>";
}#end if query good


if($queryFail) {
	print "<div style='float:right'><span style='text-align:right; font-size:14px'>&nbsp;</span></div>";
}
elsif($fileOpen) {
	print "<div style='float:right; font-size:14px'><b>$querySize</b> AGIs Found in File</div>";
}
else{
	print "<div style='text-align:right'>";
# 	print navigation_control($querySize, $lb, $htmlQuery, $noCheck, $referenceGene, $physicalMode);
	print "<table width='100%'><tr><td style='text-align:left'>";
	print $page->navigation_info("#bottom");
	print "</td><td style='text-align:right'>";
	print $page->navigation_control($prevPrefix, $nextPrefix, "#bottom");
	print "</td></tr></table></div>";
}


print <<HTML;
<a name='bottom'>&nbsp;</a>
<!--Preload images -->
<img src='/documents/img/secretary/hotlist_add.png' style='display:none'>
<img src='/documents/img/secretary/hotlist_remove.png' style='display:none'>
HTML

my $extra_footer=<<HTML;
<script language='javascript'>
prepareSearchHighlight();
</script>
HTML
$page->footer($extra_footer);

################# Subroutines ############################################
sub zeropadleft {
	my ($location) = @_;
	$location = int($location);

	if($location < 10) {
		return "00" . $location;
	}
	elsif($location < 100) {
		return "0" . $location;
	}
	else {
		return "" . $location;
	}
}

sub zeropadright {
	my ($location) = @_;
	$location = int($location);

	if($location < 10) {
		return $location . "00";
	}
	elsif($location < 100) {
		return $location . "0";
	}
	else {
		return $location . "";
	}
}


