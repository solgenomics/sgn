package CXGN::Page::VHost::SGN;
use strict;
use warnings;

use CGI qw/ -compile :standard /;

use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People;
use CXGN::Apache::Request;
use CXGN::Apache::Error;
use CXGN::Page::FormattingHelpers;
use CXGN::Page::Toolbar::SGN;
use CXGN::People::Person;

use base qw | CXGN::Page::VHost |;

sub new {
    my $class = shift;
    my $dbh = shift;
    return $class->SUPER::new($dbh, @_);
}

sub html_head {
    my $self = shift;
    my ( $page_title, $extra_head_stuff ) = @_;
    $page_title       ||= 'Sol Genomics Network';
    $extra_head_stuff ||= '';

    my $ret_html = <<EOHTMLEIEIO;
<head>
  <title>$page_title</title>
  <meta http-equiv="content-type" content="text/html; charset=iso-8859-1" />
  <link rel="stylesheet" href="/css/sgn.css" type="text/css" />
  <link rel="search" type="application/opensearchdescription+xml" title="SGN Sol Search" href="/documents/sgn_sol_search.xml" />

  <script language="JavaScript" type="text/javascript">
    var docroot = '/';
    JSAN = {};
    JSAN.use = function() {};
    MochiKit = {__export__: false};
  </script>

  <script language="JavaScript" src="/css/sgn.js" type="text/javascript"></script>

  $extra_head_stuff
</head>
EOHTMLEIEIO
    return $ret_html;
}

sub bar_top {
    my $self     = shift;
    my $ret_html = '';
    my $welcome  = '';
    my $login_logout = '';

    our $vhost ||= SGN::Context->new;
    if ($vhost->get_conf('is_mirror')) { 
	$login_logout = qq | <a class="ghosted" style="text-decoration: none" title="Mirror site does not support login">log in</a> \| <a class="ghosted" style="text-decoration: none" title="Mirror site does not support new user">new user</span> |; 
    }
    else { 
	
	$login_logout = '<a class="toplink" style="text-decoration: underline" href="/solpeople/login.pl">log in</a> | 
<a class="toplink" style="text-decoration: underline" href="/solpeople/new-account.pl">new user</a>';
    }
#this code will not work when database connectivity is lost, or when these modules are broken.
#since the page header is highly important and we ALWAYS expect it to work, we must continue even when that other stuff is broken.
    eval {
        my $person_id = CXGN::Login->new($self->get_dbh())->has_session();
        if ($person_id) {

            my $person = CXGN::People::Person->new( $self->get_dbh(), $person_id );
            if ($person) {
                my $person_id = $person->get_sp_person_id();
                my $fname     = $person->get_first_name() || '';
                my $lname     = $person->get_last_name() || '';
                my $username  = "$fname $lname";
                my $user_type = $person->get_user_type() || '';
                $welcome      = "<b>$fname $lname</b>";
                $login_logout = <<HTML

(<a class="toplink" style="text-decoration: underline" href="/solpeople/login.pl?logout=yes">log out</a>)
<a class="mytools" href="/solpeople/profile/$person_id">My SGN</a>
HTML
            }
        }
    };
    if ($@) {
        CXGN::Apache::Error::notify(
            'cannot get user information from database');
        my $msg = $@;
        eval { $self->{page}->log($msg) };
    }

 #this controls whether the quick search shows times for the individual searches
  
    my $showtimes = $vhost->get_conf('production_server') ? 0 : 1;

    my $tb      = CXGN::Page::Toolbar::SGN->new();
    my $tb_html = $tb->as_html();

    my $devbar_style = "display:none";
    $ret_html .= <<EOHTMLEIEIO;
<!-- top links and quick search -->
<table id="siteheader" cellpadding="0" cellspacing="0">
<tr>
  <td rowspan="3" width="10" class="sunlogo">
    <a href="/"><img src="/img/sgn_logo_icon.png" width="70" height="69" border="0" alt="SGN Home" title="Sol Genomics Network Home" id="sgnlogo" /></a>
  </td>
  <td style="vertical-align: bottom">
    <a href="/"><img id="sgntext" src="/img/sgn_logo_text.png" width="230" height="21" border="0" alt="SGN Home" title="Sol Genomics Network Home" /></a>
  </td>
  <td width="50%" class="clonecart">
     <div id="clone_shoppingcart">
         <script language="JavaScript" type="text/javascript">
         count_clones();
         </script>
         clone(s) in cart (<a class="toplink" style="text-decoration: underline" href="/search/clone-order.pl">order</a>)
     </div>
  </td>
  <td class="toplink" width="50%">
          <a class="toplink" href="/">home</a>
        | <a class="toplink" href="/forum/topics.pl">forum</a>
        | <a class="toplink" href="/contact/form">contact</a>
        | <a class="toplink" href="/help">help</a>
		<span id="open_developer_toolbar" style="$devbar_style">
		| <a class="toplink" href="#" onclick="openDeveloperToolbar(); return false">devbar</a>
		</span>
  </td>
</tr>
<tr>
  <td colspan="3">
$tb_html
  </td>
</tr>
<tr>
  <td class="toplink" colspan="3" style="text-align: right">
    $welcome
    $login_logout
  </td>
</tr>
</table>

<script language="javascript" type="text/javascript">
<!--
  CXGN.Page.Toolbar.hideall();
  check_clonecart();
  startLoad();
-->
</script>

EOHTMLEIEIO
    return $ret_html;
}

