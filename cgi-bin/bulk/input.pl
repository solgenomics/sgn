=head1 NAME

  /bulk/input.pl

=head1 DESCRIPTION

  This perl script is used on the bulk download page. It structures the tabs on
  the main download page and determines the mode of each tab, as well as what
  information fields are available in each mode. It does this by accepting the
  mode parameter and displaying its corresponding input form. Legal values for
  mode are clone_search, array_search, unigene_search, bac_search,
  bac_end_search, unigene_convert and ftp. Other values have undefined results but will
  probably default to clone_search.It also accepts a debug parameter, which when
  set to 1 will add a 'print debug info' checkbox to the input forms. This
  parameter will be used by download.pl to display debug information.

=cut

# Author: Lukas Mueller
# modified by Caroline N. Nyenke (intern)

# Modified June 27th, 2007 by Alexander Naydich and Matthew Crumb (interns)


use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel simple_selectbox_html/;
use CXGN::DB::Connection;

our $page = CXGN::Page->new( "Bulk download", "Lukas Mueller, Caroline Nyenke, Rob Buels");
my $db = CXGN::DB::Connection->new();

my ($mode, $debug) = $page->get_arguments(qw/mode debug/); #determine mode and whether debug is on

$page->header("Bulk download",'Bulk download'); #print page header and text below
print <<EOH;
<div style="margin-bottom: 1em">Download Unigene or BAC information using a list of identifiers, or complete datasets with FTP.</div>
EOH

# create tab categories
my @mode_funcs = (\&clone_search,
		  \&array_search,
		  \&unigene_search,
		  \&bac_search,
		  \&bac_end_search,
		  \&ftp_site,
                  \&unigene_convert,
		 );

# define urls of modes
my @mode_links = (
		  ['?mode=clone_search','Clone&nbsp;name<br />(SGN-C)'],
		  ['?mode=microarray','Array&nbsp;spot&nbsp;ID<br />(SGN-S)'],
		  ['?mode=unigene','Unigene&nbsp;ID<br />(SGN-U)'],
		  ['?mode=bac','BACs'],
		  ['?mode=bac_end','BAC&nbsp;ends'],
		  ['?mode=ftp','Full&nbsp;datasets<br />(FTP)'],
                  ['?mode=unigene_convert','Unigene ID Converter<br />(SGN-U)'],
		 );

### figure out which mode we're in ###
my $modenum =
      $mode =~ /clone_search/i    ? 0 :
      $mode =~ /array/i           ? 1 :
      $mode =~ /unigene_convert/i ? 6 :
      $mode =~ /unigene/i         ? 2 :
      $mode =~ /bac_end/i         ? 4 :
      $mode =~ /bac/i             ? 3 :
      $mode =~ /ftp/i             ? 5 :
                                    0; #clone search is default


### print out the mode selection buttons at the top of the page ###
### prints out all @mode_links buttons, highlighting the current selected one###
print modesel(\@mode_links,$modenum);
print qq|<div class="indentedcontent">\n|;

### call the appropriate function from the $mode_funcs list to print###
### out the download form, passing the $page object                      ###
$mode_funcs[$modenum]($page,$db,$debug);

print <<EOH;
</div>
        <i><b>Note:</b> The SGN bulk download is limited to 10,000 identifiers per request.  If you need more, please either split your query into multiple parts, download a full dataset from the FTP site, or <a href="mailto:sgn-feedback\@sgn.cornell.edu">email us</a> and we will be happy to generate a custom dataset for you.</i>
EOH
$page->footer();

###end of webpage###

=head2 DEBUG

  Desc: sub DEBUG
  Args: string;
  Ret : n/a

  Print debug information fed to it by download.pl when set to 1. (see also
  debug() in download.pl).

=cut

#one parameter: a string to print, or not, as desired
sub DEBUG
{
	print shift(@_);
}


