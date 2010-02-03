use strict;
use CXGN::DB::Connection;
use CXGN::Page::Secretary;
use CXGN::Cookie;
use DBI;
use HTML::Entities;
use CXGN::Page::Widgets qw/swapper collapser/;


my $page = CXGN::Page::Secretary->new("Secretary", "Chris");
my $dbh = $page->{dbh};

my $query = $page->{searchQuery};
my $gene = $page->{gene};

if(!defined($gene) || !($gene =~ /AT[1-5MC]G\d{5}\.\d+/ )) {
	$page->client_redirect("index.pl");
}

my %EviDefs = %{$page->{evicode2definition}}; 
my $dbquery = $dbh->prepare("SELECT * FROM ara_evidef");
$dbquery->execute();

while (my $hashref = $dbquery->fetchrow_hashref()){
	my %hash = %$hashref;
	my $code = $hash{'code'};
	my $def = $hash{'description'};
#	$EviDefs{$code} = $def;
}

$page->header("Secretary", $gene);

my $userConfirm = $page->{userConfirm};
print <<HTML;
<table width='100%'>
<tr>
<td>
<div style="float:left">
<a href='index.pl' style='text-decoration:none'><span style='font-size: 36px;'><span style='color:#ff3366;'>Secret</span><span style='color:green'>ary</span></span></a>
</div></td>

<td valign="bottom" style='text-align:left'>
HTML

my $locus = substr($gene, 0, 9);
my $hashref;
my %hash = ();
my $content_q;
	
$dbquery = "SELECT * FROM ara_properties WHERE agi='$gene'";
$content_q = $dbh->prepare($dbquery); 
$content_q->execute();	
$hashref = $content_q->fetchrow_hashref();
%hash = %$hashref;

my $molWeight = $hash{'weight'};
$molWeight = $molWeight / 1000;
my $numTrans = $hash{'transmemcount'};
my $isoElectric = $hash{'isoelectric'};

my $numTrans = $hash{'transmemcount'};
my $transmempos = $hash{'transmempos'};
my $Genome_Position = $hash{'genomepos'};

$dbquery = "SELECT * FROM ara_annotation WHERE agi='$gene'";
$content_q = $dbh->prepare($dbquery); 
$content_q->execute();	
$hashref = $content_q->fetchrow_hashref();
%hash = %$hashref;

my $Annotation = $hash{'tair_annotation'};
my $Loc = $hash{'localization'};
my $LocEvidence = $hash{'localization_evidence'};

my $Func = $hash{'function'};
my $FuncEvidence = $hash{'function_evidence'};
my $Proc = $hash{'process'};
my $ProcEvidence = $hash{'process_evidence'};
	
my $Symbol = $hash{'symbol'};
my $Aliases = $hash{'aliases'};
my $NCBI_M = $hash{'gb_mrna_id'};

#if(strpos($NCBI_M, ".")) $NCBI = substr($NCBI_M, 0, strpos($NCBI_M, "."));

my $NCBI_P = $hash{'gb_prot_id'};
my $uniProtId = $hash{'uniprot_id'};

$dbquery = "SELECT * FROM ara_sequence WHERE agi='$gene'";
$content_q = $dbh->prepare($dbquery); 
$content_q->execute();	
$hashref = $content_q->fetchrow_hashref();
%hash = %$hashref;
	

my $fullSequence = $hash{'genomic'};
my $CDS = $hash{'cds'};
my $cDNA = $hash{'cdna'};
my $protSequence = $hash{'protein'};

my $numResidues = length($protSequence);

$dbquery = "SELECT intron_num, lbound, rbound FROM ara_intron WHERE agi=?";
$content_q = $dbh->prepare($dbquery);
$content_q->execute($gene);

my $introns = {};
my $intron_lbs = {};
my $intron_rbs = {};
my $debug = "";
while (my @row = $content_q->fetchrow_array){
	my ($intron_num, $ilb, $irb) = @row;
	$debug .= "$intron_num\t$ilb\t$irb\n";
	($introns->{$intron_num}->{lb}, $introns->{$intron_num}->{rb}) = ($ilb, $irb);
	$intron_lbs->{$ilb} = 1;
	$intron_rbs->{$irb} = 1;
}
#die $debug;

