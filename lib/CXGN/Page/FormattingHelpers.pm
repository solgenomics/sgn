package CXGN::Page::FormattingHelpers;
use strict;
use CXGN::Tools::List;
use warnings;
use Carp;
use POSIX;
use HTML::Entities;
use Storable qw/dclone/;
use Config::General;

use JSON::Any;
my $json = JSON::Any->new;

use CXGN::Tools::List qw/max all/;
use CXGN::Tools::Text qw/commify_number/;

use CXGN::MasonFactory;
use CXGN::Scrap;

=head1 NAME

CXGN::Page::FormattingHelpers - helper functions for formatting
HTML in an attractive and uniform way across our many pages

=head1 SYNOPSIS

    #somewhere in a mod_perl script on the SGN site....
    use CXGN::Page::FormattingHelpers qw/  page_title_html
                                           info_section_html  /;

    print page_title_html('Making a Great SGN Page');

    print blue_section_html('SGN Page Guidelines',<<EOH);
    <ol>
      <li>Always use the FormattingHelpers module!
      </li>
      <li>Using HTML helper functions is the easiest way to ensure
          that your page fits in with the look of the rest of the site.
      </li>
    </ol>
EOH

    print info_section_html( title => 'Search Again',
                             contents => my_search_form_html(),
                           );


=head1 FUNCTIONS

All functions are EXPORT_OK.


=cut

BEGIN {
    our @ISA = qw/Exporter/;
    use Exporter;
    our $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;
    our @EXPORT_OK =
      qw/  blue_section_html                    html_optional_show
      newlines_to_brs                      html_break_string
      html_string_linebreak_and_highlight  page_title_html
      tabset  modesel                      info_table_html
      toolbar_html                         truncate_string
      simple_selectbox_html                columnar_table_html
      hierarchical_selectboxes_html        numerical_range_input_html
      conditional_like_input_html          info_section_html
      tooltipped_text                      html_alternate_show
      multilevel_mode_selector_html        commify_number
      simple_checkbox_html
      /;
}
our @ISA;
our @EXPORT_OK;

=head2 blue_section_html

    DEPRECATED DEPRECATED DEPRECIATED DEPRECATED DEFENESTRATED DEPRECATED
         This is now a special case of info_section_html().

    Returns HTML for a page section with a standard SGN header
    and indented content.
    Args: HTML string containing the section title,
          (optional) HTML string containing the sections second title
          HTML string containing the section content

    Returns: HTML for an SGN-style page section

=cut

sub blue_section_html {
    if ( @_ == 3 ) {
        info_section_html(
            title    => shift,
            subtitle => shift,
            contents => shift,
        );
    }
    else {
        info_section_html(
            title    => shift,
            contents => shift,
        );
    }
}

