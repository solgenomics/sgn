package CXGN::Page::Secretary;
use strict;

use CXGN::Login;
use CXGN::People;
use CXGN::Contact;
use CXGN::Cookie;
use CXGN::UserPrefs;
use CXGN::Apache::Request;
use CXGN::DB::Connection;
use CXGN::Page::Widgets;
use HTML::Entities;

use base('CXGN::Page');

sub new {
    my $class=shift;
	my $page_name = shift;
	my $author = shift;

	## I've decided to make the Secretary Page module create the default database handle for the Page-calling script
	
	my $self = $class->SUPER::new($page_name, $author);
	
	my $dbh = CXGN::DB::Connection->new();
	$dbh->do("SET SEARCH_PATH=tsearch2,public,sgn_people");
	$self->{dbh} = $dbh;

	my %evidefs;	
	my $evidef_q = $dbh->prepare("SELECT * FROM ara_evidef");
	$evidef_q->execute();
	while(my $row = $evidef_q->fetchrow_hashref) {
		$evidefs{$row->{code}} = $row->{description};
	}
	$self->{evicode2definition} = \%evidefs;
	$self->{hotlist_button_ids} = {};

	#The project name will still be SGN for cookie compatibility, but we use the Secretary Page/VHost file
	$self->{page_module}="CXGN::Page::VHost::Secretary";
	eval "require $self->{page_module}";
	if($@){
		die("Secretary VHost Page module ($self->{page_module}) not found");
	}
 	$self->{page_object}=$self->{page_module}->new($self->{dbh});
	$self->fetch_arguments();	

	return $self;
}

sub fetch_arguments {
	my $self = shift;
	(		$self->{gene}, $self->{searchQuery}, $self->{noCheck}, $self->{leftBound}, $self->{querySize}, 
			$self->{referenceGene}, $self->{prevQuery}, $self->{prevLB}, $self->{physicalMode}, $self->{username}, 
			$self->{pass}, $self->{logout}, $self->{newUser}, $self->{passRep}, $self->{email},
			$self->{fname}, $self->{lname}, $self->{org}, $self->{error404}
	) 
		= map { HTML::Entities::decode($_) }	
			$self->get_encoded_arguments 
			(
			'g', 'query', 'nocheck', 'lb', 'qsize', 
			'referenceGene', 'prevQ', 'prevLB', 'physicalMode', 'username', 
			'password', 'logout', 'newuser', 'passwordrep', 'email',
			'fname', 'lname', 'org', 'error404'
			);

	if(!($self->{leftBound} =~ /^\d+$/) || $self->{leftBound} <= 0) { 
		$self->{leftBound} = 1; 
	}

	$self->{gene} ||= "";
	$self->{searchQuery} ||= "";
	#$self->{searchQuery} =~ s/^\s*(.*?)\s*$/$1/;

	my $querySize = $self->{querySize};
	if(defined $querySize && (!($querySize =~ /^\d+$/) || $querySize<=0)) { undef $querySize }
	$self->{querySize} = $querySize;	
	
	my $physicalMode = 0;
	if($self->{referenceGene}) { $physicalMode = 1}
	$self->{physicalMode} ||= $physicalMode;
}

### User account functions #########################################

sub login {
	my $self = shift;
	my ($username, $password) = ($self->{username}, $self->{pass});
	$username ||= '';
	$password ||= '';
	my $login_controller = CXGN::Login->new({NO_REDIRECT=>1});
	my $login_info=$login_controller->login_user($username,$password);
	$self->{login_info} = $login_info;
	return $login_info;
}

sub logout {
	my $logout_controller = CXGN::Login->new({NO_REDIRECT=>1});
	$logout_controller->logout_user();
}