$dbquery = "SELECT length(utr5), length(utr3) FROM ara_sequence WHERE agi=?";
my $utr_q = $dbh->prepare($dbquery);
$utr_q->execute($gene);
my @row = $utr_q->fetchrow_array;
my ($utr5_len, $utr3_len) = @row;


print <<HTML;
</td>
<td>
<center><div style="text-align:right"><br>
<form action='query.pl' method="GET" name='fqtop' style="margin:0">
<input type="textbox" name='query' size=30 id='query' value='$query'>
<input type="submit" value="Search">
</form></div></center></td></tr></table>

<div class='headingBar' style='padding-left:5px;margin:0px;text-align:left;'>
	<table style='width:100%; margin:0px'><tr>
	<td style='text-align:left'>
HTML
my $show_prev_q = 0;
if($page->{prevLB} && length($page->{searchQuery}) > 0 && $page->{prevLB} =~ /^\d+$/ && $page->{prevLB} > 0){
	$show_prev_q = 1;	
	print "<a href='query.pl?query=$page->{searchQuery}&lb=$page->{prevLB}'>&laquo; Back to Query</a>&nbsp;&nbsp;";
}

print <<HTML;
	<span style='font-size:1.10em; color:black'><b>$gene</b></span>&nbsp;&nbsp;
HTML


print $page->hotlist_button($gene);
print<<HTML;
</td>
	<td style='text-align:right'>
HTML
if($show_prev_q) {
	print "<a href='query.pl?query=$page->{searchQuery}&lb=$page->{prevLB}'>&laquo; Back to Query</a>&nbsp;&nbsp;";
}
print<<HTML;
	<span style='font-size:1.10em; color:black'><b>$gene</b></span>
	</td>
</tr></table></div>
HTML




my @hashIDs = ("Loc", "LocEvidence", "Proc", "ProcEvidence", "Func", "FuncEvidence");
my @GO_text = ($Loc, $LocEvidence, $Proc, $ProcEvidence, $Func, $FuncEvidence);
my %GO_annot = ();  # hash of arrays containing separate entries for GO types

my $buffer = "";
my $i = 0;
my $item = "";

while($i<6) {
	$buffer = $GO_text[$i];
	my @array = ();
	while($buffer) {
		if($buffer =~ /::/) { 
			($item) = $buffer =~ /(.+?)::/;
			push(@array, $item);
			$buffer =~ s/(.+?):://;
		}
		else {
			push(@array, $buffer);
			$buffer = '';
		}
	}
	foreach (@array) {
		print "\n<!-- GO: $_ -->";
	}
	$GO_annot{$hashIDs[$i]} = [@array];
	
	if( $i % 2 ) { #evidence definition
		my @array = ();
		if(defined($GO_annot{$hashIDs[$i]})){
			@array = @{$GO_annot{$hashIDs[$i]}};
		}
		foreach (@array) {
			if(/PMID/) {
				my ($code) = /(\S+)-PMID/;
				my ($PMID) = /PMID:(\d+)/;	
				my $link = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$PMID&query_hl=5&itool=pubmed_docsum";
				$_ = $EviDefs{$code} . " <a class='external' href='$link'>PubMed</a>";
			}
			else {
				$_ = $EviDefs{$_};
			}
		}
		$GO_annot{$hashIDs[$i]} = [ @array ];
	}
	$i++;
}



my $targetp_q = $dbh->prepare("SELECT * FROM ara_targetp WHERE agi=?");
$targetp_q->execute($gene);

my ($Location, $CScore, $SScore, $MScore, $OScore, $RC);
my ($primary, $alternate);
my %scorehash = ();
my @sorter = ();

if(my $ref = $targetp_q->fetchrow_hashref()) {
	my %hash = %$ref;
	$Location = $hash{'location'};
	$CScore = $hash{'c_score'};
	$SScore = $hash{'s_score'};
	$MScore = $hash{'m_score'};
	$OScore = $hash{'o_score'};
	$RC = $hash{'rc'};
	$scorehash{$CScore} = 'the chloroplast'; 
	$scorehash{$SScore} = 'the secretory pathway'; 
	$scorehash{$MScore} = 'the mitochondrion'; 
	$scorehash{$OScore} = 'another structure';	
	@sorter = ($CScore, $SScore, $MScore, $OScore);
	@sorter = sort { $b <=> $a } @sorter;
	$primary = $scorehash{$sorter[0]};
	shift @sorter;
	$alternate = $scorehash{$sorter[0]};
}


