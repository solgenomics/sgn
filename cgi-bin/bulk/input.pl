
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

use Modern::Perl;
use CatalystX::GlobalContext qw($c);
use SGN::I18N;
use HTML::Entities qw(encode_entities);
use CXGN::Page;
use CXGN::Page::FormattingHelpers
  qw/page_title_html modesel simple_selectbox_html/;
use CXGN::DB::Connection;

our $page = CXGN::Page->new( "Bulk download",
    "Lukas Mueller, Caroline Nyenke, Rob Buels" );
my $db = CXGN::DB::Connection->new();

my ( $mode, $debug ) =
  $page->get_arguments(qw/mode debug/);  #determine mode and whether debug is on

my SGN::I18N $bulk_input_i18n = eval { $c && $c->i18n };
my $bulk_input_page_title = encode_entities($bulk_input_i18n ? $bulk_input_i18n->p('global.bulk.input.page_title', 'Bulk download') : 'Bulk download');
my $bulk_input_intro = encode_entities($bulk_input_i18n ? $bulk_input_i18n->p('global.bulk.input.intro', 'Download Unigene or BAC information using a list of identifiers, or complete datasets with FTP.') : 'Download Unigene or BAC information using a list of identifiers, or complete datasets with FTP.');
my $bulk_input_note_label = encode_entities($bulk_input_i18n ? $bulk_input_i18n->p('global.bulk.input.note_label', 'Note:') : 'Note:');
my $bulk_input_email_label = encode_entities($bulk_input_i18n ? $bulk_input_i18n->p('global.bulk.input.email_us', 'email us') : 'email us');
my $bulk_input_email_link = '<a href="mailto:sgn-feedback@sgn.cornell.edu">' . $bulk_input_email_label . '</a>';
my $bulk_input_limit_note = $bulk_input_i18n ? $bulk_input_i18n->p('global.bulk.input.limit_note', 'The SGN bulk download is limited to 10,000 identifiers per request.  If you need more, please either split your query into multiple parts, download a full dataset from the FTP site, or %{email_link} and we will be happy to generate a custom dataset for you.', { email_link => '__SGN_BULK_EMAIL_LINK__' }) : 'The SGN bulk download is limited to 10,000 identifiers per request.  If you need more, please either split your query into multiple parts, download a full dataset from the FTP site, or __SGN_BULK_EMAIL_LINK__ and we will be happy to generate a custom dataset for you.';
$bulk_input_limit_note = encode_entities($bulk_input_limit_note);
$bulk_input_limit_note =~ s/__SGN_BULK_EMAIL_LINK__/$bulk_input_email_link/;
$page->header( $bulk_input_page_title, $bulk_input_page_title )
  ;                                      #print page header and text below
print <<EOH;
<div style="margin-bottom: 1em">$bulk_input_intro</div>
EOH

# create tab categories
my @mode_funcs = (
    \&clone_search,   \&array_search, \&unigene_search, \&bac_search,
    \&bac_end_search, \&ftp_site,     \&unigene_convert,
);

my SGN::I18N $bulk_mode_i18n = eval { $c && $c->i18n };
my $bulk_mode_clone = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('global.bulk.input.tab_clone', 'Clone name') : 'Clone name');
$bulk_mode_clone =~ s/ /&nbsp;/g;
my $bulk_mode_array = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('global.bulk.input.tab_array', 'Array spot ID') : 'Array spot ID');
$bulk_mode_array =~ s/ /&nbsp;/g;
my $bulk_mode_unigene = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('global.bulk.input.tab_unigene', 'Unigene ID') : 'Unigene ID');
$bulk_mode_unigene =~ s/ /&nbsp;/g;
my $bulk_mode_full = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('global.bulk.input.tab_full', 'Full datasets') : 'Full datasets');
$bulk_mode_full =~ s/ /&nbsp;/g;
my $bulk_mode_convert = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('global.bulk.input.tab_convert', 'Unigene ID Converter') : 'Unigene ID Converter');
$bulk_mode_convert =~ s/ /&nbsp;/g;
my $bulk_mode_bacs = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('lists_datasets.bulk.bacs', 'BACs') : 'BACs');
my $bulk_mode_bac_ends = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('lists_datasets.bulk.bac_ends', 'BAC ends') : 'BAC ends');
$bulk_mode_bac_ends =~ s/ /&nbsp;/g;
my $bulk_mode_features = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('lists_datasets.bulk.features', 'Features') : 'Features');
my $bulk_mode_genes = encode_entities($bulk_mode_i18n ? $bulk_mode_i18n->p('lists_datasets.bulk.genes', 'Genes') : 'Genes');

# define urls of modes
my @mode_links = (
    [ '?mode=clone_search',    $bulk_mode_clone . '<br />(SGN-C)' ],
    [ '?mode=microarray',      $bulk_mode_array . '<br />(SGN-S)' ],
    [ '?mode=unigene',         $bulk_mode_unigene . '<br />(SGN-U)' ],
    [ '?mode=bac',             $bulk_mode_bacs ],
    [ '?mode=bac_end',         $bulk_mode_bac_ends ],
    [ '?mode=ftp',             $bulk_mode_full . '<br />(FTP)' ],
    [ '?mode=unigene_convert', $bulk_mode_convert . '<br />(SGN-U)' ],
    [ '/bulk/feature',         $bulk_mode_features ],
    [ '/bulk/gene',            $bulk_mode_genes ],
);

### figure out which mode we're in ###
my $modenum =
    $mode =~ /clone_search/i    ? 0
  : $mode =~ /array/i           ? 1
  : $mode =~ /unigene_convert/i ? 6
  : $mode =~ /unigene/i         ? 2
  : $mode =~ /bac_end/i         ? 4
  : $mode =~ /bac/i             ? 3
  : $mode =~ /ftp/i             ? 5
  : $mode =~ /feature/i         ? 7
  :                               0;    #clone search is default