sub new_user {
	my $self = shift;	

	my ($first_name, $last_name, $username, $password, $confirm_password, $email_address)
		= ($self->{fname}, $self->{lname}, $self->{username}, $self->{pass}, $self->{passRep}, $self->{email});

	if ($username) {
	#
	# check password properties...
	#
	my @fail = ();
	if (length($username) < 7) {
	    push @fail, "Username is too short. Username must be 7 or more characters";
	  } else {
	    # does user already exist?
	    #
	      my $existing_login = CXGN::People::Login -> get_login($username); 
	
	      if ($existing_login->get_username()) { 
		  push @fail, "Username \"$username\" is already in use. Please pick a different username.";
	      }
	      
	  }
	  if (length($password) < 7) {
	    push @fail, "Password is too short. Password must be 7 or more characters";
	  }
	  if ("$password" ne "$confirm_password") {
	    push @fail, "Password and confirm password do not match.";
	  }
	  if ($password eq $username) {
	    push @fail, "Password must not be the same as your username.";
	  }
	  if ($email_address !~ m/[^\@]+\@[^\@]+/) {
	    push @fail, "Email address is invalid.";
	  }
	    

	  if (@fail) {
	    return new_user_fail(\@fail);
	  }
	
	  my $confirm_code = $self->tempname();
	  my $new_user = CXGN::People::Login->new();
	  $new_user -> set_username($username);
	  $new_user -> set_password($password);
	  $new_user -> set_pending_email($email_address);
	  $new_user -> set_confirm_code($confirm_code);
#	  $new_user -> set_disabled('unconfirmed account');
	  $new_user -> store();
	
	  #this is being added because the person object still uses two different objects, despite the fact that we've merged the tables
		my $person_id=$new_user->get_sp_person_id();
		my $new_person=CXGN::People::Person->new($person_id);
		$new_person->set_first_name($first_name) if ($first_name);
		$new_person->set_last_name($last_name) if ($last_name);
		$new_person->store();
 
		$self->{person_id} = $person_id;
		return "success";
	}
	else {
		return "Username not provided";
	}
}

sub new_user_fail {
	my ($fail_ref) = @_;

	my $fail_str = "";
	foreach ( @{$fail_ref} ) {
		$fail_str .= "<li>$_</li>\n"
	}

	return <<END_HEREDOC;

<table summary="" width=80% align=center>
<tr><td style='color:black'>
<p style='color:#dd4444'>Your account could not be created for the following reasons</p>

<ul>
$fail_str
</ul>
</td></tr>
<tr><td><br /></td></tr>
</table>
END_HEREDOC
 
}
	
sub set_hotlist {
	my $self = shift;
	unless($self->{hotlist}){
		$self->{hotlist} = $self->{page_object}->get_hotlist();
	}

	if($self->{hotlist}){
		$self->{hotlist_content} = $self->{hotlist}->get_item_contents();
	}
	return $self->{hotlist};
}