my $signalp_q = $dbh->prepare("SELECT * FROM ara_signalp WHERE agi=?");
$signalp_q->execute($gene);
my ($NNDQ, $NNscore, $Ypos, $cleavageString);

if(my $ref = $signalp_q->fetchrow_hashref()) {
	my %hash = %$ref;
	$NNDQ = $hash{'nn_d'};
	$NNscore = $hash{'nn_score'};
	$Ypos = $hash{'nn_ypos'};

	my $pseqlength = length($protSequence);

	$cleavageString = substr($protSequence, max($Ypos-4, 0), min(3, $Ypos-1)) . "-" . substr($protSequence, $Ypos-1, min(3, $pseqlength - $Ypos + 1));
}


my $evi = $GO_annot{'LocEvidence'}[0];  #ex:  "inferred from electronic annotation" => "electronic annotation"

if($evi =~  /from/) {
	$evi =~ s/.*from //;
}
elsif($evi =~ /by/) {
	$evi =~ s/.*by //; 
}

if($evi =~ /<a/i){
	$evi =~ s/(.*) <a/<b>$1<\/b> <a/i;
}
else{
	$evi = '<b>' . $evi . '</b>';
}

# if (sizeof(array_unique($LocEvi_array))==1 && sizeof(array_unique($Loc_array))>1){
# 	$loc = implode(" or ", array_unique($Loc_array));
# }
# else $loc = $Loc_array[0];

my $loc = $GO_annot{'Loc'}[0];

if ($loc =~ /intrinsic to/) {
	$loc =~ s/intrinsic to //;
}

if ($loc =~ /intracellular/) {
	$loc =~ s/intracellular/intracellular region/g;
}


####
#### Presentation of Gene Information ################################################################################
####


### Store segments of page into variables ################
##########################################################

my $protein_info_color = "white";

my $proteinBox =<<HTML;
<div style='padding:2px;'>
HTML

my @locArray = @GO_annot{'Loc'};
my $proteinInfo = "<span style='font-size:1.0em'>";
if(@GO_annot{'Loc'} <1 || $evi =~ /No biological data available/i) {
	$proteinInfo .= "No annotation regarding localization is available for this protein.<br>";
}
else {
	$proteinInfo .= "This protein is thought to localize in the <span style='white-space:nowrap'><b>" . $loc . "</b></span>";
	$proteinInfo .= ", which is supported by <span style='white-space:nowrap'>$evi</span><br>";
}
$proteinInfo .= "</span>";

$proteinInfo .= "<table style='text-align:center'><tr><td width='50%' style='vertical-align:top; background-color:#eee'>";
$proteinInfo .= "<div style='padding-left:4px;margin-top:4px;text-align:center;font-size:1.05em;background-color:#eee;color:black'>";
$proteinInfo .= "<b style='color:#b60'>TargetP</b> - ";

my $CScoreText = sprintf("%.3f", $CScore);
my $MScoreText = sprintf("%.3f", $MScore);
my $SScoreText = sprintf("%.3f", $SScore);
my $OScoreText = sprintf("%.3f", $OScore);