sub ug_build_selectbox {
  my ($db,$filter_sub) = @_;
  my %builds;
  my $sth =$db->prepare(q|SELECT 	ub.unigene_build_id,
					ub.organism_group_id,
					ub.build_nr,
					g.group_id,
					g.comment
				FROM	sgn.unigene_build as ub, sgn.groups as g
				WHERE 	ub.organism_group_id=g.group_id
				  AND 	g.type=1
				  AND 	ub.status='C'
			 |);
  $sth->execute();
  while (my @row = $sth -> fetchrow_array()) {
    if($filter_sub) {
      next unless $filter_sub->(@row);
    }

    my ($unigene_build_id, $organism_group_id, $build_nr, $group_id, $species) = @row;
    $species =~ s/(\S)[a-z]+\s([a-z]+)/uc($1).'. '.$2/ei; #< abbreviate the species names
    $builds{$unigene_build_id} = "$species (build $build_nr)"; 
  }

  return simple_selectbox_html( name => 'build_id',
				label => 'Only include unigene build:',
				choices => [ [all => 'include all'],
					     (map [$_,$builds{$_}], keys %builds),
					   ],
			      );

}

=head2 clone_search

  Desc: sub clone_search
  Args: n/a
  Ret : clone tab format

  Defines the format of the clone tab using html, perl and perl dbi. Speicfies
  information fields available for searching clones. Also, this and all other
  tabs print the debug checkbox when debug parameter is set to one.

=cut

sub clone_search {

	# displays the clone search input form
	#
	my ($page, $db, $debug) = @_;

	my $content="";
	my $ug_build_select = ug_build_selectbox($db);
	print <<HTML;
<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

$ug_build_select
<br />

Enter a list of identifiers or upload a file containing identifers, one per line:<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>Example:</i> #example box
<pre style="border: 1px solid gray; width: 10em; height: 5em">
cLEB-1-A2
cLEB-1-A3
cLEB-1-A4
</pre>
</td></tr></table>

<br />
<br />
And/or upload list file: <br /><input type="file" name="file" />
<br />
<br />

HTML

	print qq|</td><td valign="top" bgcolor="#EEEEEE" width="320">\n|;
	output_list(); #print out checkboxes

	print <<HTML;

</td></tr></table>

HTML


	if ($debug eq "1") {
		print qq|<input type="checkbox" checked="checked" name="debug" /> print debug statements<br /><br />\n|;
	}

	print <<HTML;

	<input type="hidden" name="idType" value="clone" />
	<input type="reset" />&nbsp;&nbsp;
        <input type="submit" value="Submit" /><br />
   </form>

HTML

}

=head2 array_search

  Desc: sub array_search
  Args: n/a
  Ret : array tab format

  Defines the format of the array tab using html, perl and perl dbi. Specifies
  information fields available for searching microarrays. Prints the debug
  checkbox when debug parameter is set to one.

=cut

sub array_search {
	#
	# displays the array search input form
	#
	my ($page, $db, $debug) = @_;

	my $content = "";

	$page = CXGN::Page->new( "Bulk download", "Lukas Mueller");

	my $ug_select = ug_build_selectbox($db,sub {($_[4] =~ /lycopersicon|tomato/i && $_[4] !~ /demethylated/i) ? 1 : 0});
	print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">
<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

$ug_select
<br /><br />
	<br />
Enter a list of identifiers or upload a file containing one identifier:<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>Example:</i>
<pre style="border: 1px solid gray; width: 10em; height: 5em">
1-1-1.2.3.4
1-1-1.2.4.5
1-1-1.5.3.6
</pre>
</td></tr></table>
<br />
<br />
And/or upload list file: <br /><input type="file" name="file" />
<br />
<br />

 </td><td valign="top" bgcolor="#EEEEEE" width="320">

HTML

	output_list();


	print "</td></tr></table>\n";


	if ($debug eq "1") {
		print qq|<input type="checkbox" checked="checked" name="debug" /> print debug statements<br /><br />\n|;
	}

	print <<HTML

<input type="hidden" name="idType" value="microarray" />
	<input type="reset" />&nbsp;&nbsp;
<input type="submit" value="Submit" /><br />
</form>

HTML

	;

}