sub get_login_info {
	my $self = shift;
	
	my $just_logged_in = 0;  #we can't check a cookie that we just set, so use this to properly display page elements on first page-load of login
	my $login_warning = '';
	my $extra_notification = '';
	my $login_info_person_id = 0;
	my $login_info;
	
	
	if($self->{newUser}){
		$login_warning = $self->new_user();
		$login_info = $self->login();
		$extra_notification = "New account with the username \"$self->{username}\" created!";
	}
	elsif($self->{username}){
		$login_info = $self->login();
		if($login_info->{incorrect_password}) { $login_warning = "You provided an incorrect password for this account." }
		if($login_info->{account_disabled}) { 
			$login_warning =  "Your account has been disabled.  Please contact <a href='mailto:support\@sgn.cornell.edu'>support\@sgn.cornell.edu</a>";
		}
		if($login_info->{duplicate_cookie_string}) { $login_warning = "A duplicate cookie string has been issued (rare).  Please try again." }
		if($login_info->{logins_disabled}) { $login_warning = "Sorry, logins have been temporarily disabled on this system" }
		if(!$login_warning) { 
			$login_warning = "success";
			$login_info_person_id = $login_info->{person_id};
		}
	}

	# overrides username login_info handler, which has to remain in place to make warnings (i should change this)
	my $loginh = CXGN::Login->new({NO_REDIRECT=>1});
 	my $extra_warning;	
	if(my $sp_person_id = $loginh->has_session()){
		$login_info = $loginh->get_login_info();
		$self->{validUser} = 1;
	}
	if($login_warning eq "success") { 
		$login_warning = '';
		$just_logged_in = 1;
		$self->{validUser} = 1;
	}

	$self->{person_id} = $login_info->{person_id};
	$self->{cookie_string} = $login_info->{cookie_string};
	$self->{user_prefs} = $login_info->{user_prefs};

	if($login_warning) { $login_warning .= "<br>" }

	$self->{just_logged_in} = $just_logged_in;
	$self->{login_warning} = $login_warning;
	if($extra_notification) { $login_warning = $extra_notification }	

	if($self->{person_id}){
#makes sure that cookie and database user_pref string are current and agreeable on initial login or when loading any page.  This is important when the user changes a preference, then jumps to a page in which UserPrefs ISN'T used, so the database will stil be updated with the new client cookie string.
		my $prefh = CXGN::UserPrefs->new( $self->{dbh}, $self->{person_id} );
		$self->{user_prefs} = $prefh->get_user_pref_string(); 	
	}

	#logout is done last since we want to sync up the userprefs that were set before the logout button was clicked
	if($self->{logout}){
		$self->logout();
	}

		

	return $login_warning;
	
}

### CXGN::Page over-riding functions  #############
sub get_system_message {
	my $self = shift;
	my $system_message='';
	if(my $message_file=$self->{vhost_object}->get_conf('system_message_file'))
    {
        my $message_text=CXGN::Tools::File::file_contents($message_file);
        $system_message.="<span class=\"developererrorbox\">$message_text</span><br />";
    }
    unless($self->{vhost_object}->get_conf('production_server'))
    {
        my $connection_test=CXGN::DB::Connection->new_no_connect();
        $system_message.="<span class=\"developererrorbox\">Viewing the ".$connection_test->dbname." database on ".$connection_test->dbhost.", ".$connection_test->dbbranch." branch</span>\n";
    }
	else { die("This site is not ready to go live yet!");}

	return $system_message;
}

sub get_header {
	my $self = shift;	
#	$self->{request}->send_http_header("text/html");
	if($self->{content_title}){ $self->{page_title} .= ": " . $self->{content_title} }
			
	my $system_message = $self->get_system_message();
	my $login_warning = $self->get_login_info();
	
	my $login_panel = $self->{page_object}->login_panel($self->{gene}, $self->{searchQuery});

	my $html_head = $self->html_head();
	
	my $user_bar = $self->{page_object}->user_bar
									(
										$self->{gene}, $self->{searchQuery}, $self->{just_logged_in}, $self->{person_id}, $self->{error404}
									);
	my $body_tag = "<body>";

	my $notifier = CXGN::Page::Widgets::notifier();
	
	if($self->{content_title} =~ /Home/i) { $body_tag = "<body onload='document.getElementById(\"query_focus\").focus()'>" }
return<<HTML;
<html>
$html_head
$body_tag
<center>
<div id='userbar_container' style='width:100%'>
<table style='width:100%; margin-bottom:5px;'>
<tr>
	<td style='text-align:left'>
	$system_message
	</td>
	<td style='text-align:right'>
	$user_bar
	</td>
</tr>
</table>
</div>
<span id='login_warning' style='color:#dd4444; font-size:1.05em'>$login_warning</span>
$login_panel
</center>
<noscript>
<center>
<span style='font-size:0.9em; color:#990000'>
<a href='/documents/howtojs.html' style='color:#993355'><b>Javascript</b></a> (and cookies) must be enabled for logging in, hotlists, and dynamic effects
</span>
</center>
</noscript>
<center>
$notifier
</center>

<!--/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/| BEGIN PAGE CONTENT |/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/-->

HTML
}