if(!$CScore) {
	$proteinInfo .= "prediction not available</div>";
}
else{
	if($Location ne '_') {
		$proteinInfo .= "predicted localization in";
		my $locText = "";
		if($Location eq 'M') {
			$locText = "mitochondrion";
			$MScoreText = "<b>" . $MScoreText . "</b>";
		}
		elsif($Location eq 'C') {
			$locText = "chloroplast";
			$CScoreText = "<b>" . $CScoreText . "</b>";
		}
		elsif($Location eq 'S') {
			$locText = "secretory pathway";
			$SScoreText = "<b>" . $SScoreText . "</b>";
		}
		$proteinInfo .= " the <b style='color:#b60'>$locText</b>";
	}
	else {
		$OScoreText = "<b>" . $OScoreText . "</b>";
		$proteinInfo .= "<b>unknown</b> localization";
	}


	$proteinInfo .= "</div>";
	if($RC>2) {$proteinInfo .= "Given a reliability class of <b>$RC</b>";}
	else { $proteinInfo .= "Reliability class: <b>$RC</b>";}
	if($RC==1) {$proteinInfo .= " (best)"}
	elsif($RC==2) {$proteinInfo .= " (good)"}
	elsif($RC==3) {$proteinInfo .= " (fair)"}
	elsif($RC==4) {$proteinInfo .= " (poor)"}
	else {$proteinInfo .= " (worst)"}

	if($RC>2) {$proteinInfo .= ", the protein may also localize in <b>$alternate</b><br>"}
		
	$proteinInfo .= <<HTML
<center>
<table width='70%' style='font-size:1.0em; text-align:center'>
<tr>
	<td style='width:156px'>Chloroplast</td>
	<td style='width:156px'>Mitochondrion</td>
	<td style='width:156px'>Secretory</td>
	<td style='width:156px'>Other</td></tr>
<tr><td>$CScoreText</td><td>$MScoreText</td><td>$SScoreText</td><td>$OScoreText</td></tr>
</table>
</center>
HTML

}
	$proteinInfo .= "</td><td width='50%' style='vertical-align:top;background-color:#eee;'>";
my $NNscoreText = sprintf("%.3f", $NNscore);
$proteinInfo .= "<div style='padding-left:4px;margin-top:4px;text-align:center;font-size:1.05em;background-color:#eee;color:black'>";
$proteinInfo .= "<b style='color:#3a3'>SignalP</b> - ";
if($NNDQ eq 'Y'){ 
	$proteinInfo .= "predicted <b style='color:#3a3'>secretion</b>"; 
	$proteinInfo .= "</div>";
	$proteinInfo .= "With a decision score of <b>$NNscoreText</b>, ";
	$proteinInfo .= "the most likely cleavage point is at positions <b>" . ($Ypos-1) . "-" . ($Ypos) . "</b>: $cleavageString";  
}
else {
	$proteinInfo .= "predicted <b>non-secretion</b>"; 
	$proteinInfo .= "</div>";
	$proteinInfo .= "Decision score: <b>$NNscoreText</b>";
}
	$proteinInfo .= "</td></tr></table>";

my ($link, $content) = collapser({ linktext=> "Proteomic Info", linkstyle=> "font-weight:bold; font-size:1.1em; text-decoration:none; color:white", 
									content => $proteinInfo, id=>"proteinInfoCollapse", save=>1 });

$proteinBox .= <<HTML;
<div style='background-color:#615; padding:2px; border-bottom:2px solid #a48'>$link</div>$content
</div>
HTML





my $aliasesInfo = "";
$Aliases = "None" if(!$Aliases);
$aliasesInfo .= <<HTML;
<div style='width:100%; text-align:left'>
<table width='100%'><tr>
<td style='width:50%; text-align:left;'>
<span style='font-size:1.1em; font-weight:bold'>
HTML
	$aliasesInfo .= "<span style='color:#990000'>Aliases:</span> $Aliases";
	$aliasesInfo .= "</span>";
$aliasesInfo.=<<HTML;
</td>
<td style='text-align:left'>
<b style='color:#393955'>External Links:</b>&nbsp;&nbsp;&nbsp;
		<a class = 'external' href='http://www.arabidopsis.org/servlets/TairObject?type=gene&name=$gene'>TAIR</a>&nbsp;&nbsp;
			<a class = 'external' href='http://www.tigr.org/tigr-scripts/euk_manatee/shared/ORF_infopage.cgi?db=ath1&orf=$locus'>TIGR</a>&nbsp;&nbsp;
			<a class = 'external' href='http://mips.gsf.de/cgi-bin/proj/thal/search_gene?code=$locus'>MIPS</a>&nbsp;&nbsp;
			<a class = 'external' href='http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=nucleotide&val=$NCBI_P'>GenBank</a>&nbsp;&nbsp; 
HTML

if($uniProtId) { $aliasesInfo .= "<a class = 'external' href='http://www.pir.uniprot.org/cgi-bin/upEntry?id=$uniProtId'>UniProt</a>";}
$aliasesInfo .= "</td></tr></table></div>";