=head2 unigene_search

  Desc: sub unigene_search
  Args: n/a
  Ret : unigene tab format

  Defines the format of the unigene tab using html, perl and perl dbi. Speicfies
  information fields available for searching unigenes. Prints the debug
  checkbox when debug parameter is set to one.

=cut

sub unigene_search {
	#
	# displays the unigene input form
	#
	# Note: the unigene input form does not display the drop down of unigene builds, because a unigene ID is by definition mapped to a
	# given build.
	#
	# This form supports to different types of unigene queries: getting information pertaining to unigenes themselves (annotations and seq)
	# and unigene membership information. The two queries are distinguished by the unigene_mode radio control. Some adjustments have to
	# be made in the download.pl program when distinguishing the two modes.
	#
	my ($page, $db, $debug) = @_;

	my $content="";
	my $ug_select = ug_build_selectbox($db);

	print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

HTML

	;



	print <<HTML1

<br />
Enter a list of identifiers or upload a file containing one identifer separated by whitespace (returns, spaces or tabs):<br />


<table summary="" width="100%" cellpadding="0"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>Example:</i>
<pre style="border: 1px solid gray; width: 10em; height: 5em">
SGN-U268057
SGN-U562661
SGN-U196026
</pre>
</td></tr></table>
<br />
<br />

And/or upload list file: <br /><input type="file" name="file" />
<br />
<br />

</td><td valign="top" bgcolor="#EEEEEE" width="320">

 <input type="checkbox" name="convert_to_current" checked="checked" /><label for="convert_to_current"><a class="stealth" title="Check this box to convert each unigene in the list to its equivalent in the most current corresponding unigene build(s), if available"><img src="/documents/img/new.gif" />convert unigene list to current build</a></label>

 <hr />

<input type="radio" name="unigene_mode" value="unigene_info" checked="checked" /> <b>Download unigene information</b>:<br />
<!-- SGN_U for Unigene Info -->
<div style="padding-left: 1em">
    <input type="checkbox" name="SGN_U_U" checked="checked" /> unigene id (SGN-U)<br />
    <input type="checkbox" name="automatic_annotation" checked="checked" /> automatic (BLAST) annotation<br />
    <input type="checkbox" name="best_genbank_match" checked="checked" /> best genbank match<br />
    <input type="checkbox" name="best_arabidopsis_match" checked="checked" /> best arabidopsis match<br />
    <input type="checkbox" name="associated_loci" checked="checked" /> associated loci<br />
    <input type="checkbox" name = "uni_seq" checked="checked" onclick="check_fasta_option()"/> sequence<br />
    <div style="padding-left: 1em">
         <input type="radio" name="seq_mode" value="unigene_seq" checked="checked" /> unigene nucleotide sequence<br />
         <input type="radio" name="seq_mode" value="estscan_seq" /> estscan predicted proteins<br />
         <input type="radio" name="seq_mode" value="longest6frame_seq" /> longest 6 frame translation<br />
         <input type="radio" name="seq_mode" value="preferred_protein_seq" /> preferred sequence<br />
    </div>
</div>

<input type="radio" name="unigene_mode" value="member_info" /> <b>Download member information</b>:
<div style="padding-left: 1em">
    <input type="checkbox" name="clone_name" checked="checked" /> clone name<br />
    <input type="checkbox" name="SGN_C" checked="checked" /> clone id (SGN-C)<br />
    <input type="checkbox" name="SGN_T" checked="checked" /> sequence read id (SGN-T)<br />
    <input type="checkbox" name="SGN_E" checked="checked" /> est id (SGN-E)<br />
    <input type="checkbox" name="build_nr" checked="checked" /> unigene build number<br />
    <!-- SGN_U for Member Info -->
    <input type="checkbox" name="SGN_U_M" checked="checked" /> unigene id (SGN-U)<br />
    <input type="checkbox" name="chipname" checked="checked" /> chipname<br />
    <input type="checkbox" name="SGN_S" checked="checked" /> microarray spot id (SGN-S)<br />
    <input type="checkbox" name="TUS" checked="checked" /> TUS number<br />
    <input type="checkbox" name="manual_annotation" /> manual annotation<br />
    <input type="checkbox" name="est_seq" checked="checked" /> EST sequence<br />
</div>
</td></tr></table>

HTML1

	;

	if ($debug eq "1") {
		print qq|<input type="checkbox" checked="checked" name=debug /> print debug statements<br /><br />\n|;
	}

	print <<HTML2

	<input type=hidden name="idType" value="unigene" />
	<input type="reset" />&nbsp;&nbsp;
<input type="submit" value="Submit" /><br />
</form>

HTML2

	;

}