sub header {  
	my $self = shift;
	($self->{page_title}, $self->{content_title}, $self->{extra_head_stuff}) = @_;
	unless($self->{page_title})
    {
    	$self->{page_title}=$self->{name};
    }
	print $self->get_header();	
}

sub footer {
	my $self = shift;  
	my $extra_footer_stuff = shift;	
	print $self->get_footer($extra_footer_stuff);
}

sub get_footer {
	my $self = shift;
	my $extra_footer_stuff = shift;
	$extra_footer_stuff||='';
return <<HTML;
</body>
<head>
<META HTTP-EQUIV="cache-control" CONTENT="no-store">
<META HTTP-EQUIV="cache-control" CONTENT="no-cache">
$extra_footer_stuff
</head>
</html>
HTML
}

sub jsan_render_includes {
	my ($self) = @_;
	return join("\n",map { qq|<script language="JavaScript" src="$_" type="text/javascript"></script>| } $self->_jsan->uris);
}

sub html_head
{
    my $self=shift;
	$self->jsan_use(qw|CXGN.Base CXGN.UserPrefs CXGN.Effects CXGN.Hotlist CXGN.secretary|);		
	my $jsanh = $self->_jsan();
	my $script_src = $self->jsan_render_includes();
	my $pathex = $jsanh->_class_to_file("CXGN.Effects");

	#my $script_src = $self->jsan_render_includes();
    return<<HTML;

<head><title>$self->{page_title}</title>

<link rel="stylesheet" href="/documents/inc/secretary.css" TITLE="Secretary Default" TYPE="text/css" />	
<link rel="icon" href="favicon.ico" type="image/x-icon" />
<link rel="shortcut icon" href="favicon.ico" type="image/x-icon" />

<META HTTP-EQUIV="cache-control" CONTENT="no-store" />
<META HTTP-EQUIV="cache-control" CONTENT="no-cache" />

<script language='javascript'>
	var JSAN = {};
	JSAN.use = function () {};

	//Global page variables for all scripts 
	var thispage = location.href;
	var agi = '$self->{gene}';
	var query = '$self->{searchQuery}';
	var user_id = '$self->{person_id}';
	var cookie_string = '$self->{cookie_string}';
	var user_pref_string = '$self->{user_prefs}';
	var just_logged_in = '$self->{just_logged_in}';
	if(just_logged_in == '1') location.href = thispage;

</script>
$script_src
<!--transitional script
$pathex
<script language='javascript' src='/documents/inc/secretary.js'></script>
-->
</head>

HTML
}

## Secretary page elements ##################
sub hotlist_button { 
	my $self = shift;
	my $agi = shift;
	my $buttonText = "";
	my $enum = 0;
	my $i = 0;
	while($self->{hotlist_button_ids}->{"$agi:$i"}){
		$i++;
	}
	$enum = $i;
	$self->{hotlist_button_ids}->{"$agi:$enum"} = 1;

	if(!$self->{hotlist_content}) { $self->set_hotlist() }
	if($self->{validUser}){
		my $in_hotlist = 0;
		foreach(@{$self->{hotlist_content}}){
			if ($_ eq $agi) { $in_hotlist = 1 }
		}
		if($in_hotlist) {
			$buttonText .= <<HTML;
			<img id='hotlistButton:$agi:$enum:imgAdd' src='/documents/img/secretary/hotlist_add.png' style='display:none' border=0 \>
			<img id='hotlistButton:$agi:$enum:imgRemove' src='/documents/img/secretary/hotlist_remove.png' style='display:inline' border=0 \>
			<a href='#' id='hotlistButton:$agi:$enum' 
				onclick='Hotlist.remove(this.id, \"$agi\"); return false;' 
				style='text-decoration:none'>Remove from Hotlist</a>
HTML
		}
		else {
			$buttonText .=  <<HTML;
			<img id='hotlistButton:$agi:$enum:imgAdd' src='/documents/img/secretary/hotlist_add.gif' style='display:inline' border=0 \>
			<img id='hotlistButton:$agi:$enum:imgRemove' src='/documents/img/secretary/hotlist_remove.gif' style='display:none'  border=0 \>
			<a href='#' id='hotlistButton:$agi:$enum' 
				onclick='Hotlist.add(this.id, \"$agi\");return false;' 
				style='text-decoration:none'>Add to Hotlist</a>
HTML
		}
		$buttonText .=  "&nbsp;<span id='hotlistWait:$agi:$enum' style='display:none'>...</span>";
	}
	else {
		$buttonText .= <<HTML
		<img src='/documents/img/secretary/hotlist_add.gif' border=0 \>
		<a href='#' style='text-decoration:none'
			onMouseOver='document.getElementById("hotlistGuest:$agi:$enum").style.display = "inline";'
			onMouseOut='document.getElementById("hotlistGuest:$agi:$enum").style.display = "none";'
			onclick='show_login();'>Add to Hotlist</a>&nbsp;

	<span id='hotlistGuest:$agi:$enum' style='display:none;color:#aa3333' > Login to use hotlists</span>
HTML
	}
	return $buttonText;
}	