my $properties_color = "#448";
my $propertiesBox = <<HTML;
	<div style='padding-top:2px;font-size:1em'>
HTML

my $label_style = "width:22%;text-align:left;font-weight:bold;font-size:0.8em";
my $value_style = "width:22%;text-align:right;font-weight:bold;font-size:0.8em";

my $propertiesInfo = <<HTML;
<center>
				<table width='100%' style='font-size:1em; text-align:left; padding:1px'>
					<tr style='color:black;'>
						<td style='$label_style'>Molecular Weight:</td>
						<td style='$value_style'>$molWeight kDa</td>
						<td style='width:12%'>&nbsp;</td>
						<td style='$label_style'>Number of Residues:</td>
						<td style='$value_style'>$numResidues</td>
					</tr>
					<tr style='color:#550055;'>
						<td style='$label_style'>Number of Predicted Transmembrane Domains:</td>
						<td style='$value_style'>$numTrans</td>
						<td style='width:12%'>&nbsp;</td>
						<td style='$label_style'>Isoelectric Point:</td>
						<td style='$value_style'>$isoElectric</td>
					</tr>
				</table>
</center>
HTML

my ($link, $content) = collapser({ linktext => "Properties", linkstyle=>"color:white; font-weight:bold; text-decoration:none; font-size:1.1em;",	
									content => $propertiesInfo, id=>"propertiesCollapse", save => 1 });	

$propertiesBox .= "<div style='padding:2px; background-color:#448; border-bottom:2px solid #779; color:white'>$link</div>$content</div>";


my $go_color = "#44aa44";
my $goBox = "<div style='padding:2px;text-align:left'>\n";

my $goInfo = "";
#Insert Function and Process info here:
if(defined $GO_annot{'Loc'} && @{$GO_annot{'Loc'}} > 0) {
	$goInfo .= <<HTML;
			<b style="font-size:0.9em">Localization</b>
		<table style='width:100%;text-align:left'>
HTML
	my $j = 0;
	while ($j < @{$GO_annot{'Loc'}}) {
		$goInfo .=  "<tr><td width='100%' style='font-size:1.0em'><li>";	
		$goInfo .=  ucfirst($GO_annot{'Loc'}[$j]) . " (<em>$GO_annot{'LocEvidence'}[$j]</em>)";
		$goInfo .=  "</td></tr>";	
		$j++;
	}
	$goInfo .=  "</table>";
}

if(defined $GO_annot{'Func'} && @{$GO_annot{'Func'}} > 0) {
	$goInfo .= <<HTML;
			<b style="font-size:0.9em">Function</b>
		<table style='width:100%;text-align:left'style='text-align:left'>
HTML
	my $j = 0;
	while ($j < @{$GO_annot{'Func'}}) {
		$goInfo .=  "<tr><td width='100%' style='font-size:1.0em'><li>";	
		$goInfo .=  ucfirst($GO_annot{'Func'}[$j]) . " (<em>$GO_annot{'FuncEvidence'}[$j]</em>)";
		$goInfo .=  "</td></tr>";	
		$j++;
	}
	$goInfo .=  "</table>";
}


if(defined $GO_annot{'Proc'} && @{$GO_annot{'Proc'}} > 0) {
	$goInfo .= <<HTML;
			<b style="font-size:0.9em">Process</b>
		<table style='width:100%;text-align:left'>
HTML
	my $j = 0;
	while ($j < @{$GO_annot{'Proc'}}) {
		$goInfo .=  "<tr><td width='100%' style='font-size:1.0em'><li>";	
		$goInfo .=  ucfirst($GO_annot{'Proc'}[$j]) . " (<em>$GO_annot{'ProcEvidence'}[$j]</em>)";
		$goInfo .=  "</td></tr>";	
		$j++;
	}
	$goInfo .=  "</table>";
}
my ($link, $content) = collapser({ 	linktext => "Gene Ontologies", 
									linkstyle => "text-decoration:none; color:white",
									content => $goInfo, 
									id => "GOcollapse", 
									save => 1  });