### print out the mode selection buttons at the top of the page ###
### prints out all @mode_links buttons, highlighting the current selected one###
print modesel( \@mode_links, $modenum );
print qq|<div class="indentedcontent">\n|;

### call the appropriate function from the $mode_funcs list to print###
### out the download form, passing the $page object                      ###
$mode_funcs[$modenum]( $page, $db, $debug );

print <<EOH;
</div>
        <i><b>$bulk_input_note_label</b> $bulk_input_limit_note</i>
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
sub DEBUG {
    print shift(@_);
}

sub ug_build_selectbox {
    my ( $db, $filter_sub ) = @_;
    my SGN::I18N $bulk_build_select_i18n = eval { $c && $c->i18n };
    my $bulk_build_label = encode_entities($bulk_build_select_i18n ? $bulk_build_select_i18n->p('lists_datasets.bulk.build_label', 'Only include unigene build:') : 'Only include unigene build:');
    my %builds;
    my $sth = $db->prepare(
        q|SELECT 	ub.unigene_build_id,
					ub.organism_group_id,
					ub.build_nr,
					g.group_id,
					g.comment
				FROM	sgn.unigene_build as ub, sgn.groups as g
				WHERE 	ub.organism_group_id=g.group_id
				  AND 	g.type=1
				  AND 	ub.status='C'
			 |
    );
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() ) {
        if ($filter_sub) {
            next unless $filter_sub->(@row);
        }

        my ( $unigene_build_id, $organism_group_id, $build_nr, $group_id,
            $species )
          = @row;
        $species =~ s/(\S)[a-z]+\s([a-z]+)/uc($1).'. '.$2/ei
          ;    #< abbreviate the species names
        $builds{$unigene_build_id} = "$species (build $build_nr)";
    }

    my $bulk_include_all = encode_entities($bulk_build_select_i18n ? $bulk_build_select_i18n->p('lists_datasets.bulk.include_all', 'include all') : 'include all');
    return simple_selectbox_html(
        name    => 'build_id',
        label   => $bulk_build_label,
        choices => [
            [ all => $bulk_include_all ],
            ( map [ $_, $builds{$_} ], keys %builds ),
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
    my ( $page, $db, $debug ) = @_;
    my SGN::I18N $bulk_clone_search_i18n = eval { $c && $c->i18n };
    my $bulk_clone_search_reset_button = encode_entities($bulk_clone_search_i18n ? $bulk_clone_search_i18n->p('lists_datasets.bulk.reset', 'Reset') : 'Reset');
    my $bulk_clone_search_submit_button = encode_entities($bulk_clone_search_i18n ? $bulk_clone_search_i18n->p('lists_datasets.bulk.submit', 'Submit') : 'Submit');
    my $bulk_clone_search_prompt = encode_entities($bulk_clone_search_i18n ? $bulk_clone_search_i18n->p('lists_datasets.bulk.enter_a_list_of_identifiers_or_upload_a_file_containing_identifers_one_per_lin', 'Enter a list of identifiers or upload a file containing identifers, one per line:') : 'Enter a list of identifiers or upload a file containing identifers, one per line:');
    my $bulk_clone_search_example = encode_entities($bulk_clone_search_i18n ? $bulk_clone_search_i18n->p('lists_datasets.bulk.example', 'Example:') : 'Example:');
    my $bulk_clone_search_upload = encode_entities($bulk_clone_search_i18n ? $bulk_clone_search_i18n->p('lists_datasets.bulk.and_or_upload_list_file', 'And/or upload list file:') : 'And/or upload list file:');
    my $bulk_clone_search_debug = encode_entities($bulk_clone_search_i18n ? $bulk_clone_search_i18n->p('global.bulk.input.print_debug', 'print debug statements') : 'print debug statements');

    my $content         = "";
    my $ug_build_select = ug_build_selectbox($db);
    print <<HTML;
<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

$ug_build_select
<br />

$bulk_clone_search_prompt<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>$bulk_clone_search_example</i> #example box
<pre style="border: 1px solid gray; width: 10em; height: 5em">
cLEB-1-A2
cLEB-1-A3
cLEB-1-A4
</pre>
</td></tr></table>

<br />
<br />
$bulk_clone_search_upload <br /><input type="file" name="file" />
<br />
<br />

HTML

    print qq|</td><td valign="top" bgcolor="#EEEEEE" width="320">\n|;
    output_list();    #print out checkboxes

    print <<HTML;

</td></tr></table>

HTML

    if ( $debug eq "1" ) {
        print
qq|<input type="checkbox" checked="checked" name="debug" /> $bulk_clone_search_debug<br /><br />\n|;
    }

    print <<HTML;

	<input type="hidden" name="idType" value="clone" />
	<input type="reset" value="$bulk_clone_search_reset_button" />&nbsp;&nbsp;
        <input type="submit" value="$bulk_clone_search_submit_button" /><br />
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
    my ( $page, $db, $debug ) = @_;
    my SGN::I18N $bulk_array_search_i18n = eval { $c && $c->i18n };
    my $bulk_array_search_reset_button = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('lists_datasets.bulk.reset', 'Reset') : 'Reset');
    my $bulk_array_search_submit_button = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('lists_datasets.bulk.submit', 'Submit') : 'Submit');
    my $bulk_array_search_prompt = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('lists_datasets.bulk.enter_a_list_of_identifiers_or_upload_a_file_containing_one_identifier', 'Enter a list of identifiers or upload a file containing one identifier:') : 'Enter a list of identifiers or upload a file containing one identifier:');
    my $bulk_array_search_example = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('lists_datasets.bulk.example', 'Example:') : 'Example:');
    my $bulk_array_search_upload = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('lists_datasets.bulk.and_or_upload_list_file', 'And/or upload list file:') : 'And/or upload list file:');
    my $bulk_array_search_debug = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('global.bulk.input.print_debug', 'print debug statements') : 'print debug statements');
    my $bulk_array_page_title = encode_entities($bulk_array_search_i18n ? $bulk_array_search_i18n->p('global.bulk.input.page_title', 'Bulk download') : 'Bulk download');

    my $content = "";

    $page = CXGN::Page->new( $bulk_array_page_title, "Lukas Mueller" );

    my $ug_select = ug_build_selectbox(
        $db,
        sub {
            ( $_[4] =~ /lycopersicon|tomato/i && $_[4] !~ /demethylated/i )
              ? 1
              : 0;
        }
    );
    print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">