sub navigation_info {
	my $self = shift;
	my $extraHREF = shift;
	my $querysize = $self->{querySize};
	my $lb = $self->{leftBound};
	my $searchquery = $self->{searchQuery};
	my $referenceGene = $self->{referenceGene};
	my $physicalMode = $self->{physicalMode};
	my $prevQuery = $self->{prevQuery};
	my $prevLB = $self->{prevLB};

	if(!$physicalMode){
		my $rb = $lb + 19;
		if((defined $querysize) && ($querysize < 20 || ($lb + 19) > $querysize)){
			$rb = $querysize;
		}
		my $navinfo = "<span style='font-size:1em'>Results <b>$lb</b> - <b>$rb</b> of ";
		if(defined $querysize) {$navinfo .= "<b>$querysize</b><br>"}
		else {$navinfo .= "<b>200+</b><br>"}
		return $navinfo;
	}
	else {

		my %lowerbounds = ( 1=>10, 2=>10, 3=>10,4=>0,5=>10,M=>0,C=>0);
		my %upperbounds = (1=>809, 2=>481, 3=>666, 4=>401, 5=>676, M=>14, C=>13);
		my ($currentpos) = $searchquery =~ /AT[1-5MC]G(\d{1,3})/;
		my ($refpos) = $referenceGene =~ /AT[1-5MC]G(\d{1,3})/;
		my ($chromchar) = $searchquery =~ /AT([1-5MC])G/;	
		my $lower = $lowerbounds{$chromchar};
		my $upper = $upperbounds{$chromchar};
		$lower = int($lower / 5) * 5;
		$currentpos = zeropadleft(int(zeropadright($currentpos)));
		$refpos = zeropadleft(int($refpos));
		my $navinfo = "<span style='font-size:1em'><b>$querysize</b> genes at the prefix <b>AT$chromchar" . "G$currentpos</b>";
		$navinfo .= "&nbsp; &nbsp;<b style='letter-spacing:0px'>(";
		my $i = $lower;
		while ($i <= $upper){
			my $pos = $i;
			if(abs($pos-$currentpos)<3 || (abs($upper-$currentpos)<3 && abs($upper-$pos)<5)) { 
				$pos = $currentpos;
				$navinfo .= "<span style='color:white;background-color:#000088'>|</span>";
			}
			elsif(abs($pos-$refpos)<3){
				$navinfo .= "<a title='" . zeropadleft($refpos) . "' href='query.pl?query=AT$chromchar" . "G" . zeropadleft($refpos);
				$navinfo .= "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'";
				$navinfo .= " style='text-decoration:none; background-color:#00AA00;font-weight:bold;color:white'>|</a>";	
			}
			elsif(abs($upper-$pos)<5){
				$navinfo .= "<a title='" . zeropadleft($upper) . "' href='query.pl?query=AT$chromchar" . "G" . zeropadleft($upper);
				$navinfo .= "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'";
				$navinfo .= " style='text-decoration:none;font-weight:bold;'>|</a>";	
			}
			else{
				$navinfo .= "<a title='" . zeropadleft($pos) . "' href='query.pl?query=AT$chromchar" . "G" . zeropadleft($pos);
				$navinfo .= "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'";
				$navinfo .= " style='font-weight:bold;text-decoration:none'>|</a>";	
			}
			$i += 5;
		}
		
		$navinfo .= ")</b></span>";
		return $navinfo;
	}
}