=head2 unigene_convert

  Desc: sub unigene_convert
  Args: n/a
  Ret : unigene tab format

  Defines the format of the unigene conversion tab using html, perl and perl dbi. Speicfies
  information fields available for searching unigenes. Prints the debug
  checkbox when debug parameter is set to one.

=cut

sub unigene_convert {
	#
	# displays the unigene converter input form
	#
	# Note: the unigene input form does not display the drop down of unigene builds, because a unigene ID is by definition mapped to a
	# given build.

	my ($page, $db, $debug) = @_;

	my $content="";

	print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

HTML
	;
	print <<HTML1

<br />
Enter a list of identifiers or upload a file containing one identifer separated by whitespace (returns, spaces or tabs):<br />


<table summary="" width="100%" cellpadding="0"><tr><td>
<textarea name="ids" rows="5" cols="50"></textarea>
</td>
<td>
<i>Example:</i>
<pre style="border: 1px solid grey; width: 20em; height: 5em">
SGN-U268057
SGN-U562661
SGN-U196026
</pre>
</td></tr></table>
<br />
<br />

And/or upload list file: <br /><input type="file" name="file" />
<br />
<br />

</td></tr></table>

HTML1

	;

	if ($debug eq "1") {
		print qq|<input type="checkbox" checked="checked" name="debug" /> print debug statements<br /><br />\n|;
	}

	print <<HTML2

	<input type=hidden name="idType" value="unigene_convert" />
	<input type="reset" />&nbsp;&nbsp;
<input type="submit" value="Convert" /><br />
</form>

HTML2

	;
}

#deprecated
sub output_type {
	print <<OUTPUT_TYPE;

	Output type:<br />
	<input type="radio" name="outputType" value="html" checked="checked" /> HTML<br />
	<input type="radio" name="outputType" value="text" /> text<br />
	&nbsp; &nbsp; &nbsp;<input type="checkbox" name="fasta" /> Fasta<br />
	<br />

OUTPUT_TYPE

}

#method used by clone_name and microarray searches to display checkboxes
sub output_list {
	print <<OUTPUT_LIST;

	<b>Please select the information you would like for each identifier:</b><br />
	<input type="checkbox" name="clone_name" checked="checked" /> clone name<br />
	<input type="checkbox" name="SGN_C" checked="checked" /> clone id (SGN-C)<br />
	<input type="checkbox" name="SGN_T" checked="checked" /> sequence read id (SGN-T)<br />
	<input type="checkbox" name="SGN_E" checked="checked" /> est id (SGN-E)<br />
	<input type="checkbox" name="build_nr" checked="checked" /> unigene build nr<br />
	<input type="checkbox" name="SGN_U" checked="checked" /> unigene id (SGN-U)<br />
	<input type="checkbox" name="chipname" checked="checked" /> chipname<br />
	<input type="checkbox" name="SGN_S" checked="checked" /> microarray spot id (SGN-S)<br />
	<input type="checkbox" name="TUS" checked="checked" /> TUS number (used to order clones)<br />
	<input type="checkbox" name="manual_annotation" /> manual annotation<br />
	<input type="checkbox" name="automatic_annotation" /> automatic (BLAST) annotation<br />
	<input type="checkbox" name="sequence" onclick="check_fasta_option()" /> sequence<br />
	&nbsp;&nbsp;&nbsp;<input type="radio" name="seq_type" value="est_seq" checked="checked" /> EST sequence<br />
	&nbsp;&nbsp;&nbsp;<input type="radio" name="seq_type" value="unigene_seq" /> Unigene sequence<br />

OUTPUT_LIST

}