<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

$ug_select
<br /><br />
	<br />
$bulk_array_search_prompt<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>$bulk_array_search_example</i>
<pre style="border: 1px solid gray; width: 10em; height: 5em">
1-1-1.2.3.4
1-1-1.2.4.5
1-1-1.5.3.6
</pre>
</td></tr></table>
<br />
<br />
$bulk_array_search_upload <br /><input type="file" name="file" />
<br />
<br />

 </td><td valign="top" bgcolor="#EEEEEE" width="320">

HTML

    output_list();

    print "</td></tr></table>\n";

    if ( $debug eq "1" ) {
        print
qq|<input type="checkbox" checked="checked" name="debug" /> $bulk_array_search_debug<br /><br />\n|;
    }

    print <<HTML

<input type="hidden" name="idType" value="microarray" />
	<input type="reset" value="$bulk_array_search_reset_button" />&nbsp;&nbsp;
<input type="submit" value="$bulk_array_search_submit_button" /><br />
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
    my ( $page, $db, $debug ) = @_;
    my SGN::I18N $bulk_unigene_options_i18n = eval { $c && $c->i18n };
    my $bulk_unigene_search_reset_button = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.reset', 'Reset') : 'Reset');
    my $bulk_unigene_search_submit_button = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.submit', 'Submit') : 'Submit');
    my $bulk_unigene_convert_unigene_list_to_current_build = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.convert_unigene_list_to_current_build', 'convert unigene list to current build') : 'convert unigene list to current build');
    my $bulk_unigene_download_unigene_info = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.download_unigene_information', 'Download unigene information') : 'Download unigene information');
    my $bulk_unigene_unigene_id = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.unigene_id_sgn_u', 'unigene id (SGN-U)') : 'unigene id (SGN-U)');
    my $bulk_unigene_automatic_annotation = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.automatic_blast_annotation', 'automatic (BLAST) annotation') : 'automatic (BLAST) annotation');
    my $bulk_unigene_best_genbank = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.best_genbank_match', 'best genbank match') : 'best genbank match');
    my $bulk_unigene_best_arabidopsis = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.best_arabidopsis_match', 'best arabidopsis match') : 'best arabidopsis match');
    my $bulk_unigene_associated_loci = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.associated_loci', 'associated loci') : 'associated loci');
    my $bulk_unigene_sequence = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.sequence', 'sequence') : 'sequence');
    my $bulk_unigene_unigene_nucleotide = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.unigene_nucleotide_sequence', 'unigene nucleotide sequence') : 'unigene nucleotide sequence');
    my $bulk_unigene_estscan_proteins = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.estscan_predicted_proteins', 'estscan predicted proteins') : 'estscan predicted proteins');
    my $bulk_unigene_longest_orf = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.longest_orf_from_6_frame_translation', 'longest ORF from 6-frame translation') : 'longest ORF from 6-frame translation');
    my $bulk_unigene_preferred_sequence = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.preferred_sequence', 'preferred sequence') : 'preferred sequence');
    my $bulk_unigene_download_member = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.download_member_information', 'Download member information') : 'Download member information');
    my $bulk_unigene_clone_name = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.clone_name', 'clone name') : 'clone name');
    my $bulk_unigene_clone_id = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.clone_id_sgn_c', 'clone id (SGN-C)') : 'clone id (SGN-C)');
    my $bulk_unigene_read_id = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.sequence_read_id_sgn_t', 'sequence read id (SGN-T)') : 'sequence read id (SGN-T)');
    my $bulk_unigene_est_id = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.est_id_sgn_e', 'est id (SGN-E)') : 'est id (SGN-E)');
    my $bulk_unigene_build_number = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.unigene_build_number', 'unigene build number') : 'unigene build number');
    my $bulk_unigene_microarray_id = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.microarray_spot_id_sgn_s', 'microarray spot id (SGN-S)') : 'microarray spot id (SGN-S)');
    my $bulk_unigene_chipname = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.chipname', 'chipname') : 'chipname');
    my $bulk_unigene_tus = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.tus_number', 'TUS number') : 'TUS number');
    my $bulk_unigene_manual_annotation = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.manual_annotation', 'manual annotation') : 'manual annotation');
    my $bulk_unigene_est_sequence = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('lists_datasets.bulk.est_sequence', 'EST sequence') : 'EST sequence');
    my $bulk_unigene_convert_title = encode_entities($bulk_unigene_options_i18n ? $bulk_unigene_options_i18n->p('global.bulk.input.convert_title', 'Check this box to convert each unigene in the list to its equivalent in the most current corresponding unigene build(s), if available') : 'Check this box to convert each unigene in the list to its equivalent in the most current corresponding unigene build(s), if available');
    my SGN::I18N $bulk_unigene_search_i18n = eval { $c && $c->i18n };
    my $bulk_unigene_search_prompt = encode_entities($bulk_unigene_search_i18n ? $bulk_unigene_search_i18n->p('lists_datasets.bulk.enter_a_list_of_identifiers_or_upload_a_file_containing_one_identifer_separate', 'Enter a list of identifiers or upload a file containing one identifer separated by whitespace (returns, spaces or tabs):') : 'Enter a list of identifiers or upload a file containing one identifer separated by whitespace (returns, spaces or tabs):');
    my $bulk_unigene_search_example = encode_entities($bulk_unigene_search_i18n ? $bulk_unigene_search_i18n->p('lists_datasets.bulk.example', 'Example:') : 'Example:');
    my $bulk_unigene_search_upload = encode_entities($bulk_unigene_search_i18n ? $bulk_unigene_search_i18n->p('lists_datasets.bulk.and_or_upload_list_file', 'And/or upload list file:') : 'And/or upload list file:');
    my $bulk_unigene_search_debug = encode_entities($bulk_unigene_search_i18n ? $bulk_unigene_search_i18n->p('global.bulk.input.print_debug', 'print debug statements') : 'print debug statements');

    my $content   = "";
    my $ug_select = ug_build_selectbox($db);

    print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