sub navigation_control {
	my $self = shift;
	my $prevReplace = shift;
	my $nextReplace = shift;
	my $extraHREF = shift;
	$extraHREF ||= "";
	my $lb = $self->{leftBound};
	my $query = $self->{searchQuery};
	my $nocheck = $self->{noCheck};
	my $referenceGene = $self->{referenceGene};
	my $physicalMode = $self->{physicalMode};
	my $querysize = $self->{querySize};
	my $prevQuery = $self->{prevQuery};
	my $prevLB = $self->{prevLB};
	my $navbar = "<span class='navbar'>";
	
	if(!$physicalMode){	#standard search-relevance navigation
		my $nextbound = 0;
	
		if($lb>1) {
			if(defined $querysize){
				$nextbound = $lb - 20;
				if($nextbound != 1 || 1) {
					$navbar .=  "<a href='query.pl?query=$query&lb=1&qsize=$querysize&nocheck=$nocheck&prevQ=$prevQuery&prevLB=${prevLB}${extraHREF}'>&laquo; First</a> &nbsp;";
				}
				else { 
					$navbar .= "<span style='color:grey'><u>&laquo; First</u> &nbsp;</span>";
				}
				$navbar .=  "<a href='query.pl?query=$query&lb=$nextbound&qsize=$querysize&nocheck=${nocheck}${extraHREF}'>&#8249; Prev</a> &nbsp;";
			}
			else{
				$nextbound = $lb - 20;
				if($nextbound != 1 || 1) { ##still deciding whether to grey-out if unnecessary
					$navbar .= "<a href='query.pl?query=$query&lb=1&nocheck=${nocheck}${extraHREF}'>&laquo; First</a> &nbsp;";
				}
				else { 
					$navbar .= "<span style='color:grey'><u>&laquo; First</u> &nbsp;</span>";
				}
				$navbar .= "<a href='query.pl?query=$query&lb=$nextbound&nocheck=${nocheck}${extraHREF}'>&#8249; Prev</a> &nbsp;";
			}
		
		}
		else {
			$navbar .= "<span style='color:grey'><u>&laquo; First</u> &nbsp;<u>&#8249; Prev</u> &nbsp;</span>";
		}
		
		if((!defined $querysize) || (($querysize - $lb) >= 20)){
			$nextbound = $lb + 20;
			my $lastbound;
			if(defined $querysize) {
				$navbar .= "<a href='query.pl?query=$query&lb=$nextbound&qsize=$querysize&nocheck=${nocheck}${extraHREF}'>Next &#8250;</a> &nbsp;";
			}
			else {
				$navbar .= "<a href='query.pl?query=$query&lb=$nextbound&nocheck=${nocheck}${extraHREF}'>Next &#8250;</a> &nbsp;"
			}
			if(!defined $querysize) {$lastbound = $lb + 200 }
			elsif($querysize%20) {$lastbound = $querysize - $querysize%20 + 1 }
			else {$lastbound = $querysize - 19 }
		
			if(defined $querysize)  {
				if($lastbound != $nextbound || 1){
					$navbar .= "<a href='query.pl?query=$query&lb=$lastbound&qsize=$querysize&nocheck=${nocheck}${extraHREF}'>Last &raquo;</a>";
				}
				else {
					$navbar .= "<span style='color:grey'><u>Last &raquo;</u></span>";
				}
			}
			else {
				$navbar .= "<a href='query.pl?query=$query&lb=$lastbound&nocheck=${nocheck}${extraHREF}'>Jump &raquo;</a>";
			}
		}
		else {
			$navbar .= "<span style='color:grey'><u>Next &#8250;</u> &nbsp;<u>Last &raquo;</u></span>";
		}
	}

	#gene pseudo-physical navigation 
	else {

		###Locus Boundaries####found by ordering locii in database#################
		# 		Lower Bounds:
		# 		1:01010
		# 		2:01031
		# 		3:01010
		# 		4:00010
		# 		5:01010
		# 		M:00010
		# 		C:00020
		# 		
		# 		Upper Bounds
		# 		1:80990
		# 		2:48160
		# 		3:66658
		# 		4:40100
		# 		5:67640
		# 		M:01410
		# 		C:01310
		my %lowerbounds = (1=>10, 2=>10, 3=>10,4=>0,5=>10,M=>0,C=>0);
		my %upperbounds = (1=>809, 2=>481, 3=>666, 4=>401, 5=>676, M=>14, C=>13);

		my ($chrom) = $query =~ /(AT[1-5MC]G)/;
		my ($chromchar) = $query =~ /AT([1-5MC])G/;
		my ($location) = $query =~ /AT[1-5MC]G(\d{1,3})/;
		
		if(length($location)<1) { $location .= "000" }
		elsif(length($location) == 1) { $location .= "00" }
		elsif(length($location) ==2) { $location .= "0" }
		$location = int($location);
		my $jumpleft = $location - 10;
		my $jumpright = $location + 10;
		my $next = $location + 1;
		my $prev = $location - 1;

		if($location > ($lowerbounds{$chromchar}+10)) {
			$navbar .= "<a href='query.pl?query=$chrom" . zeropadleft($jumpleft) . "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'>&laquo; (x10)</a>&nbsp;&nbsp;";
		}
		else {
			$navbar .= "<span style='color:grey'><u>&laquo; (x10)</u></span>&nbsp;&nbsp;";
		}
		if($location > $lowerbounds{$chromchar}) {
			$navbar .= "<a href='query.pl?query=";
			if($prevReplace){
				$navbar .= $prevReplace;
			}
			else {
				$navbar .= $chrom . zeropadleft($prev);
			}
			$navbar .= "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'>&#8249; Left</a>&nbsp;&nbsp;";
		}
		else {
			$navbar .= "<span style='color:grey'><u>&#8249; Left</u></span>&nbsp;&nbsp;";
		}
		if($location < $upperbounds{$chromchar}) {
			$navbar .= "<a href='query.pl?query=";
			if($nextReplace){
				$navbar .= $nextReplace;
			}
			else {
				$navbar .= $chrom . zeropadleft($next);
			}
			$navbar .= "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'>Right &#8250;</a>&nbsp;&nbsp;";
		}
		else {
			$navbar .= "<span style='color:grey'><u>Right &#8250;</u></span>&nbsp;&nbsp;";
		}
		if($location < ($upperbounds{$chromchar}-10)) {
			$navbar .= "<a href='query.pl?query=$chrom" . zeropadleft($jumpright) . "&referenceGene=$referenceGene&prevQ=$prevQuery&prevLB=${prevLB}$extraHREF'>(x10) &raquo;</a>	";
		}
		else {
			$navbar .= "<span style='color:grey'><u>(x10) &raquo;</u></span>";
		}
	}
	$navbar .= "</span>";
	return $navbar;
}	

## Helper routines ##########################
sub zeropadleft {
	my ($location) = @_;

	if(length($location)==1) {
		return "00" . $location;
	}
	elsif(length($location)==2) {
		return "0" . $location;
	}
	else {
		return "" . $location;
	}
}

sub zeropadright {
	my ($location) = @_;
	
	if(length($location)==1) {
		return $location . "00";
	}
	elsif(length($location)==2) {
		return $location . "0";
	}
	else {
		return $location . "";
	}
}


###
1;#do not remove
###