=head2 bac_search

  Desc: sub bac_search
  Args: n/a
  Ret : BAC tab format

  Defines the format of the BAC tab using html & perl. Speicfies
  information fields available for searching BACs. Prints the debug
  checkbox when debug parameter is set to one.

=cut

# new bac_search
sub bac_search {

	# displays the bac search input form
	#
	my ($page, $db, $debug) = @_;

	my $content="";


	print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">


<br />
Enter a list of identifiers or upload a file containing identifers separated by whitespace (returns, spaces or tabs):<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>Example:</i>
<pre style="border: 1px solid gray; width: 10em; height: 5em">
LE_HBa0033F11
SL_MboI0001A07
SL_EcoRI0022A07

</pre>
</td></tr></table>
<br />
<br />
And/or upload list file: <br /><input type="file" name="file" />
<br />
<br />

</td><td valign="top" bgcolor="#EEEEEE" width="320">\n
<b>Download BAC information:</b> <br />
<div style="margin: 1em; white-space: nowrap">
  <input type="checkbox" name="arizona_clone_name" checked="checked"  /> Arizona-style clone name (LE_HBa0001A01) <br />
  <input type="checkbox" name="cornell_clone_name" checked="checked"  /> Old Cornell-style clone name (P001A01)<br />
  <input type="checkbox" name="chr_clone_name" checked="checked"  /> Clone name with chromosome (C01HBa0001A01)<br />
  <input type="checkbox" name="clone_type" checked="checked" /> clone type <br />
  <input type="checkbox" name="org_name" checked="checked" /> organism name <br />
  <input type="checkbox" name="accession_name" checked="checked" /> accession name <br />
  <input type="checkbox" name="library_name" checked="checked" /> library name <br />
  <input type="checkbox" name="estimated_length" checked="checked" /> estimated length <br />
  <input type="checkbox" name="genbank_accession" checked="checked" /> genbank accession<br />
<!--	<input type="checkbox" name="overgo_matches" checked="checked" DISABLED /> overgo matches<br /> -->
</div>

</td></tr></table>
HTML


	if ($debug eq "1") {
		print qq|<input type="checkbox" checked="checked" name="debug" /> print debug statements<br /><br />\n|;
	}

	print <<HTML;

	<input type="hidden" name="idType" value="bac" />
	<input type="reset" />&nbsp;&nbsp;
        <input type="submit" value="Submit"><br />
   </form>

HTML

}

=head2 bac_end_search

  Desc: sub bac_end_search
  Args: n/a
  Ret : BAC end tab format

  Defines the format of the BAC end=head2 bac_end_search tab using html & perl.
  Specifies information fields available for searching BAC ends. Prints the debug
  checkbox when debug parameter is set to one.

=cut