HTML

    print <<HTML1

<br />
$bulk_unigene_search_prompt<br />


<table summary="" width="100%" cellpadding="0"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>$bulk_unigene_search_example</i>
<pre style="border: 1px solid gray; width: 10em; height: 5em">
SGN-U268057
SGN-U562661
SGN-U196026
</pre>
</td></tr></table>
<br />
<br />

$bulk_unigene_search_upload <br /><input type="file" name="file" />
<br />
<br />

</td><td valign="top" bgcolor="#EEEEEE" width="320">

 <input type="checkbox" name="convert_to_current" checked="checked" /><label for="convert_to_current"><a class="stealth" title="$bulk_unigene_convert_title"><img src="/documents/img/new.gif" />$bulk_unigene_convert_unigene_list_to_current_build</a></label>

 <hr />

<input type="radio" name="unigene_mode" value="unigene_info" checked="checked" /> <b>$bulk_unigene_download_unigene_info</b>:<br />
<!-- SGN_U for Unigene Info -->
<div style="padding-left: 1em">
    <input type="checkbox" name="SGN_U_U" checked="checked" /> $bulk_unigene_unigene_id<br />
    <input type="checkbox" name="automatic_annotation" checked="checked" /> $bulk_unigene_automatic_annotation<br />
    <input type="checkbox" name="best_genbank_match" checked="checked" /> $bulk_unigene_best_genbank<br />
    <input type="checkbox" name="best_arabidopsis_match" checked="checked" /> $bulk_unigene_best_arabidopsis<br />
    <input type="checkbox" name="associated_loci" checked="checked" /> $bulk_unigene_associated_loci<br />
    <input type="checkbox" name = "uni_seq" checked="checked" onclick="check_fasta_option()"/> $bulk_unigene_sequence<br />
    <div style="padding-left: 1em">
         <input type="radio" name="seq_mode" value="unigene_seq" checked="checked" /> $bulk_unigene_unigene_nucleotide<br />
         <input type="radio" name="seq_mode" value="estscan_seq" /> $bulk_unigene_estscan_proteins<br />
         <input type="radio" name="seq_mode" value="longest6frame_seq" /> $bulk_unigene_longest_orf<br />
         <input type="radio" name="seq_mode" value="preferred_protein_seq" /> $bulk_unigene_preferred_sequence<br />
    </div>
</div>

<input type="radio" name="unigene_mode" value="member_info" /> <b>$bulk_unigene_download_member</b>:
<div style="padding-left: 1em">
    <input type="checkbox" name="clone_name" checked="checked" /> $bulk_unigene_clone_name<br />
    <input type="checkbox" name="SGN_C" checked="checked" /> $bulk_unigene_clone_id<br />
    <input type="checkbox" name="SGN_T" checked="checked" /> $bulk_unigene_read_id<br />
    <input type="checkbox" name="SGN_E" checked="checked" /> $bulk_unigene_est_id<br />
    <input type="checkbox" name="build_nr" checked="checked" /> $bulk_unigene_build_number<br />
    <!-- SGN_U for Member Info -->
    <input type="checkbox" name="SGN_U_M" checked="checked" /> $bulk_unigene_unigene_id<br />
    <input type="checkbox" name="chipname" checked="checked" /> $bulk_unigene_chipname<br />
    <input type="checkbox" name="SGN_S" checked="checked" /> $bulk_unigene_microarray_id<br />
    <input type="checkbox" name="TUS" checked="checked" /> $bulk_unigene_tus<br />
    <input type="checkbox" name="manual_annotation" /> $bulk_unigene_manual_annotation<br />
    <input type="checkbox" name="est_seq" checked="checked" /> $bulk_unigene_est_sequence<br />
</div>
</td></tr></table>

HTML1

      ;

    if ( $debug eq "1" ) {
        print
qq|<input type="checkbox" checked="checked" name=debug /> $bulk_unigene_search_debug<br /><br />\n|;
    }

    print <<HTML2

	<input type=hidden name="idType" value="unigene" />
	<input type="reset" value="$bulk_unigene_search_reset_button" />&nbsp;&nbsp;
<input type="submit" value="$bulk_unigene_search_submit_button" /><br />
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

    my ( $page, $db, $debug ) = @_;
    my SGN::I18N $bulk_unigene_convert_i18n = eval { $c && $c->i18n };
    my $bulk_unigene_convert_reset_button = encode_entities($bulk_unigene_convert_i18n ? $bulk_unigene_convert_i18n->p('lists_datasets.bulk.reset', 'Reset') : 'Reset');
    my $bulk_unigene_convert_submit_button = encode_entities($bulk_unigene_convert_i18n ? $bulk_unigene_convert_i18n->p('global.bulk.input.convert_button', 'Convert') : 'Convert');
    my $bulk_unigene_convert_prompt = encode_entities($bulk_unigene_convert_i18n ? $bulk_unigene_convert_i18n->p('lists_datasets.bulk.enter_a_list_of_identifiers_or_upload_a_file_containing_one_identifer_separate', 'Enter a list of identifiers or upload a file containing one identifer separated by whitespace (returns, spaces or tabs):') : 'Enter a list of identifiers or upload a file containing one identifer separated by whitespace (returns, spaces or tabs):');
    my $bulk_unigene_convert_example = encode_entities($bulk_unigene_convert_i18n ? $bulk_unigene_convert_i18n->p('lists_datasets.bulk.example', 'Example:') : 'Example:');
    my $bulk_unigene_convert_upload = encode_entities($bulk_unigene_convert_i18n ? $bulk_unigene_convert_i18n->p('lists_datasets.bulk.and_or_upload_list_file', 'And/or upload list file:') : 'And/or upload list file:');
    my $bulk_unigene_convert_debug = encode_entities($bulk_unigene_convert_i18n ? $bulk_unigene_convert_i18n->p('global.bulk.input.print_debug', 'print debug statements') : 'print debug statements');

    my $content = "";

    print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">