sub toolbar {
    my $self    = shift;
    my $tb      = CXGN::Page::Toolbar::SGN->new();
    my $tb_html = $tb->as_html();

    return div({ id => 'site_toolbar' },
               comment('begin toolbar'),
               $tb_html,
               <<SCRIPT,
<script language="javascript" type="text/javascript">
  CXGN.Page.Toolbar.hideall();
  check_clonecart();
  startLoad();
</script>
<!--end toolbar-->
SCRIPT
               comment('end toolbar'),
              );
}

sub footer_html {

    #add a link to do xhtml validation on this page, if the viewer is on the developer subnet
    my ( undef, $cornell_client_name ) = CXGN::Apache::Request::client_name();
    my $validation_link = a({href => "http://validator.w3.org/check?uri=referer"},'[Validate this page]');

    return
        table({ id => 'pagefooter', width => '100%', cellpadding => 0, cellspacing => 0 },
              Tr(
td( {style => 'vertical-align: top; width: 370' },


table(
Tr( 
td(

                     # BTI logo with link
                     a({class => 'footer', href=> 'http://bti.cornell.edu/'},
                       img({ src => '/img/bti_logo_bw.png',
                             (map {$_ => 'Boyce Thompson Institute'} 'alt', 'title'),
                             width => 91, height => 70, border => 0,
                           }),
                      ),

                     # NSF logo with link
                     a({class => 'footer', href=> 'http://www.nsf.gov/'},
                       img({ src => '/img/nsf_logo.png',
                             (map {$_ => 'National Science Foundation'} 'alt', 'title'),
                             width => 77, height => 76, border => 0,
                           }),
                      ),

		   ),
),
Tr(
td(

                     # USDA CSREES logo with link
                     a({class => 'footer', href=> 'http://www.nifa.usda.gov/'},
                       img({ src => '/img/usda_nifa_h_2.jpg',
                             (map {$_ => 'USDA CSREES'} 'alt', 'title'),
                             width => 250, height => 44, border => 0,
                           }),
                      ),
                   ),
   

),
),
),

              #td('&nbsp;'),









                 td({style => 'text-align: right; font-size: smaller'},
                    <<EOHTML,
Cite SGN using <a class="footer" href="http://www.plantphysiol.org/cgi/content/abstract/138/3/1310"> Mueller et al. (2005).</a><br />
SGN is supported by the <a class="footer" href="/about/tomato_project/">NSF (\#0116076)</a>,<br />
<a class="footer" href="http://www.usda.gov">USDA CSREES</a> and hosted at the <a class="footer" href="http://bti.cornell.edu">Boyce Thompson Institute.</a><br />
<br />
Subscribe to the <a class="footer" href="http://rubisco.sgn.cornell.edu/mailman/listinfo/sgn-announce/">sgn-announce mailing list</a> for updates<br />
Send comments and feedback to <a class="footer" href="mailto:sgn-feedback\@solgenomics.net">sgn-feedback\@solgenomics.net</a><br />
<a href="/legal.pl">Disclaimer</a>
EOHTML
                   ),
                ),
             )

            .<<EOJS;
<!-- Google Analytics Code -->
<script src="http://www.google-analytics.com/urchin.js" type="text/javascript">
</script>

<script type="text/javascript">
_uacct = "UA-2460904-1";
//prevent js error on remote script load failure
if(typeof(urchinTracker) == "function"){
	urchinTracker();
 }
</script>
EOJS

}

###
1;    #do not remove
###