=head2 info_section_html

  Usage: my $section_html =
           info_section_html( title         => 'Search Results',
                              subtitle      => '3 matches',
                              empty_message => 'No matching monkeys found',
                              is_subsection => 0,
                              contents      => <<EOHTML);
  <ul><li>chimpanzee</li><li>bonobo</li><li>rob</li></ul>
  EOHTML
  Desc : return a piece of html that formats the given
         content for display as a section of a detail page
  Ret  : string of html to make a pretty page section
  Args : named argument list, as:
      ( title         => 'main title of the section',
        contents      => 'HTML content this section will contain',
        subtitle      => (optional) 'secondary title of the section',
        empty_message => (optional) 'The message that should be displayed to the user when
                          the section is empty', default 'None'
        is_empty      => (optional) if true, forces this info_section to be drawn in the empty
                         state, content will not be shown.
        is_subsection => (optional) if true, renders this section with sub-section styles,
	id         => (optional) collapsible_id for the collbpsible javascript div. Default "sgnc" . int(rand(10000)
        collapsible => (optional) if true, this section is collapsible.  default false.
        collapsed   => (optional) if true, this section should be shown initially collapsed.  default false.
        align       =>
      )
  Side Effects: none

=cut

sub info_section_html {
    return CXGN::MasonFactory->bare_render( '/page/info_section.mas', @_ );
}

=head2 page_title_html

    Returns HTML for a standard SGN page title.

    Args: text of the page title
    Returns: page title HTML

=cut

sub page_title_html {
    my ($title) = @_;
    return CXGN::MasonFactory->bare_render( '/page/page_title.mas',
        title => $title );
}

=head2 html_optional_show

    given a unique item ID, an item title, and the HTML of the item,
    makes a "Show $itemtitle" link that turns the display of the item
    on as well as a 'Hide' link to hide it again

    Args: unique identifier for the item on the page (no whitespace),
          title of the item to hide or show OR ['text to show when hidden','text to show when shown']
          html contents to be hidden or shown,
          (optional) boolean whether it should be shown by default,
          (optional) css class name for the <a> and <div> elements.  Both elements will
                     always be of class [class], but when the show is active (open),
                     the class [class]_active will be added to the <a> and <div>
                     Default 'optional_show'
   Returns: HTML

=cut

sub html_optional_show {
    my ( $itemid, $itemtitle, $itemHTML, $default_show_item, $class_name ) = @_;

    return CXGN::MasonFactory->bare_render( '/page/optional_show.mas',
        id => $itemid,
        title => $itemtitle,
        content => $itemHTML,
        default_show => $default_show_item,
        class => $class_name,
    );
}

=head2 html_alternate_show

    given a unique item ID, an item title, and the HTML of two items,
    makes a "Show $itemtitle" link that turns the display of the second item
    on and the display of the first item off, as well as a 'Hide' link to hide it again

    Args: unique identifier for the item on the page (no whitespace),
          title of the item to hide or show OR ['text to show when hidden','text to show when shown']
          html contents to be shown, html contents to replace the first one.
    Returns: HTML

=cut

sub html_alternate_show {
    my ( $itemid1, $itemtitle1, $itemHTML1, $itemHTML2 ) = @_;

    my ( $click_style, $start_style ) =
      0
      ? (
        ' class="optional_show" style="display:none"',
        ' class="optional_show"'
      )
      : (
        ' class="optional_show"',
        ' class="optional_show" style="display:none"'
      );
    my ( $hiddentitle1, $showntitle1 ) =
      ref($itemtitle1) ? (@$itemtitle1) : ( $itemtitle1, $itemtitle1 );

    return <<END_HTMLD;
    <a name="$itemid1"></a>
    <div id="click$itemid1" $click_style>
    <a class="optional_show" onclick="document.getElementById('start$itemid1').style.display='block';document.getElementById('click$itemid1').style.display='none';">$hiddentitle1</a>
    $itemHTML1
    </div>
    <div id="start$itemid1" $start_style>
    <a class="optional_show_active" onclick="document.getElementById('click$itemid1').style.display='block';document.getElementById('start$itemid1').style.display='none';">$showntitle1</a>
    $itemHTML2
    </div>
END_HTMLD

}

=head2 newlines_to_brs

    Given a string, replaces newlines with the given breaking string.
    Args: string, breaking string (default "<br />\n")
    Returns: broken HTML string

=cut

sub newlines_to_brs {
    my ( $string, $breaker ) = @_;
    $breaker ||= "<br />\n";
    $string =~ s/\n/$breaker/g;
    return $string;
}

=head2 html_break_string

    format a string with html line breaks at the specified width

    Args:  string to break,
           optional break width (default 50),
           optional break string (default "<br />\n")
    Returns: formatted HTML

=cut

sub html_break_string {
    my $seq   = shift;
    my $width = shift || 50;
    my $break = shift || "<br />\n";
    return '' unless $seq;
    return join( $break, ( $seq =~ /.{1,$width}/g ) );
}

=head2 html_string_linebreak_and_highlight

  args:  - string to format and break up,
         - array ref to pairs of start and end highlight regions as
         - [[start, end], [start, end], [start, end]],
         - CSS class of highlighting <span> elements
           (optional, default ='badseq'),
         - width in characters at which to break the string
           (optional, default = 50)
  returns: the complete formatted HTML string

=cut

sub html_string_linebreak_and_highlight {
    my ( $seq, $highlights_ar, $highlightclass, $breakwidth ) = @_;
    $highlightclass ||= 'badseq';
    $breakwidth     ||= 50;

    my $hstart_string = qq/<span class="$highlightclass">/;
    my $hend_string   = q|</span>|;

    my %hstarts;
    my %hends;

    #build highlight starts and ends hashes
    while ( scalar(@$highlights_ar) ) {
        my ( $hs, $he ) = @{ shift @$highlights_ar };
        croak "Highlight indexes array must have an even number of elements.\n"
          unless defined($he);

        #     my $hs = shift @$highlights_ar;
        #     my $he = shift @$highlights_ar;
        croak "Invalid highlight start index $hs.\n"
          unless $hs >= 0;

        ( $he >= 0 && $he >= $hs )
          || croak
          "Invalid highlight end index $he (highlight start was $hs).\n";
        $hstarts{$hs}++;
        $hends{$he}++;
    }

    my @splitseq = split '', $seq;
    my $retstr = '';

    my $linectr = 0;

    #get down wid da for loop
    for ( my $i = 0 ; $i < scalar(@splitseq) ; $i++ ) {
        $retstr .= $hstart_string x ( $hstarts{$i} || 0 );
        $retstr .= $splitseq[$i];
        $retstr .= $hend_string x   ( $hends{$i}   || 0 );
        if ( ++$linectr == $breakwidth ) {
            $retstr .= "<br />\n";
            $linectr = 0;
        }
    }
    return $retstr;
}

=head2 modesel

  args:    ( [ [url, HTML contents],
               [url, HTML contents],
               [url, HTML contents],
             ],
             index of currently selected mode, or undef if none
           )
  returns: a string of HTML for a set of tabs, which is actually an HTML
           table of class 'modesel', containing images and text to make
           pretty tabs

  You may find the CSS style a.modesel in sgn.css useful for formatting HTML
  links in mode selections.

  Note: tabset() is now an alias for modesel()

  Note II:  This thing now uses some javascript to change the button highlighting
            when the user clicks, rather than just when the next page loads.
            This turns out to make the interface feel way nicer and more responsive.
            If you mess with this function, make sure you check
            modesel_switch_highlight in /css/sgn.js

=cut

sub tabset { modesel(@_) }    #alias

sub modesel {
    my $ar       = shift;
    my $numcols  = @$ar * 4 + 1;
    my $selected = shift;

    if( $selected =~ /\D/ ) {
        my $found = undef;
        for( my $i = 0; $i < @$ar; $i++ ) {
            my $link = $ar->[$i][0];
            if( $selected =~  m! ^ $link (?: $ | [\?/] ) !x ) {
                $found = $i;
                last;
            }
        }
        $selected = $found;
    }

    my @buttons =
      map {
        {
            id       => 'mb' . our $_unique_modesel_button_counter++,
            contents => $_->[1],
            url      => $_->[0],
            onclick  => $_->[2] || '',
        }
      } @$ar;

    my $highlighted_id =
      defined($selected) && $selected >= 0 ? $buttons[$selected]{id} : '';

    foreach my $button (@buttons) {
        my $bid = $button->{id};
        my $sel = $bid eq $highlighted_id ? '_hi' : '';

        my $tablecell = sub {
            my ( $leaf, $content ) = @_;
	    #qq|    <td id="${bid}_${leaf}" class="modesel_$leaf$sel">$content</td>\n|;
	    qq|<li style="margin:2px -4px" id="${bid}_${leaf}">$content</li>|;
        };

        $button->{contents} = [
           # $tablecell->(
           #     'tl', qq|<img src="/img/modesel_tl$sel.gif" alt="" />|
           #   )
           #   . $tablecell->( 't', qq|| )
           #   . $tablecell->(
           #     'tr', qq|<img src="/img/modesel_tr$sel.gif" alt="" />|
           #   ),
           # $tablecell->(
           #     'l', qq|<img src="/img/modesel_l$sel.gif" alt="" />|
           #   )
              $tablecell->(
                'c',
#qq|<a class="modesel$sel" onclick="CXGN.Page.FormattingHelpers.modesel_switch_highlight('$highlighted_id','$bid'); $button->{onclick}" href="$button->{url}">$button->{contents}</a>|
		qq|<button class="btn btn-xs modesel$sel" onclick="location.href='$button->{url}';">$button->{contents}</button>|
              )
           #   . $tablecell->(
           #     'r', qq|<img src="/img/modesel_r$sel.gif" alt="" />|
           #   ),
           # $tablecell->(
           #     'bl', qq|<img src="/img/modesel_bl$sel.gif" alt="" />|
           #   )
           #   . $tablecell->( 'b', qq|| )
           #   . $tablecell->(
           #     'br', qq|<img src="/img/modesel_br$sel.gif" alt="" />|
           #   ),
        ];
    }

    #my $spacer    = qq{    <td class="modesel_spacer"></td>\n};
    my $spacer    = qq{};
    my $tabs_html = join(
        "\n",
        (
            map { "  $_  " } (
                join( $spacer, ( map { $_->{contents}[0] ? $_->{contents}[0] : '' } @buttons ) ),
                join( $spacer, ( map { $_->{contents}[1] ? $_->{contents}[1] : '' } @buttons ) ),
                join( $spacer, ( map { $_->{contents}[2] ? $_->{contents}[2] : '' } @buttons ) ),
            )
        )
    );
    return <<EOH;
<center>
<!--<table class="modesel" summary="" cellspacing="0">-->
<ul class="list-inline">
$tabs_html
</ul>
<!--</table>-->
</center>
<hr class="modesel" />
EOH

}

=head2 simple_selectbox_html

  args:    - hash-style list as:
                     name     => 'the name of the variable',
                     choices  => [array of choices],
                     selected => (optional) the selected value (from choices), either
                                 single value or listref (for multiple select box),
                     selected_params => (optional) any additional HTML parameters to be attached
                                to the selected option as a string ( 'hidden' ),
                     multiple => (optional) anything true here makes it a multiple-select
                                 box
                     live_search => (optional) anything true here adds a live-search to the select
                                 box
                     id       => (optional) a specific HTML id to be given to this <select>
                     params   => (optional) any additional HTML parameters to be attached to the <select> tag,
                                     either as a hashref ( { onchange => "alert('foo')" } )
                                     or as a string ( 'onchange="alert('foo')" )
                     label    => (optional) html string to put inside a <label> </label> preceding the select box
  returns: a string of HTML for a select box input


  The choices can each either be a simple string, in which case the
  value returned and the visible text will be the same, or they can be
  an array ref as ['value','visible text'].  If you want grouped
  select options (with optgroup tags), pass strings prefixed with two
  underscores to for group names, like:

  [  '__Group 1',
     choices,
     [choiceval, choicename],
     ...,
     '__Group 2',
     choices,
     ...
  ]

=cut

sub simple_selectbox_html {
    my %params = @_;
    my $retstring;

    $params{choices} && ref( $params{choices} ) eq 'ARRAY'
      or confess "'choices' option must be an arrayref";

    $params{multiple} = $params{multiple} ? 'multiple="1"' : '';

    $params{id} ||= "simple_selectbox_" . ++our $__simple_selectbox_ctr;
    my $id = qq|id="$params{id}"|;

    #print out the select box head
    if ( ref $params{params} ) {
        $params{params} = join ' ',
          map { qq|$_="$params{params}{$_}"| } keys %{ $params{params} };
    }
    $params{params} ||= '';
    $params{name}   ||= '';
    my $data_related = $params{data_related} ? "data-related=".$params{data_related} : '';
    my $size = $params{size};
    $retstring = qq!<select class="form-control" $id $data_related $params{multiple} $params{params} name="$params{name}"!;
    if ($size) {
        $retstring .= qq!size="$params{size}"!;
    }
    $retstring .= qq!>!;
    $retstring =~ s/ +/ /;    #collapse spaces

    my $in_group = 0;
    if ($params{default}){
        my $default = $params{default};
        $retstring .= qq{<option title="$default" value="$default" disabled>$default</option>};
    }
    foreach ( @{ $params{choices} } ) {
        no warnings 'uninitialized';
        if ( !ref && s/^__// ) {
            $retstring .= qq{</optgroup>} if $in_group;
            $in_group = 1;
            $retstring .= qq{<optgroup label="$_">};
        }
        else {
	    my @selected = ();
	    my $selected = '';

            my ( $name, $text ) = ref $_ ? @$_ : ( $_, $_ );

	    if (defined($params{selected}) && !ref($params{selected})) {
		@selected = ( $params{selected} );
	    }
	    elsif (ref($params{selected})) {
		@selected = @{$params{selected}};


	    }

	    foreach my $s (@selected) {
		if (defined($s) && ($s eq $name)) {
		    $selected = ' selected="selected" ';
		    last();
		}
	    }
	    $retstring .= qq{<option title="$text" value="$name"$selected $params{selected_params}>$text</option>};
	}
    }
    $retstring .= qq{</optgroup>} if $in_group;
    $retstring .= "</select>\n";

    if ( $params{label} ) {
        $retstring =
          qq|<label for="$params{id}">$params{label}</label> $retstring|;
    }
    return $retstring;
}

=head2 simple_checkbox_html

=cut

sub simple_checkbox_html {
    my %params = @_;
    my $retstring = '<div class="panel panel-default"><div class="panel-body">';

    $params{choices} && ref( $params{choices} ) eq 'ARRAY'
      or confess "'choices' option must be an arrayref";

    $params{multiple} = $params{multiple} ? 'multiple="1"' : '';

    #print out the select box head
    if ( ref $params{params} ) {
        $params{params} = join ' ',
          map { qq|$_="$params{params}{$_}"| } keys %{ $params{params} };
    }
    $params{params} ||= '';
    $params{name}   ||= '';
    my $data_related = $params{data_related} ? "data-related=".$params{data_related} : '';

    my @selected = $params{selected} ? @{$params{selected}} : ();

    foreach ( @{ $params{choices} } ) {
        my ( $name, $text ) = ref $_ ? @$_ : ( $_, $_ );

        $retstring .= qq!<input type="checkbox" $data_related $params{multiple} $params{params} name="$params{name}" value="$name"!;

        foreach my $s (@selected) {
            if (defined($s) && ($s eq $name)) {
                $retstring .= ' selected="selected" ';
                last();
            }
        }
        $retstring .= qq!> $text<br/>!;
    }
    $retstring .= '</div></div>';

    return $retstring;
}

=head2 info_table_html

  Desc:
  Args:	an ordered list of value names => values
  Ret :	html to produce an attractive table laying out these values
  Used in:  clone_info.pl, clone_read_info.pl
  Example:

    my $info_html = info_table_html( 'Clone name' => $clone->name ,
                                     'Clone type' => $clone->clone_type_object->name,
                                     '__title'    => 'Clone '.$clone->name,
                                   );
    print $info_html;

  There are a few special value names that, if found in the list you pass,
  will modify the table this produces:

=over 12

=item __title

  If found, will produce a title on the simple info table.

=item __caption

  If found, will put the value of this field in the html caption of the table.

=item __tableattrs

  A string of HTML attributes (like qq{width="100%" height="200"}) that will be directly imbedded
  in the beginning <table> tag.

=item __multicol

  Maximum number of columns the data can appear in.  This function
  will attempt to fit the given data into the minimum number of rows
  while staying within the specified __multicol column limit.

  Default is __multicol => 1.

=item __border

  If true, draw a border around the table.  If false, do not.
  Default true.

=item __sub

  If true, this info_table is a subtable of another info_table.  Implies __border => 0,
  and uses sub_info_table styles.
  Default false.

=back

=cut

sub info_table_html {
    croak 'Must pass an even-length argument list' if scalar(@_) % 2;

    my %tabledata = @_;
    $tabledata{__multicol} ||= 1;
    $tabledata{__border} = 1 unless exists( $tabledata{__border} );

    #list of reserved field names
    my @reserved = qw/__title __caption __tableattrs __multicol __border __sub/;
    my %reserved = map { $_ => 1 } @reserved;    #hash them for quick lookup

    #get every other element from args to remember the order of the
    #table row names
    my $last = 0;
    my @field_order = map { $last = !$last; $last ? ($_) : () } @_;

    #take out the reserved field names from the field order list

    { no warnings 'uninitialized';
      @field_order = grep { !$reserved{$_} } @field_order;

    }

    #figure out the multi-column wrapping
    my @fields_layout;    #2-D array of where in the table each field name
                          #will be
    my $numcols = 0;
    {
        my $numfields   = @field_order;
        my $max_col_len = POSIX::ceil( $numfields / $tabledata{__multicol} );

        #  split the fields array into chunks (these will be columns)
        push @fields_layout, [] foreach ( 1 .. $max_col_len );
        while ( my @chunk = splice( @field_order, 0, $max_col_len ) ) {

            #     my $chunksize = @chunk;
            #     push @chunk,undef while($chunksize++ != $max_col_len);
            # for each chunk, add one of its elements to each of the rows
            push @$_, ( shift @chunk ) foreach (@fields_layout);
            $numcols++;
        }
    }

    my $tableattrs =
      $tabledata{__tableattrs}
      ? ' ' . $tabledata{__tableattrs}
      : '';

    my $sub = $tabledata{__sub} ? 'sub_' : '';

    my $noborder = $tabledata{__border} ? '' : '_noborder';
    no warnings 'uninitialized';
    join(
        "\n",
        (
#qq/<table summary="" class="${sub}info_table$noborder" $tableattrs>/,
qq/<table summary="" $tableattrs>/,

            $tabledata{__caption}
            ? (
qq!<caption class="${sub}info_table">$tabledata{__caption}</caption>!
              )
            : (),

            $tabledata{__title}
            ? (
qq!<tr><th class="${sub}info_table" colspan="$numcols">$tabledata{__title}</th></tr>!
              )
            : (),

            #turn each of the passed field=>value pairs into an html table row
            (
                map {
                    '<tr>'
                      . join( '',
                        map {
                            $_
                              ? <<EOH : '<td>&nbsp;</td><td>&nbsp;</td>' } @$_ ) . '</tr>' } @fields_layout ),
  <td class="${sub}info_table_field">
    <span class="${sub}info_table_fieldname">$_</span>
    <div class="${sub}info_table_fieldval">
      $tabledata{$_}
    </div>
  </td>
EOH

            #	'<tr><td colspan="2" class="${sub}info_table_lastrow"></td></tr>',
            '</table>',
        )
    );
}

=head2 truncate_string

  Desc:	truncate a string that might be long so that it fits in a manageable
        length, adding an arbitrary string (default '&hellip;') to the end if
        necessary.  If the string is shorter than the given truncation
        length, simply returns the string unaltered.  If the truncated
        string would have whitespace between the end of the given
        string and the addon string, drops that whitespace.
  Args: string to truncate, optional truncation length (default 50),
        optional truncation addon (default '&hellip;')
  Ret :	in scalar context:   truncated string
        in list context:     (truncated string,
			      boolean telling whether string was truncated)

  Example:
    truncate_string('Honk if you love ducks',6);
    #would return
    'Honk i&hellip;'

    truncate_string('Honk if you love cats',5);
    #would return
    'Honk&hellip;'
    #because this function drops trailing whitespace

=cut

sub truncate_string {
    my ( $string, $length, $addon ) = @_;
    $length ||= 50;
    $addon  ||= '&hellip;';

    return CXGN::Tools::Text::truncate_string( $string, $length, $addon );
}

=head2 columnar_table_html

  Desc: generates a table of results arranged in columns,
        with column headings and pretty alternating-color rows
  Args: ( headings => [ col name, col name,...],
          data     => [ [html, html, ...],
                        [ html,
                          { onmouseover => "alert('ow!')",
                            content => some html
                          },
                          html,
                          ...
                        ],
                        ...
                      ],
          __align      => 'cccccc...',
          __tableattrs => 'summary="" cellspacing="0" width="100%"',
          __border     => 1,

          __alt_freq   => 4,
          __alt_width  => 2,
          __alt_offset => 0,
        )
  Ret : string of HTML to prettily draw such a table
  Side Effects: none

  If you want, you can add arbitrary HTML attributes to the <tds>
  by passing hashrefs instead of HTML strings in the
  table data, such as { colspan => 3, content=>"blabla" }.

  Note about the use of colspan: If you are going to use colspan
  you need put after this element as many undef variables as colspan
  number. For example, if you want print:

  +------------+------------+-----------+-----------+----------+
  |   head1    |  head2     |   head3   |  head4    | head5    |
  +------------+------------+-----------+-----------+----------+
  |   test1    |  test2     |   test3               |  test4   |
  +------------+------------+-----------------------+----------+

  The code will be:

  columnar_table_html( headings => ['head1' ,
                                    'head2' ,
                                    'head3' ,
                                    'head4' ,
                                    'head5'
                                   ],
                       data     => [ [ 'test1',
                                       'test2',
                                       { colspan => 2, content => 'test3'},
                                       undef,
                                       'test4'
                                   ] ]
                      );

  Best used to display lists of query results and the like.
  __alt_width must be smaller than __alt_freq.

  To produce a heading that spans multiple consecutive columns, succeed
  the heading with undefs.  For example ['foo', undef, undef, 'bar'] will
  cause the table heading 'foo' to have a colspan of 3.

  There are a few special value names that, if found in the list you pass,
  will modify the table this produces:

=head3 __align

Specify the text alignments for each column.  Takes either
a string containing the alignments, like 'lccr' or 'llll', or an array
ref like ['l','c','c','r'].  Default is all columns centered.

=head3 __caption

Specify a <caption> to include in this table.

=head2 __alt_freq

If specified, sets the frequency of color change for alternating the
color of rows.  Setting this to 0 will disable alternate-row
highlighting.  Defaults to 0 for tables with fewer than 3 rows, 2
(every other row) for tables with 4-6 rows, and 4 (every 3rd row) for
tables with more than 6 rows.

=head3 __tableattrs

If set, will add whatever html you put here to the HTML as <table $params{__tableattrs}>

=head3 __border

Defaults to false.  If true, draws a border around the table.

=head3 __alt_width

Set the width of the alternate row highlighting.  Defaults to 1 for tables with fewer than 6 rows, 2 otherwise.

=head3 __alt_offset

Set the offset of the row highlighting.  Shifts all the row
highlighting up and down by the number placed here.  Defaults to 0.
Play with this if you don't like the exact placement of the
every-other-row highlighting.

=cut

sub columnar_table_html {
    my %params = @_;

    croak "must provide 'data' parameter" unless $params{data};

    my $noborder = $params{__border} ? '' : '_noborder';

    my $html;

    #table beginning
    #$params{__tableattrs} ||= qq{summary="" cellspacing="0" width="100%"};
    $params{__tableattrs} ||= qq{};
    $html .=
      #qq|<table class="columnar_table$noborder" $params{__tableattrs}>\n|;
      qq|<table class="table table-hover table-condensed" $params{__tableattrs}>\n|;

    if( defined $params{__caption} ) {
        $html .= "<caption class=\"columnar_table\">$params{__caption}</caption>\n";
    }

    unless ( defined $params{__alt_freq} ) {
        $params{__alt_freq} =
            @{ $params{data} } > 6 ? 4
          : @{ $params{data} } > 2 ? 2
          :                          0;
    }
    unless ( defined $params{__alt_width} ) {
        $params{__alt_width} = @{ $params{data} } > 6 ? 2 : 1;
    }
    unless ( $params{__alt_width} < $params{__alt_freq} ) {
        $params{__alt_width} = $params{__alt_freq} / 2;
    }
    unless ( defined $params{__alt_offset} ) {
        $params{__alt_offset} = 0;
    }

    #set the number of columns in our table.  rows will be padded
    #up to this with '&nbsp;' if they don't have that many columns
    my $cols =
      $params{headings}
      ? scalar( @{ $params{headings} } )
      : max( map { scalar(@$_) } @{ $params{data} } );

    ###figure out text alignments of each column
    my @alignments = do {
        if ( ref $params{__align} ) {
            ref( $params{__align} ) eq 'ARRAY'
              or croak
              '__align parameter must be either a string or an arrayref';
            @{ $params{__align} }    #< just dereference it
        }
        elsif ( $params{__align} ) {
            split '', $params{__align};    #< explode the string into an array
        }
        else {
            ('c') x $cols;
        }
    };
    my %lcr =
      ( l => 'align="left"', c => 'align="center"', r => 'align="right"' );
    foreach (@alignments) {
        if ($_) {
            $_ = $lcr{$_} or croak "'$_' is not a valid column alignment";
        }
    }

    #columns headings
    if ( $params{headings} ) {

        # Turn headings like this:
        #  [ 'foo', undef, undef, 'bar' ]
        # into this:
        # <tr><th colspan="3">foo</th><th>bar</th></tr>
        # The first column heading may not be undef.
        unless ( defined( $params{headings}->[0] ) ) {
            croak("First column heading is undefined");
        }
        $html .= '<thead><tr>';

        # The outer loop grabs the defined colheading; the
        # inner loop advances over any undefs.
        my $i = 0;
        while ( $i < @{ $params{headings} } ) {
            my $colspan = 1;
            my $align   = $alignments[$i] || '';
            my $heading = $params{headings}->[ $i++ ] || '';
            while (( $i < @{ $params{headings} } )
                && ( !defined( $params{headings}->[$i] ) ) )
            {
                $colspan++;
                $i++;
            }
            $html .=
"<th $align class=\"columnar_table$noborder\" colspan=\"$colspan\">$heading</th>";
        }
        $html .= "</tr></thead>\n";
    }

    $html .= "<tbody>\n";
    my $hctr                     = 0;
    my $rows_remaining_to_hilite = 0;
    foreach my $row ( @{ $params{data} } ) {
        if ( $params{__alt_freq} != 0
            && ( $hctr++ - $params{__alt_offset} ) % $params{__alt_freq} == 0 )
        {
            $rows_remaining_to_hilite = $params{__alt_width};
        }
        my $hilite = do {
            if ($rows_remaining_to_hilite) {
                $rows_remaining_to_hilite--;
                'class="columnar_table bgcoloralt2"';
            }
            else {
                'class="columnar_table bgcoloralt1"';
            }
        };

        #pad the row with &nbsp;s up to the length of the headings
        if ( @$row < $cols ) {
            $_ = '&nbsp;' foreach @{$row}[ scalar(@$row) .. ( $cols - 1 ) ];
        }
        $html .= "<tr>";
        for ( my $i = 0 ; $i < @$row ; $i++ ) {
            my $a = $alignments[$i] || '';
            my $c = $row->[$i]      || '';
            my $tdparams = '';
            if ( ref $c eq 'HASH' )
            {    #< process HTML attributes if this piece of data is a hashref
                my $d = $c;
                $c = delete $d->{content};
                if ( my $moreclasses = delete $d->{class} )
                {    #< add more classes if present
                    $hilite =~ s/"$/ $moreclasses"/x;
                }
                if ( exists $d->{'colspan'} )
                { ### If exists a colspan it should not add more columns so, we increase
                    ### the column count as many times as colspan
                    $i = $i + $d->{'colspan'};
                }
                $tdparams = join ' ',
                  map { qq|$_="$d->{$_}"| } grep { $_ ne 'content' } keys %$d;
            } elsif( ref $c eq 'ARRAY' ) {
                $c = "@$c";
            }
            $html .= "<td $hilite $tdparams $a>$c</td>";
        }
        $html .= "</tr>\n";

#    $html .= join( '',('<tr>',(map {"<td $hilite>$_</td>"} @$row),'</tr>'),"\n" );
    }
    $html .= "</tbody></table>\n";

    return $html;
}

=head2 commify_number

  Args: a number
  Ret : a string containing the commified version of it

  Example: commify_number(230400) returns '230,400'

=cut

# just handled by the importation of CXGN::Tools::Text::commify_number above

=head2 hierarchical_selectboxes_html

  Desc: make two select boxes, the contents of one of which is
        dependent on the selection in the first
  Args: hash-style list as:
        (  parentsel => ref to hash of args in format called for by
                        simple_selectbox_html(),
           childsel  => ref to hash of args in format called for by
                        simple_selectbox_html(),
           childchoices => [ [ option, option, option, ...],
			     [ option, option, option, ...],
			     [ option, option, option, ...],
                           ],
       )
  Ret : in scalar context: complete html of parent select box, child box, and javascript
        in list context:
          array of (parent select box, child select box, piece of
          javascript)

  WARNING: currently, the javascript won't work if the parent and
           child boxes are in different <form>s.  So either don't do
           that or make it work yourself and remove this warning.

=cut

sub hierarchical_selectboxes_html {
    my %params = @_;

    #assemble javascript datastructure holding the options for the contents of
    #our dependent select box
    our $sel_id;
    $sel_id++;
    my $seloptions = "seloptions$sel_id";
    $params{parentsel}{id} ||= "hsparent$sel_id";

    #  $params{childsel}{id} ||= "hschild$sel_id";

   #since this routine knows nothing about the form it's going to be used in,
   #we can't just use javascript to initialize the dependent select box to
   #its proper state based on the initial state of the parent select box.  Thus,
   #we figure out the proper state and initialize it to that statically in HTML
   #make sure that the child select box has the proper options initially for
   #whatever is selected in the parent select box
    my $i = 0;

   #index in the options array of the initially selected value in the parent box
    my $parent_selected_index = 0;
    foreach my $option ( @{ $params{parentsel}{choices} } ) {
        my $val = ref($option) ? $option->[0] : $option;
        if (   $params{parentsel}{selected}
            && $val eq $params{parentsel}{selected} )
        {
            $parent_selected_index = $i;
            last;
        }
        else {
            $i++;
        }
    }

    $params{childsel}{choices} = $params{childchoices}[$parent_selected_index]
      || [];

    #add an onChange event handler to the parent select box
    my $onchange =
qq|CXGN.Page.FormattingHelpers.update_hierarchical_selectbox(document.getElementById('$params{parentsel}{id}').selectedIndex,$seloptions,document.getElementById('$params{parentsel}{id}').form.$params{childsel}{name})|;

    if ( ref $params{parentsel}{params} ) {
        $params{parentsel}{params}{onchange} =
          $onchange . '; ' . $params{parentsel}{params}{onchange};
    }
    else {
        $params{parentsel}{params} =
          qq|onchange="$onchange;" | . ( $params{parentsel}{params} || '' );
    }

    #now make the html for the parent select box
    my $parentselbox = simple_selectbox_html( %{ $params{parentsel} } );

    #and for the child select box
    my $childselbox = simple_selectbox_html( %{ $params{childsel} } );

    #and the javascript enumerating the options and initializing the box
    my $options_js =

      #is an array
      "var $seloptions = [ "

      #of arrays
      . join(
        ",",
        (
            map {
                "\n                            [ "

                  #of options
                  . join(
                    ', ',
                    (
                        map {    #consisting of quoted names and values
                            ref $_
                              ? "new Option('$_->[1]','$_->[0]')"
                              : "new Option('$_','$_')"
                          } @$_
                    )
                  )
                  . "]"
              } @{ $params{childchoices} }
        )
      ) . "\n                           ];\n$onchange";

    #NOTE: a lot of the seemingly useless spaces above are for nice indentation
    #      in the output

    if (wantarray) {
        return ( $parentselbox, $childselbox, $options_js );
    }
    else {

        #and put them in context
        return <<EOH;
$parentselbox
$childselbox
<script language="JavaScript" type="text/javascript">
<!--
$options_js
-->
</script>
EOH
    }
}

=head2 numerical_range_input_html

  Args: hash-style list as:
     ( compare => [name, (optional) initial value],
       value1  => [name, (optional) initial value],
       value2  => [name, (optional) initial value],
       units   => html string describing the measurement units of these numbers,
     )
  Ret : html for a numerical range form input

=cut

my $numerical_range_input_unique_id = 0;

sub numerical_range_input_html {
    my %params = @_;

    3 == grep { $params{$_}[0] } qw/compare value1 value2/
      or croak
'Must provide names for each of the three form fields that make up a numerical range input';

    if ( defined( $params{compare}[1] ) ) {
        grep { $params{compare}[1] eq $_ } qw/gt lt bet eq/
          or croak
"Invalid initial value for comparison box, you passed '$params{compare}[1]'";
    }

    my $id = 'rangeinput' . $numerical_range_input_unique_id++;

    my $compare_select = simple_selectbox_html(
        name    => $params{compare}[0],
        choices => [
            [ 'gt',  'greater than' ],
            [ 'lt',  'less than' ],
            [ 'bet', 'between' ],
            [ 'eq',  'exactly' ],
        ],
        selected => $params{compare}[1],
        id       => $id . '_r',
        params =>
qq|onchange="CXGN.Page.FormattingHelpers.update_numerical_range_input('$id','$params{units}')"|
    );

    $params{value1}[1] = '' unless defined( $params{value1}[1] );
    $params{value2}[1] = '' unless defined( $params{value2}[1] );

    return <<EOH;
<div class="form-group"><div class="input-group col-sm-6"><span class="input-group-btn ">$compare_select</span><span class="input-group-btn"><input class="form-control" type="text" size="8" name="$params{value1}[0]" value="$params{value1}[1]" /></span></div>&nbsp;<span id="${id}_m">and</span>&nbsp;<span id="${id}_2" ><input size="8" type="text" name="$params{value2}[0]" value="$params{value2}[1]" />&nbsp;</span><span id="${id}_e">$params{units}</span></div>

<!--$compare_select&nbsp;<input type="text" size="8" name="$params{value1}[0]" value="$params{value1}[1]" />&nbsp;<span id="${id}_m">and</span>&nbsp;<span id="${id}_2" ><input size="8" type="text" name="$params{value2}[0]" value="$params{value2}[1]" />&nbsp;</span><span id="${id}_e">$params{units}</span>-->
<script language="JavaScript" type="text/javascript">
  CXGN.Page.FormattingHelpers.update_numerical_range_input('$id','$params{units}');
</script>
EOH

}

=head2 conditional_like_input_html

  Usage: my $html = conditional_like_input_html('matchtype','matchstring');
  Desc : makes html for a select box and text input field for a sort of
         "conditional like", which is a select box with 'starts with','ends with',
         'contains', and 'exactly', followed by a regular text input box
  Ret  : a string of html
  Args : name/id of these two elements (select will be called $name.'_matchtype',
           text input name and id will be called $name),
         (optional) initial value of the match type select box,
         (optional) initial value of the match string box
  Side Effects: none
  Example:

    my $condselect = conditional_like_input_html('locus_name','starts_with','YabbaMonkeyTumor', '30');
    #will return a select box set to 'starts_with' (displaying 'starts with', with no underscore),
    #and a text input initialized to 'YabbaMonkeyTumor' size = 30

=cut

sub conditional_like_input_html {
    my ( $name, $type_init, $string_init, $size ) = @_;

    #check arguments
    $name or croak 'must provide a name to conditional_like_input_html()';
    !$type_init
      or grep { $type_init eq $_ } qw/starts_with ends_with contains exactly/
      or croak <<EOC;
conditional_like_input_html: invalid initial match type $type_init, must be
starts_with, ends_with, contains, or exactly
EOC
    $string_init ||= '';
    $size        ||= '30';

    #make the select box
    my $matchtype_select = simple_selectbox_html(
        name     => $name . '_matchtype',
	id       => $name . '_matchtype',
	selected => $type_init,
        choices  => [
            'contains', [ 'starts_with', 'starts with' ],
            [ 'ends_with', 'ends with' ], 'exactly',
        ],
    );
    chomp $matchtype_select;   #remove newline, cause some browsers are idiotic.
                               #return the html
    return <<EOHTML;
<div class="form-group"><div class="input-group"><span class="input-group-btn" width="20%">$matchtype_select</span><span class="input-group-btn"><input class="form-control" name="$name" id="$name" value="$string_init" size="$size" type="text" placeholder="Type search here..."/></span></div></div>
EOHTML
}

=head2 tooltipped_text($text, $tooltip)

  Usage: my $html = tooltipped_text('Mouse over here for help',
                                    'help is on the way!'
                                   );
  Desc : Returns html for a span containing a tooltip and styled
         according to the span.help rules in sgn.css . Typically this
         includes a dashed underline and a question-mark cursor.
  Ret  : said string of html
  Args : text of span, text of tooltip,
         optional class of the <span> (defaults to 'help')
  Side Effects: none
  Example:

    my $html = tooltipped_text('Select a marker confidence','Marker confidences come from the MapMaker program and range from I to F(LOD3).');

   # This produces the following html:
   <span class="help" onmouseover="return escape('Marker confidences come from the MapMaker program and range from I to F(LOD3).')">Select a marker confidence</span>

=cut

sub tooltipped_text {

    my ( $text, $tooltip, $class ) = @_;

    $class ||= 'information';

    $tooltip =~ s/'/\\'/g;
    $tooltip =~ s!\n! !g;
    $tooltip = HTML::Entities::encode_entities($tooltip);

    return
qq{<span class="tooltipped $class" title="$tooltip">$text</span>};

}

=head2 multilevel_mode_selector_html

  Usage: my ($selector_html,@selected_levels) = multilevel_mode_selector_html($mode_config, $current_modename);
  Desc : function to do a multilevel mode selector
  Args : mode config string (in the Apache-like Config::General format, see below),
         full name of mode to draw as selected
  Ret  : list as ( selector html,
                   list of selected choices that have been selected in each of
                   the selection levels, based on the modename you passed,
                 )
  Side Effects: none
  Configuration format:

    Takes config information as a parsable string (you would probably
    want to write it as a heredoc).  Format is
    <modename>
      desc "Something"
      <submodename>
         desc "Something green"
      </submodename>
      <submodename2>
         desc "Something blue"
      </submodename2>
    </modename>

    Modes can be nested to arbitrary depth, but for depths greater
    than 3 the coloring might be rather difficult.

  Example:

     my $animal_selector_html = multilevel_mode_selector_html(<<EOC,$params{mode});
  <monkey>
     text "Monkey"
     <rhesus>
       text "Rhesus monkey"
       <from_madagascar>
         text "from Madagascar"
       </from_madagascar>
       <from_borneo>
         text "from Borneo"
       </from_borneo>
     </rhesus>
     <spider>
       text "Spider monkey"
       <malaysia>
         text "from Malaysia"
       </malaysia>
     </spider>
  </monkey>
  <dog>
    text "Dog"
    <wild>
      text "Wild dog"
      <dingo>
        text "a Dingo"
      </dingo>
      <coyote>
        text "coyote, sort of a wild dog"
      </coyote>
    </wild>
    <domesticated>
      text "In Your House"
      <mastiff>
        text "a huge Mastiff"
      </mastiff>
      <chihuahua>
        text "a little Chihuahua"
      </chihuahua>
    </domesticated>
  </dog>
  EOC

  # and now, if mode were to be 'monkey_rhesus_from_borneo', it would return
  # an HTML selector with Monkey > Rhesus monkey > from Borneo selected,
  # along with the list 'monkey','rhesus','borneo'.  Notice that underscores
  # are allowed in mode names.  It's smart enough to handle them correctly.

=cut

# IMPLEMENTATION OVERVIEW: first we parse

sub multilevel_mode_selector_html {
    my ( $config, $mode_name ) = @_;

    # parse our configuration if necessary
    my %conf =
      ref($config)
      ? %{ dclone($config) }
      : Config::General->new( -String => $config )->getall;

    ($mode_name) = %conf unless $mode_name;

    #warn "mode name is $mode_name\n";

    my $url_pattern = delete( $conf{url_pattern} ) || '?mode=%m';

    # these are the colors for the various mode selection levels
    my @colors = qw/ e6e6e6 c2c2ff 9797c7 333333 /;

#now use the above recursive function to find and set active => 1 appropriately for each mode level
    my @selected_modes;
    _ml_find_active( '', \%conf, '', $mode_name, \@selected_modes );

    #   use Data::Dumper;
    #   warn Dumper(\@selected_modes);

    #   use Data::Dumper;
    #   print  Dumper(\%conf);

#TODO: transform the conf into a more standard tree structure, which is easier to work with
#      and rewrite render code for it
    sub _xform_tree {
        my ( $def, $stem_name ) = @_;
        my @child_keys = _ml_child_keys($def);
        my @children;
        foreach (@child_keys) {
            my $mn = $def->{$_}->{ml_modename} =
              $stem_name ? $stem_name . '_' . $_ : $_;
            push @{ $def->{ml_children} }, $def->{$_};
            _xform_tree( delete $def->{$_}, $mn );
        }
    }
    _xform_tree( \%conf, '' );

    #   use Data::Dumper;
    #   die Dumper($categories);

    #now call the rendering function to recursively render each level
    #use Data::Dumper;
    #print Dumper(\%conf);
    return ( _ml_render( $url_pattern, 1, \%conf ), @selected_modes );
}

sub _ml_max_stratum_size {
    my ($tree) = @_;
    my @q      = ( $tree->{ml_children} );
    my $max    = 0;
    while (@q) {
        my $set = shift @q;
        $max = @$set if $max < @$set;
        push @q, $_->{ml_children} foreach @$set;
    }
    return $max;
}

# multilevel helper function:
# recursion to figure out which category is active in each level
sub _ml_find_active {
    my ( $curr_name, $curr_entry, $stem, $selected_mode_name, $active_levels ) =
      @_;

#warn join(',',($curr_name,$curr_entry,$stem,$selected_mode_name,$active_levels))."\n";
    my $level_name = $stem ? $stem . '_' . $curr_name : $curr_name;

    #warn "lev name is $level_name\n";
    my @child_keys = _ml_child_keys($curr_entry);
    if ( $selected_mode_name eq $level_name ) {
        $curr_entry->{ml_active} = 1;
        unshift @$active_levels, $curr_name;
        return 1;
    }
    elsif ( $selected_mode_name =~ /^$level_name/ ) {

        # might match one of our children
        #warn "hmm, check children\n";
        foreach my $child_name (@child_keys) {
            if (
                _ml_find_active(
                    $child_name, $curr_entry->{$child_name},
                    $level_name, $selected_mode_name,
                    $active_levels
                )
              )
            {

                #this returns true, one of my children must match
                unshift @$active_levels, $curr_name if $curr_name;
                $curr_entry->{ml_active} = 1;
                return 1;
            }
        }
    }

    #warn "that's all\n";
    return 0;
}

# check whether a given hash key is reserved
our %ml_reserved = map { $_ => 1 }
  qw/ ml_active ml_modename ml_children text sort_index ml_parent_id ml_container_id ml_id tooltip/;

sub _ml_is_reserved_key {
    return $ml_reserved{ +shift };
}

# return a list of unreserved keys in the given hash
sub _ml_child_keys {
    return grep !_ml_is_reserved_key($_), keys %{ +shift };
}

# multilevel helper function, recursively renders the HTML for the widget

our $ml_id_ctr = 0;

sub _ml_render {

    #my ($inactive_color,$active_colors,$level_count, %defs) = @_;
    my ( $url_pattern, $active, $tree ) = @_;

    #use Data::Dumper;
    #print Dumper($defs);

    #make a global id ctr for this whole multilevel widget
    $ml_id_ctr = 0;
    my $thisml = $ml_id_ctr++;

    #sorts a single set of children by sort_index, if present
    sub _sort_nodes {
        no warnings 'uninitialized';
        my ($nodelist) = @_;
        sort { $a->{sort_index} <=> $b->{sort_index} } @$nodelist;
    }

    # go through all the nodes and assign them an id, building an index
    # of the parent and children for each ID
    #use Data::Dumper;
    #  print Dumper($tree);
    my %id_based_index;

    sub _assign_ids_and_build_idx {
        my ( $self, $parent_id, $idx ) = @_;
        my $id = "ml_" . $ml_id_ctr++;
        $self->{ml_id}        = $id;
        $idx->{$id}           = $self;
        $self->{ml_parent_id} = $parent_id if $parent_id;
        _assign_ids_and_build_idx( $_, $id, $idx )
          foreach @{ $self->{ml_children} };
    }
    _assign_ids_and_build_idx( $_, '', \%id_based_index )
      foreach @{ $tree->{ml_children} };

    #warn Dumper($tree);
    #warn Dumper(\%id_based_index);

    my $button_html = '';

    my @active_button_ids;    #< one per depth, indexed by depth
    my @active_group_ids;     #< one per depth, indexed by depth
    my @traverse_queue =
      ( [ 0, _sort_nodes( $tree->{ml_children} ) ] )
      ; #< queue used for breadth-first traversal of the tree structure of the mode definitions
    my $max_stratum_size = _ml_max_stratum_size($tree);
    while (@traverse_queue) {
        my ( $depth, @node_set ) = @{ shift @traverse_queue };

        my $group_html      = '';
        my $group_is_active = 0;

        my $group_id = 'ml_' . $ml_id_ctr++;

        my $width_rel =
          sprintf( '%0.0f%%', 92 / $max_stratum_size * @node_set );
        foreach my $node_def (@node_set) {
            my $name     = $node_def->{ml_modename};
            my @subnodes = _sort_nodes( $node_def->{ml_children} );
            my $id       = $node_def->{ml_id};

            #record the depth in the node_def
            $node_def->{ml_depth} = $depth;

            my $title =
              $node_def->{tooltip} ? qq| title="$node_def->{tooltip}"| : '';
            my $link_class = "multilevel_modesel";
            if (@subnodes) {
                $link_class .= '_parent';
            }
            if ( $node_def->{ml_active} ) {
                $link_class .= '_active';
                $active_button_ids[$depth] = $id;
                $active_group_ids[$depth]  = $group_id;
                die 'assertion failed' if $group_is_active;
                $group_is_active = 1;
            }

            my $width = sprintf( '%0.0f%%', 92 / $max_stratum_size );
            my $href = qq| href="$url_pattern"|;
            $href =~ s/\%m/$name/;
            $group_html .=
qq|<td style="width: $width"><a id="$id" class="$link_class" onclick="ml_choose_$thisml(this.id); return false"$href$title>$node_def->{text}</a></td>|;

            #schedule children for this breadth-first traversal
            push @traverse_queue, [ $depth + 1, @subnodes ] if @subnodes;
        }

        my $active = $group_is_active ? '_active' : '';
        $button_html .=
qq|<div id="$group_id" class="multilevel_modesel_level_$depth multilevel_modesel$active"> <table style="width: $width_rel"><tr>$group_html</tr></table></div>\n|;
    }

    my $js_idx = $json->to_json( \%id_based_index );

    #   my $js_parents = objToJson(\%parent_ids);
    #   my $js_children = objToJson(do {
    #     my @rev_parents = reverse %parent_ids;
    #     my $children = {};
    #     while( my ($c,$p) = splice @rev_parents,0,2 ) {
    #       push @{$children->{$c}},$p;
    #     }
    #     $children
    #   });
    my $js_active_buttons = $json->to_json( \@active_button_ids );
    my $js_active_groups  = $json->to_json( \@active_group_ids );

    return <<EOH;
<script>
  var ml_idx_$thisml = $js_idx;
  var ml_active_buttons_$thisml = $js_active_buttons;
  var ml_active_groups_$thisml = $js_active_groups;

  //sets the link with the given id as highlighted and adds it to the ml_active_$thisml list
  function ml_apply_upward( tree, id, func ) {
    if( id ) {
      var el = document.getElementById(id);
      if( ! el ) {
        alert('id '+id+' not found');
      }
      ml_apply_upward(tree,tree[id].ml_parent_id,func)
      func(el);
    } else {
      return null;
    }
  }

  function ml_unset_active(depth,activelist) {
    var old_active = document.getElementById(activelist[depth]);
    if( old_active ) {
      //alert('unset '+old_active.id+', set '+el.id);
      old_active.className = old_active.className.replace(/_active\$/,'');
    }
  }

  function ml_set_active(el,depth,activelist) {
    for( var d=depth; d<activelist.length; d++) {
      //console.log('unset at depth '+d)
      ml_unset_active(d,activelist);
    }
    activelist[depth] = el.id;
m    el.className += '_active';
  }

  var ml_choose_$thisml = function( clicked_id ) {
    // set all the parent buttons and parent groups to active
    ml_apply_upward( ml_idx_$thisml, clicked_id,
     function(el) {
       var depth = ml_idx_${thisml}[el.id].ml_depth;
       ml_set_active(el.parentNode.parentNode.parentNode.parentNode.parentNode,depth,ml_active_groups_$thisml);
       ml_set_active(el,depth,ml_active_buttons_$thisml);
     });

    var mydepth = ml_idx_${thisml}[clicked_id].ml_depth;

    //now set this button's child group to active, if any
    var firstchild_rec = ml_idx_${thisml}[clicked_id].ml_children[0];
    if( firstchild_rec ) {
      //console.log('setting child div active');
      var child_elem = document.getElementById(firstchild_rec.ml_id);
      ml_set_active(child_elem.parentNode.parentNode.parentNode.parentNode.parentNode,mydepth+1,ml_active_groups_$thisml);
    }
  };
</script>

$button_html
EOH
}

###
1;    # do not remove
###

=head1 AUTHOR

Robert Buels and friends

=cut