HTML
    print <<HTML1

<br />
$bulk_unigene_convert_prompt<br />


<table summary="" width="100%" cellpadding="0"><tr><td>
<textarea name="ids" rows="5" cols="50"></textarea>
</td>
<td>
<i>$bulk_unigene_convert_example</i>
<pre style="border: 1px solid grey; width: 20em; height: 5em">
SGN-U268057
SGN-U562661
SGN-U196026
</pre>
</td></tr></table>
<br />
<br />

$bulk_unigene_convert_upload <br /><input type="file" name="file" />
<br />
<br />

</td></tr></table>

HTML1

      ;

    if ( $debug eq "1" ) {
        print
qq|<input type="checkbox" checked="checked" name="debug" /> $bulk_unigene_convert_debug<br /><br />\n|;
    }

    print <<HTML2

	<input type=hidden name="idType" value="unigene_convert" />
	<input type="reset" value="$bulk_unigene_convert_reset_button" />&nbsp;&nbsp;
<input type="submit" value="$bulk_unigene_convert_submit_button" /><br />
</form>

HTML2

      ;
}

#deprecated
sub output_type {
    my SGN::I18N $bulk_output_type_i18n = eval { $c && $c->i18n };
    my $bulk_output_type_label = encode_entities($bulk_output_type_i18n ? $bulk_output_type_i18n->p('global.bulk.input.output_type', 'Output type:') : 'Output type:');
    my $bulk_output_text_label = encode_entities($bulk_output_type_i18n ? $bulk_output_type_i18n->p('global.bulk.input.output_text', 'text') : 'text');
    print <<OUTPUT_TYPE;

	$bulk_output_type_label<br />
	<input type="radio" name="outputType" value="html" checked="checked" /> HTML<br />
	<input type="radio" name="outputType" value="text" /> $bulk_output_text_label<br />
	&nbsp; &nbsp; &nbsp;<input type="checkbox" name="fasta" /> Fasta<br />
	<br />

OUTPUT_TYPE

}