$goBox .= "<div style='font-size:1.1em; padding:2px; font-weight:bold; background-color:#4a4; text-align:center; border-bottom:2px solid #5b5'>$link</div>$content";
$goBox.= "</div>";


$Annotation = ucfirst($Annotation);
$Annotation =~ s/GB:(\w+(\.\d+)?)/<a class='external' href='http:\/\/www.ncbi.nlm.nih.gov\/entrez\/query.fcgi?db=Protein&cmd=search&term=$1'>GB:$1<\/a>/ig;
$Annotation =~ s/GI:\s*(\d+)/<a class='external' href='http:\/\/www.ncbi.nlm.nih.gov\/entrez\/viewer.fcgi?db=protein&val=$1'>GI:$1<\/a>/ig;
$Annotation =~ s/TAIR:([\w.]+)/<a class='external' href='http:\/\/www.arabidopsis.org\/servlets\/TairObject?type=gene&name=$1'>TAIR:$1<\/a>/gi;
$Annotation =~ s/InterPro:(\w+)/<a class='external' href='http:\/\/www.ebi.ac.uk\/interpro\/DisplayIproEntry?ac=$1'>InterPro:$1<\/a>/gi;

$Annotation =~ s/SP:(\w+)/<a class='external' href='http:\/\/ca.expasy.org\/uniprot\/$1'>SP:$1<\/a>/gi;


my ($link, $content) = collapser({ 	linktext => "TAIR Annotation", 
									linkstyle => "text-decoration:none; font-weight:bold; font-size:1.1em; color:black",
									content => $Annotation, 
									id => "TAIRannotationCollapse", 
									save=>1 	});

my $annotationBox = <<HTML;
		<div style='padding:2px;'>
			<div style='padding:2px; background-color:#ee9; border-bottom:2px solid #996'>$link</div>$content
		</div>
HTML




my $protSeqInfo = <<HTML;
<div style='text-align:left;'>
<span style='font-size:20px; color:#4444AA'>
	Protein Sequence
</span> &nbsp;&nbsp;&nbsp;
<a class='external' href='http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Put&QUERY=$protSequence&DATABASE=nr&PROGRAM=blastp&FILTER=L&HITLIST_SZE=500'>
	Perform BLASTP
</a> &nbsp;&nbsp;
<span style='white-space:nowrap' id='selectedblastp'>&nbsp;</span>
<div style='padding:5px; overflow:auto; border: 2px solid #4444aa; 
			font-family:courier, monospace; 
			background-color:white;'
	onmouseup='var protseq = getSel(); if(protseq) selectedblastp(protseq);'>
HTML

if($NNDQ eq 'Y') {
	if($NNscore<0.5) {$protSeqInfo .=  "Unlikely "}
	elsif($NNscore<0.6) {$protSeqInfo .=  "Somewhat likely "}
	elsif($NNscore<0.8) {$protSeqInfo .=  "Likely "}
	else {$protSeqInfo .=  "Very likely "}
	$protSeqInfo .=  "secretory signal sequence highlighted in <span style='color:green'>green</span><br>";
}

$protSeqInfo .=  "&gt;$gene (" . length($protSequence) . " aa)<br>";
$buffer = $protSequence;
my $line=1;
my $lbpos = 1;
while(my $seqline = substr($buffer, 0, 4)){
	if($NNDQ eq 'Y' && $lbpos < $Ypos) {
		$protSeqInfo .=  "<span style='color:green'>" . substr($seqline, 0, min($Ypos-$lbpos, 4)) . "</span>" . substr($seqline, min($Ypos-$lbpos, 4)); 
	}
	else {
		$protSeqInfo .=  $seqline . "<wbr></wbr>";
	}
	$buffer = substr($buffer, 4);
	$line++;
	$lbpos += 4;
}

$protSeqInfo .=  <<HTML;
</div>
</div>
HTML

my $cdsSeqInfo = <<HTML;
<div style='text-align:left;'>
<span style='font-size:20px; color:#44aa44'>Coding Sequence</span> 
&nbsp;&nbsp;&nbsp;&nbsp;
<a class = 'external' href='http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Put&QUERY=$CDS&DATABASE=nr&PROGRAM=blastn&FILTER=L&HITLIST_SZE=500'>Perform BLASTN</a>
 &nbsp;&nbsp;