# new bac_end
sub bac_end_search {

	# displays the bac search input form
	#
	my ($page, $db, $debug) = @_;

	my $content="";


	print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="370">


<br />
Enter a list of identifiers or upload a file containing identifers separated by whitespace (returns, spaces or tabs):<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="25"></textarea>
</td>
<td>
<i>Example:</i>
<pre style="border: 1px solid gray; width: 15em; height: 5em">
LE_HBa0011C24_SP6_121022
SL_MboI0033A13_SP6_294865
SL_EcoRI0022A07_T7_229350

</pre>
</td></tr></table>
<br />
<br />
And/or upload list file: <br /><input type="file" name="file" />
<br />
<br />

</td><td valign="top" bgcolor="#EEEEEE" width="280">\n

<b>Download BAC end information:</b><br />
<div style="margin-left: 1em; white-space: nowrap">
  <input type="checkbox" name="bac_id" checked= "checked" /> bac end identifier <br />
  <input type="checkbox" name="clone_type" checked="checked" /> clone type <br />
  <input type="checkbox" name="org_name" checked="checked" /> organism name <br />
  <input type="checkbox" name="accession_name" checked="checked" /> accession name <br />
  <input type="checkbox" name="library_name" checked="checked" /> library name <br />
  <input type="checkbox" name="estimated_length" checked="checked" /> estimated length <br />
  <input type="checkbox" name="genbank_accession" checked="checked" /> genbank accession<br />
  <!--	<input type="checkbox" name="overgo_matches" checked="checked" DISABLED /> overgo matches <br /> -->  <br />
  <b>Choose format and type:</b><br />
  <input type="checkbox" name="bac_end_sequence" checked="checked" /> bac end sequence <br />
  <input type="checkbox" name="qual_value_seq" checked="checked" /> quality value <br />
  <div style="margin-left: 1em">
    <input type="radio" name="bac_seq_type" value="raw_seq" />raw sequence and/or quality<br />
    <input type="radio" name="bac_seq_type" value="trim_seq" checked="checked" />trimmed seq. and/or quality<br />
  </div>
</div>
	
	
</td></tr></table>
HTML


	if ($debug eq "1") {
		print qq|<input type="checkbox" checked="checked" name="debug" /> print debug statements<br /><br />\n|;
	}

	print <<HTML;

	<input type="hidden" name="idType" value="bac_end" />
	<input type="reset" />&nbsp;&nbsp;
        <input type="submit" value="Submit"><br />
   </form>

HTML

}



=head2 ftp_site

  Desc: sub ftp_site
  Args: n/a
  Ret : ftp tab format

  Defines the format of the ftp tab using html & perl. Specifies
  links for downloading ftp information.

=cut

sub ftp_site {
    my $page = shift;

    print <<HTML;
    <h3 style="margin-bottom: 0.3em">SGN FTP site</h3>
	<div style="margin: 0 1em 0 1em">Download complete datasets.</div><br />

    <div style="margin: 0; padding: 1em; border: 1px solid #ccccff">
	<a class="folderlink" href="ftp://ftp.solgenomics.net">ftp top level</a>
	
	<ul style="margin: 1em 0 0 0; list-style: none">
	
HTML
	
    my %ftplinks = ('unigene_builds'    => 'Sequence, quality, and membership information for all SGN unigene builds',
		    'est_sequences'     => 'Sequence and quality files for all SGN ESTs, organized by library',
		    'maps_and_markers'  => 'Marker sequences and marker position lists for all SGN maps',
		    'physical_mapping'  => 'Raw data files for Tomato HindIII BAC library FPC and overgo analyses',
		    'blast_annotations' => 'Highest-ranked hits vs. Genbank NR and Arabidopsis for all SGN unigenes.',
		    'manual_annotations'=> 'Manual annotations for a number of SGN unigenes',
		    'user_requests'     => 'Custom-generated datasets for individual users (mail special requests to <a href="mailto:sgn-feedback@sgn.cornell.edu">sgn-feedback</a>)',
		    'tomato_genome'     => 'Tomato genomic data, including BAC end and full BAC sequences',
                    'COSII'             => 'COSII marker data'
		    );

    foreach my $dir (sort keys %ftplinks) {
	my $desc = $ftplinks{$dir};
	print <<HTML;
	<li><a class="folderlink" href="ftp://ftp.solgenomics.net/$dir"> $dir</a>
	    <div class="folderdesc">$desc</div>
	</li>
HTML
    }


    print <<HTML;
        </ul>
    </div>

	<br />
	<i>Note:</i> The SGN FTP site can also be accessed directly through <a href="ftp://ftp.solgenomics.net">ftp://ftp.solgenomics.net</a> using a browser or ftp program.
HTML

}


=head1 BUGS

  None known.

=head1 AUTHOR

  Lukas Mueller, August 12, 2003
  Modified and documented by Caroline Nyenke, August 11, 2005
  Modified June 27th, 2007 by Alexander Naydich and Matthew Crumb
 

=head1 SEE ALSO

  /bulk/download.pl
  /bulk/display.pl

=cut