#method used by clone_name and microarray searches to display checkboxes
sub output_list {
    my SGN::I18N $bulk_output_list_i18n = eval { $c && $c->i18n };
    my $bulk_select_identifier = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.please_select_the_information_you_would_like_for_each_identifier', 'Please select the information you would like for each identifier:') : 'Please select the information you would like for each identifier:');
    my $bulk_clone_name = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.clone_name', 'clone name') : 'clone name');
    my $bulk_clone_id = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.clone_id_sgn_c', 'clone id (SGN-C)') : 'clone id (SGN-C)');
    my $bulk_read_id = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.sequence_read_id_sgn_t', 'sequence read id (SGN-T)') : 'sequence read id (SGN-T)');
    my $bulk_est_id = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.est_id_sgn_e', 'est id (SGN-E)') : 'est id (SGN-E)');
    my $bulk_build_nr = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.unigene_build_nr', 'unigene build nr') : 'unigene build nr');
    my $bulk_unigene_id = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.unigene_id_sgn_u', 'unigene id (SGN-U)') : 'unigene id (SGN-U)');
    my $bulk_chipname = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.chipname', 'chipname') : 'chipname');
    my $bulk_spot_id = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.microarray_spot_id_sgn_s', 'microarray spot id (SGN-S)') : 'microarray spot id (SGN-S)');
    my $bulk_tus_number = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.tus_number_used_to_order_clones', 'TUS number (used to order clones)') : 'TUS number (used to order clones)');
    my $bulk_manual_annotation = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.manual_annotation', 'manual annotation') : 'manual annotation');
    my $bulk_automatic_annotation = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.automatic_blast_annotation', 'automatic (BLAST) annotation') : 'automatic (BLAST) annotation');
    my $bulk_sequence = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.sequence', 'sequence') : 'sequence');
    my $bulk_est_sequence = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.est_sequence', 'EST sequence') : 'EST sequence');
    my $bulk_unigene_sequence = encode_entities($bulk_output_list_i18n ? $bulk_output_list_i18n->p('lists_datasets.bulk.unigene_sequence', 'Unigene sequence') : 'Unigene sequence');
    print <<OUTPUT_LIST;

	<b>$bulk_select_identifier</b><br />
	<input type="checkbox" name="clone_name" checked="checked" /> $bulk_clone_name<br />
	<input type="checkbox" name="SGN_C" checked="checked" /> $bulk_clone_id<br />
	<input type="checkbox" name="SGN_T" checked="checked" /> $bulk_read_id<br />
	<input type="checkbox" name="SGN_E" checked="checked" /> $bulk_est_id<br />
	<input type="checkbox" name="build_nr" checked="checked" /> $bulk_build_nr<br />
	<input type="checkbox" name="SGN_U" checked="checked" /> $bulk_unigene_id<br />
	<input type="checkbox" name="chipname" checked="checked" /> $bulk_chipname<br />
	<input type="checkbox" name="SGN_S" checked="checked" /> $bulk_spot_id<br />
	<input type="checkbox" name="TUS" checked="checked" /> $bulk_tus_number<br />
	<input type="checkbox" name="manual_annotation" /> $bulk_manual_annotation<br />
	<input type="checkbox" name="automatic_annotation" /> $bulk_automatic_annotation<br />
	<input type="checkbox" name="sequence" onclick="check_fasta_option()" /> $bulk_sequence<br />
	&nbsp;&nbsp;&nbsp;<input type="radio" name="seq_type" value="est_seq" checked="checked" /> $bulk_est_sequence<br />
	&nbsp;&nbsp;&nbsp;<input type="radio" name="seq_type" value="unigene_seq" /> $bulk_unigene_sequence<br />

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
    my ( $page, $db, $debug ) = @_;
    my SGN::I18N $bulk_bac_search_labels_i18n = eval { $c && $c->i18n };
    my $bulk_bac_search_reset_button = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.reset', 'Reset') : 'Reset');
    my $bulk_bac_search_submit_button = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.submit', 'Submit') : 'Submit');
    my $bulk_bac_search_clone_type = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.clone_type', 'clone type') : 'clone type');
    my $bulk_bac_search_organism = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.organism_name', 'organism name') : 'organism name');
    my $bulk_bac_search_accession = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.accession_name', 'accession name') : 'accession name');
    my $bulk_bac_search_library = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.library_name', 'library name') : 'library name');
    my $bulk_bac_search_estimated_length = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.estimated_length', 'estimated length') : 'estimated length');
    my $bulk_bac_search_genbank_accession = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.genbank_accession', 'genbank accession') : 'genbank accession');
    my $bulk_bac_search_arizona_label = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('global.bulk.input.bac_search.arizona', 'Arizona-style clone name') : 'Arizona-style clone name');
    my $bulk_bac_search_cornell_label = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('global.bulk.input.bac_search.cornell', 'Old Cornell-style clone name') : 'Old Cornell-style clone name');
    my $bulk_bac_search_chromosome_label = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('global.bulk.input.bac_search.chromosome', 'Clone name with chromosome') : 'Clone name with chromosome');
    my $bulk_bac_search_heading = encode_entities($bulk_bac_search_labels_i18n ? $bulk_bac_search_labels_i18n->p('lists_datasets.bulk.download_bac_information', 'Download BAC information:') : 'Download BAC information:');
    my SGN::I18N $bulk_bac_search_i18n = eval { $c && $c->i18n };
    my $bulk_bac_search_prompt = encode_entities($bulk_bac_search_i18n ? $bulk_bac_search_i18n->p('lists_datasets.bulk.enter_a_list_of_identifiers_or_upload_a_file_containing_identifers_separated_b', 'Enter a list of identifiers or upload a file containing identifers separated by whitespace (returns, spaces or tabs):') : 'Enter a list of identifiers or upload a file containing identifers separated by whitespace (returns, spaces or tabs):');
    my $bulk_bac_search_example = encode_entities($bulk_bac_search_i18n ? $bulk_bac_search_i18n->p('lists_datasets.bulk.example', 'Example:') : 'Example:');
    my $bulk_bac_search_upload = encode_entities($bulk_bac_search_i18n ? $bulk_bac_search_i18n->p('lists_datasets.bulk.and_or_upload_list_file', 'And/or upload list file:') : 'And/or upload list file:');
    my $bulk_bac_search_debug = encode_entities($bulk_bac_search_i18n ? $bulk_bac_search_i18n->p('global.bulk.input.print_debug', 'print debug statements') : 'print debug statements');

    my $content = "";

    print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="320">


<br />
$bulk_bac_search_prompt<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="20"></textarea>
</td>
<td>
<i>$bulk_bac_search_example</i>
<pre style="border: 1px solid gray; width: 10em; height: 5em">
LE_HBa0033F11
SL_MboI0001A07
SL_EcoRI0022A07

</pre>
</td></tr></table>
<br />
<br />
$bulk_bac_search_upload <br /><input type="file" name="file" />
<br />
<br />

</td><td valign="top" bgcolor="#EEEEEE" width="320">\n
<b>$bulk_bac_search_heading</b> <br />
<div style="margin: 1em; white-space: nowrap">
  <input type="checkbox" name="arizona_clone_name" checked="checked"  /> $bulk_bac_search_arizona_label (LE_HBa0001A01) <br />
  <input type="checkbox" name="cornell_clone_name" checked="checked"  /> $bulk_bac_search_cornell_label (P001A01)<br />
  <input type="checkbox" name="chr_clone_name" checked="checked"  /> $bulk_bac_search_chromosome_label (C01HBa0001A01)<br />
  <input type="checkbox" name="clone_type" checked="checked" /> $bulk_bac_search_clone_type <br />
  <input type="checkbox" name="org_name" checked="checked" /> $bulk_bac_search_organism <br />
  <input type="checkbox" name="accession_name" checked="checked" /> $bulk_bac_search_accession <br />
  <input type="checkbox" name="library_name" checked="checked" /> $bulk_bac_search_library <br />
  <input type="checkbox" name="estimated_length" checked="checked" /> $bulk_bac_search_estimated_length <br />
  <input type="checkbox" name="genbank_accession" checked="checked" /> $bulk_bac_search_genbank_accession<br />
<!--	<input type="checkbox" name="overgo_matches" checked="checked" DISABLED /> overgo matches<br /> -->
</div>