<span style='white-space:nowrap' id='selectedblastncds'>&nbsp;</span>
<div style='padding:5px; 
			overflow:auto; border: 2px solid #44aa44; 
			font-family:courier, monospace; 
			background-color:white;' 
			onmouseup='var cdsseq = getSel(); if(cdsseq) selectedblastncds(cdsseq);'>
HTML

$cdsSeqInfo .=  "&gt;$gene (". length($CDS) . " bp)<br>";
$buffer = $CDS;
while(my $seqline = substr($buffer, 0, 4)){
	$cdsSeqInfo .=  $seqline . "<wbr></wbr>";
	$buffer = substr($buffer, 4);
}

$cdsSeqInfo .=  <<HTML;
</div>
</div>
HTML


###########################################################################################################
### Sequence Info ############################## Sequence Info ############################################
###########################################################################################################

my $seq_color = "#cf9";
my $seq_color_shade = "#9a7";


my $seqInfo = "<div style='text-align:left; border:0px solid $seq_color'>";

my $buttonStyle = 'color:black; text-decoration:none';

my $protSeqDisp =  "&gt;$gene (" . length($protSequence) . " aa)<br>";
$buffer = $protSequence;
my $line=1;
my $lbpos = 1;
while(my $seqline = substr($buffer, 0, 4)){
	if($NNDQ eq 'Y' && $lbpos < $Ypos) {
		$protSeqDisp .=  "<span style='color:green'>" . substr($seqline, 0, min($Ypos-$lbpos, 4)) . "</span>" . substr($seqline, min($Ypos-$lbpos, 4)); 
	}
	else {
		$protSeqDisp .=  $seqline . "<wbr></wbr>";
	}
	$buffer = substr($buffer, 4);
	$line++;
	$lbpos += 4;
}

my ($button, $content) = collapser({ linktext => 'Protein Sequence', 
									 linkstyle => $buttonStyle, 
									 content => $protSeqDisp, 
									 id => 'protSeqDisp',
									 save => 1
								   });


$seqInfo .= "<div style='padding:2px; background-color:$seq_color; border-bottom:2px solid $seq_color_shade; text-align:center; font-weight:bold; font-size:1.15em'>$button</div>";
$seqInfo .= "<div style='padding:2px; font-family:mono'>$content</div>";
$seqInfo .= "<div style='padding:2px;'></div>";

$buffer = $CDS;
my $nonSpacedSequence = "";
while(my $seqline = substr($buffer, 0, 3)){
	$nonSpacedSequence .=  $seqline . "<wbr></wbr>";
	$buffer = substr($buffer, 3);
}
$buffer = $CDS;
my $SpacedSequence = "";
while(my $seqline = substr($buffer, 0, 3)){
	$SpacedSequence .=  $seqline . "&nbsp;<wbr></wbr>";
	$buffer = substr($buffer, 3);
}
my ($button, $content) = swapper({	linktext => "(-)Hide Spaces", 
									linktext_alt => "(+)Show Spaces", 
									linkstyle => "text-decoration:none", 
									content=> $SpacedSequence, 
									content_alt => $nonSpacedSequence, 
									id=>'cdsSpaceSwap'
								});
my $cdsSeqDisp =  "$button<br>&gt;$gene (". length($CDS) . " bp)<br>$content";

my ($button, $content) = collapser({ linktext => 'Coding Sequence', 
									 linkstyle => $buttonStyle, 
									 content => $cdsSeqDisp, 
									 id => 'cdsSeqDisp',
									 save => 1
								   });

$seqInfo .= "<div style='padding:2px;background-color:$seq_color; border-bottom:2px solid $seq_color_shade; text-align:center; font-weight:bold; font-size:1.15em'>$button</div>";
$seqInfo .= "<div style='padding:2px;font-family:mono'>$content</div>";
$seqInfo .= "<div style='padding:2px;'></div>";

##Genomic Sequence Display:
my $genomicSeqDisp = "";

$genomicSeqDisp .= "&gt;$gene (" . length($fullSequence) . " bp)<br>";

#utr5_len, utr3_len
my $htmlSeq = "";
my $within_intron = 0;
my $iter = 1;
my $non_intron_iter = 1;
while($iter <= length($fullSequence)){
	if($non_intron_iter == 1){
		$htmlSeq .= "<span style=\"color:#779\">";
	}
	if($non_intron_iter == (length($cDNA)-$utr3_len+1)){
		$htmlSeq .= "<span style=\"color:#779\">";
	}	
	if($non_intron_iter == ($utr5_len + 1)){
		$htmlSeq .= "</span>";
	}
	if($intron_lbs->{$iter}){
		$htmlSeq .= "<span style='color:#933'>";
		$within_intron = 1;
	}

	#Add the Base:
	$htmlSeq .= substr($fullSequence, $iter-1, 1);
	
	unless($within_intron){
		$non_intron_iter++;
	}
	if($intron_rbs->{$iter}){
		$htmlSeq .= "</span>";
		$within_intron = 0;
	}
	if($iter == length($fullSequence)){
		$htmlSeq .= "</span>"; #end 3utr
	}
	
	if($iter%3==0) { $htmlSeq .= "<wbr></wbr>";}
	$iter++;
}
$genomicSeqDisp .= $htmlSeq;
$genomicSeqDisp .= "<br /><br />";
if($introns->{1}){  #if there's at least one intron...
	$genomicSeqDisp .=  "<span style='color:#933'>Intron</span>,&nbsp;&nbsp;";
}
$genomicSeqDisp .= "<span style=\"color:#779\">UTR</span><br />";

my ($button, $content) = collapser({ linktext => 'Genomic Sequence', 
									 linkstyle => $buttonStyle, 
									 content => $genomicSeqDisp, 
									 id => 'genomicSeqDisp',
									 save => 1
								   });

$seqInfo .= "<div style='padding:2px; background-color:$seq_color; border-bottom:2px solid $seq_color_shade; text-align:center; font-weight:bold; font-size:1.15em'>$button</div>";
$seqInfo .= "<div style='padding:2px;font-family:mono;'>$content</div>";
$seqInfo .= "<div style='padding:2px;'></div>";

$seqInfo .= "</div>";

#
###############################################################################################



my $fullSeqInfo .= <<HTML;
<div style='text-align:left;'>
	<span style='font-size:20px; color:#aa4444'>
		Genomic Sequence
	</span> &nbsp;&nbsp;&nbsp;&nbsp;
	<a class='external'
		href='http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Put&QUERY=$fullSequence&DATABASE=nr&PROGRAM=blastn&FILTER=L&HITLIST_SZE=500'>
		Peform BLASTN</a>&nbsp;&nbsp;
	<span style='white-space:nowrap' id='selectedblastnfull'>&nbsp;</span>
	
	<div style='padding:5px; overflow:auto; 
				border: 2px solid #aa4444; 
				font-family:courier, monospace; 
				background-color:white' 
				onmouseup='var fullseq = getSel(); if(fullseq) selectedblastnfull(fullseq);'>
HTML
$fullSeqInfo .=  "&gt;$gene (" . length($fullSequence) . " bp)<br>";
$buffer = $fullSequence;
while(my $seqline = substr($buffer, 0, 4)){
	$fullSeqInfo .=  $seqline . "<wbr></wbr>";
	$buffer = substr($buffer, 4);
}
$fullSeqInfo .= <<HTML;
</div>
</div>
HTML



## DISPLAY content variables ################################################
#############################################################################

print "<center><div style='width:80%;'>";
print "<div style='height:6px'>&nbsp;</div>";
print $aliasesInfo;
print "<br>";
print $proteinBox;
print "<br>";
print $annotationBox;
print "<br>";
print $goBox;
print "<br>";
print $propertiesBox;
print "<br>";
# print $protSeqInfo;
# print "<br>";
# print $cdsSeqInfo;
# print "<br>";
# print $fullSeqInfo;
# print "<br><br>";
print $seqInfo;
print "</div></center>";
print "<div style='height:500px'>&nbsp;</div>";
$page->footer();

################ Subroutines ###################################################################
sub max {
	my $max = shift;
	foreach(@_) { $max = $_ if $_ > $max }
	return $max;
}
sub min {
	my $min = shift;
	foreach(@_) { $min = $_ if $_ < $min }
	return $min;
}