</td></tr></table>
HTML

    if ( $debug eq "1" ) {
        print
qq|<input type="checkbox" checked="checked" name="debug" /> $bulk_bac_search_debug<br /><br />\n|;
    }

    print <<HTML;

	<input type="hidden" name="idType" value="bac" />
	<input type="reset" value="$bulk_bac_search_reset_button" />&nbsp;&nbsp;
        <input type="submit" value="$bulk_bac_search_submit_button"><br />
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
    my ( $page, $db, $debug ) = @_;
    my SGN::I18N $bulk_bac_end_search_labels_i18n = eval { $c && $c->i18n };
    my $bulk_bac_end_search_reset_button = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.reset', 'Reset') : 'Reset');
    my $bulk_bac_end_search_submit_button = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.submit', 'Submit') : 'Submit');
    my $bulk_bac_end_search_clone_type = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.clone_type', 'clone type') : 'clone type');
    my $bulk_bac_end_search_organism = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.organism_name', 'organism name') : 'organism name');
    my $bulk_bac_end_search_accession = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.accession_name', 'accession name') : 'accession name');
    my $bulk_bac_end_search_library = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.library_name', 'library name') : 'library name');
    my $bulk_bac_end_search_estimated_length = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.estimated_length', 'estimated length') : 'estimated length');
    my $bulk_bac_end_search_genbank_accession = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.genbank_accession', 'genbank accession') : 'genbank accession');
    my $bulk_bac_end_search_arizona_label = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('global.bulk.input.bac_end_search.arizona', 'Arizona-style clone name') : 'Arizona-style clone name');
    my $bulk_bac_end_search_cornell_label = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('global.bulk.input.bac_end_search.cornell', 'Old Cornell-style clone name') : 'Old Cornell-style clone name');
    my $bulk_bac_end_search_chromosome_label = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('global.bulk.input.bac_end_search.chromosome', 'Clone name with chromosome') : 'Clone name with chromosome');
    my $bulk_bac_end_heading = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.download_bac_end_information', 'Download BAC end information:') : 'Download BAC end information:');
    my $bulk_bac_end_id = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.bac_end_identifier', 'bac end identifier') : 'bac end identifier');
    my $bulk_bac_end_sequence_label = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.bac_end_sequence', 'bac end sequence') : 'bac end sequence');
    my $bulk_bac_end_quality = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.quality_value', 'quality value') : 'quality value');
    my $bulk_bac_end_choose = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.choose_format_and_type', 'Choose format and type:') : 'Choose format and type:');
    my $bulk_bac_end_raw = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.raw_sequence_and_or_quality', 'raw sequence and/or quality') : 'raw sequence and/or quality');
    my $bulk_bac_end_trimmed = encode_entities($bulk_bac_end_search_labels_i18n ? $bulk_bac_end_search_labels_i18n->p('lists_datasets.bulk.trimmed_seq_and_or_quality', 'trimmed seq. and/or quality') : 'trimmed seq. and/or quality');
    my SGN::I18N $bulk_bac_end_search_i18n = eval { $c && $c->i18n };
    my $bulk_bac_end_search_prompt = encode_entities($bulk_bac_end_search_i18n ? $bulk_bac_end_search_i18n->p('lists_datasets.bulk.enter_a_list_of_identifiers_or_upload_a_file_containing_identifers_separated_b', 'Enter a list of identifiers or upload a file containing identifers separated by whitespace (returns, spaces or tabs):') : 'Enter a list of identifiers or upload a file containing identifers separated by whitespace (returns, spaces or tabs):');
    my $bulk_bac_end_search_example = encode_entities($bulk_bac_end_search_i18n ? $bulk_bac_end_search_i18n->p('lists_datasets.bulk.example', 'Example:') : 'Example:');
    my $bulk_bac_end_search_upload = encode_entities($bulk_bac_end_search_i18n ? $bulk_bac_end_search_i18n->p('lists_datasets.bulk.and_or_upload_list_file', 'And/or upload list file:') : 'And/or upload list file:');
    my $bulk_bac_end_search_debug = encode_entities($bulk_bac_end_search_i18n ? $bulk_bac_end_search_i18n->p('global.bulk.input.print_debug', 'print debug statements') : 'print debug statements');

    my $content = "";

    print <<HTML;

<form name="bulkform" action="download.pl" method="post" enctype="multipart/form-data">

<br />
<table summary="" cellpadding="10" width="100%"><tr><td valign="top" bgcolor="#EEEEEE" width="370">


<br />
$bulk_bac_end_search_prompt<br />
<table summary="" width="100%"><tr><td>
<textarea name="ids" rows="5" cols="25"></textarea>
</td>
<td>
<i>$bulk_bac_end_search_example</i>
<pre style="border: 1px solid gray; width: 15em; height: 5em">
LE_HBa0011C24_SP6_121022
SL_MboI0033A13_SP6_294865
SL_EcoRI0022A07_T7_229350

</pre>
</td></tr></table>
<br />
<br />
$bulk_bac_end_search_upload <br /><input type="file" name="file" />
<br />
<br />

</td><td valign="top" bgcolor="#EEEEEE" width="280">\n

<b>$bulk_bac_end_heading</b><br />
<div style="margin-left: 1em; white-space: nowrap">
  <input type="checkbox" name="bac_id" checked= "checked" /> $bulk_bac_end_id <br />
  <input type="checkbox" name="clone_type" checked="checked" /> $bulk_bac_end_search_clone_type <br />
  <input type="checkbox" name="org_name" checked="checked" /> $bulk_bac_end_search_organism <br />
  <input type="checkbox" name="accession_name" checked="checked" /> $bulk_bac_end_search_accession <br />
  <input type="checkbox" name="library_name" checked="checked" /> $bulk_bac_end_search_library <br />
  <input type="checkbox" name="estimated_length" checked="checked" /> $bulk_bac_end_search_estimated_length <br />
  <input type="checkbox" name="genbank_accession" checked="checked" /> $bulk_bac_end_search_genbank_accession<br />
  <!--	<input type="checkbox" name="overgo_matches" checked="checked" DISABLED /> overgo matches <br /> -->  <br />
  <b>$bulk_bac_end_choose</b><br />
  <input type="checkbox" name="bac_end_sequence" checked="checked" /> $bulk_bac_end_sequence_label <br />
  <input type="checkbox" name="qual_value_seq" checked="checked" /> $bulk_bac_end_quality <br />
  <div style="margin-left: 1em">
    <input type="radio" name="bac_seq_type" value="raw_seq" />$bulk_bac_end_raw<br />
    <input type="radio" name="bac_seq_type" value="trim_seq" checked="checked" />$bulk_bac_end_trimmed<br />
  </div>
</div>
	
	
</td></tr></table>
HTML

    if ( $debug eq "1" ) {
        print
qq|<input type="checkbox" checked="checked" name="debug" /> $bulk_bac_end_search_debug<br /><br />\n|;
    }

    print <<HTML;

	<input type="hidden" name="idType" value="bac_end" />
	<input type="reset" value="$bulk_bac_end_search_reset_button" />&nbsp;&nbsp;
        <input type="submit" value="$bulk_bac_end_search_submit_button"><br />
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
    my SGN::I18N $bulk_ftp_i18n = eval { $c && $c->i18n };
    my $bulk_ftp_note_label = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.note_label', 'Note:') : 'Note:');
    my $bulk_ftp_title = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_title', 'SGN FTP site') : 'SGN FTP site');
    my $bulk_ftp_intro = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_intro', 'Download complete datasets.') : 'Download complete datasets.');
    my $bulk_ftp_top = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_top', 'ftp top level') : 'ftp top level');
    my $bulk_ftp_access = $bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_access', 'The SGN FTP site can also be accessed directly through %{ftp_link} using a browser or ftp program.', { ftp_link => '__SGN_BULK_FTP_LINK__' }) : 'The SGN FTP site can also be accessed directly through __SGN_BULK_FTP_LINK__ using a browser or ftp program.';
    $bulk_ftp_access = encode_entities($bulk_ftp_access);
    $bulk_ftp_access =~ s/__SGN_BULK_FTP_LINK__/<a href="ftp:\/\/ftp.solgenomics.net">ftp:\/\/ftp.solgenomics.net<\/a>/;

    print <<HTML;
    <h3 style="margin-bottom: 0.3em">$bulk_ftp_title</h3>
	<div style="margin: 0 1em 0 1em">$bulk_ftp_intro</div><br />

    <div style="margin: 0; padding: 1em; border: 1px solid #ccccff">
	<a class="folderlink" href="ftp://ftp.solgenomics.net">$bulk_ftp_top</a>
	
	<ul style="margin: 1em 0 0 0; list-style: none">
	
HTML

    my %ftplinks = (
        'unigene_builds' =>
'Sequence, quality, and membership information for all SGN unigene builds',
        'est_sequences' =>
          'Sequence and quality files for all SGN ESTs, organized by library',
        'maps_and_markers' =>
          'Marker sequences and marker position lists for all SGN maps',
        'physical_mapping' =>
'Raw data files for Tomato HindIII BAC library FPC and overgo analyses',
        'blast_annotations' =>
'Highest-ranked hits vs. Genbank NR and Arabidopsis for all SGN unigenes.',
        'manual_annotations' =>
          'Manual annotations for a number of SGN unigenes',
        'user_requests' =>
'Custom-generated datasets for individual users (mail special requests to <a href="mailto:sgn-feedback@sgn.cornell.edu">sgn-feedback</a>)',
        'tomato_genome' =>
          'Tomato genomic data, including BAC end and full BAC sequences',
        'COSII' => 'COSII marker data'
    );

    foreach my $dir ( sort keys %ftplinks ) {
        my $desc = $ftplinks{$dir};
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_unigene_builds', 'Sequence, quality, and membership information for all SGN unigene builds') : 'Sequence, quality, and membership information for all SGN unigene builds') if $dir eq 'unigene_builds';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_est_sequences', 'Sequence and quality files for all SGN ESTs, organized by library') : 'Sequence and quality files for all SGN ESTs, organized by library') if $dir eq 'est_sequences';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_maps_and_markers', 'Marker sequences and marker position lists for all SGN maps') : 'Marker sequences and marker position lists for all SGN maps') if $dir eq 'maps_and_markers';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_physical_mapping', 'Raw data files for Tomato HindIII BAC library FPC and overgo analyses') : 'Raw data files for Tomato HindIII BAC library FPC and overgo analyses') if $dir eq 'physical_mapping';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_blast_annotations', 'Highest-ranked hits vs. Genbank NR and Arabidopsis for all SGN unigenes.') : 'Highest-ranked hits vs. Genbank NR and Arabidopsis for all SGN unigenes.') if $dir eq 'blast_annotations';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_manual_annotations', 'Manual annotations for a number of SGN unigenes') : 'Manual annotations for a number of SGN unigenes') if $dir eq 'manual_annotations';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_tomato_genome', 'Tomato genomic data, including BAC end and full BAC sequences') : 'Tomato genomic data, including BAC end and full BAC sequences') if $dir eq 'tomato_genome';
        $desc = encode_entities($bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_cosii', 'COSII marker data') : 'COSII marker data') if $dir eq 'COSII';
        if ($dir eq 'user_requests') {
            my $custom = $bulk_ftp_i18n ? $bulk_ftp_i18n->p('global.bulk.input.ftp_user_requests', 'Custom-generated datasets for individual users (mail special requests to %{email})', { email => '__SGN_BULK_FEEDBACK__' }) : 'Custom-generated datasets for individual users (mail special requests to __SGN_BULK_FEEDBACK__)';
            $custom = encode_entities($custom);
            my $feedback_link = '<a href="mailto:sgn-feedback@sgn.cornell.edu">sgn-feedback</a>';
            $custom =~ s/__SGN_BULK_FEEDBACK__/$feedback_link/;
            $desc = $custom;
        }
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
	<i>$bulk_ftp_note_label</i> $bulk_ftp_access
HTML

}

=head1 BUGS

  None known.

=head1 AUTHORS

  Lukas Mueller, Caroline Nyenke, Alexander Naydich and Matthew Crumb

=head1 SEE ALSO

  /bulk/download.pl
  /bulk/display.pl

=cut
