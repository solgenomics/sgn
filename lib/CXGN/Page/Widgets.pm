#!/usr/bin/perl

package CXGN::Page::Widgets;

use strict;
use Carp;
#use CXGN::Login;
use CXGN::Cookie;
use CXGN::Page::UserPrefs;

use CXGN::Scrap;

=head1 NAME

CXGN::Page::Widget - helper functions for creating dynamic page elements such
as collapsible boxes, content swappers, and (moveable windows?).

=head1 SYNOPSIS

Built-in support for cookie-setting will give the user fine control over his or her 
SGN experience.  

The basic requirement for something to be a widget and not a FormattingHelper is
that it is dynamic.

=head1 FUNCTIONS

All functions are EXPORT_OK.

=over 4

=cut
BEGIN {
    our @ISA = qw/Exporter/;
    use Exporter;
    our $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;
    our @EXPORT_OK = qw/collapser swapper cycler/;
}
our @ISA;
our @EXPORT_OK;

=head2 collapser
	
	Returns a link and target content, where use of the link by the user
	will cause that content to collapse.


	Args:  Pass a hash reference with the following keys:
		linktext: text of the link, which will be prepended with (+) or (-)
		hide_state_linktext: text of link when hidden, if this is not specified, prepending will be used
		content: the content that you want to be hidden
		id: a unique id of your choice, which will serve as part of the user's cookie prefs
		linkstyle(optional): style of the controller link
		collapsed: default state is: already collapsed
		save: the state is savable to the user preference string.  If you use this feature,
			  you MUST add the id to the UserPref/Registry
		alt_href: go to page if javascript not working
		alt_target: target for alt_href

	Returns: ($link, $content), where $link is the html for the two consecutive <a>links</a> that make the button, and $content is the content you provided,
			wrapped with <span id='[provided id]'></span>
	
	Usage:  my ($link, $content) = collapser({	
									linktext => 'Heading', 
									linkstyle => 'text-decoration:none', 
									content => '<b>Hide this text on link-click</b>',
									collapsed => 0,
									save => 1,  #uses CXGN::UserPrefs, the "id" key on the 
                                                #next line would have to be in the Register
									id=>'hiderbox1'
								});
	print $link . "<br>" . $content;

=cut

sub collapser {
	my %args = %{ shift @_ };

	_check_args({
		args => \%args,
		valid => ['linktext', 'hide_state_linktext', 'linkstyle', 'content', 'id', 'collapsed', 'save', 'alt_href', 'alt_target'],
		required => ['linktext', 'content', 'id']
	});
	
	my ($linktext, $hide_state_linktext, $content, $id, $alt_href, $alt_target) 
		= ($args{'linktext'}, $args{'hide_state_linktext'}, $args{'content'}, $args{'id'}, $args{'alt_href'}, $args{'alt_target'});
	_check_id($id) if $args{save};

	my $state = "";
	$state = _get_pref($id) if $args{save};
	unless($state){
		if($args{collapsed}){
			$state = "hid"
		}
	}
	my ($on_display, $off_display) = ("", "");
	if($state eq "hid") { $on_display = "display:none;"; }
	else { $off_display = "display:none;" }

	my $linkstyle = $args{'linkstyle'} || "";
	$linkstyle =~ s/;\s*$//;
	$linkstyle .= ";";
	my ($hide_save_js, $show_save_js) = ("","");
	if($args{save}){
		$hide_save_js = "UserPrefs.set(\"$id\", \"hid\");UserPrefs.setCookie();";
		$show_save_js = "UserPrefs.set(\"$id\", \"dsp\");UserPrefs.setCookie();";
	}
	$hide_state_linktext ||= $linktext;
        no warnings 'uninitialized';
	my $link = <<HTML;
	<a class="collapser collapser_show" target="$alt_target" href="$alt_href" style="$linkstyle;$on_display" onclick=" 
		Effects.swapElements('${id}_offswitch', '${id}_onswitch'); 
		Effects.hideElement('${id}_content');
		$hide_save_js	
		return false;"
		id="${id}_offswitch"><img class="collapser_img" src="/documents/img/collapser_minus.png" />$linktext</a>
	<a class="collapser collapser_show" target="$alt_target" href="$alt_href" style="$linkstyle;$off_display" onclick="
		Effects.swapElements('${id}_onswitch', '${id}_offswitch'); 
		Effects.showElement('${id}_content');
		$show_save_js	
		return false;"
		id="${id}_onswitch"><img class="collapser_img" src="/documents/img/collapser_plus.png" />$hide_state_linktext</a>
HTML
	
	my $wrapped_content = qq|<span id="${id}_content" style="$on_display">$content</span>|;
	
	return ($link, $wrapped_content);
}

=head2 swapper
	
	Returns a link and target content, where use of the link by the user
	will cause that content to switch to alternate content (back-and-forth), which will be displayed in a consecutively hidden fashion
	
	Args:  
	
	Returns: ($link, $content), where $link is the html for the two consecutive <a>links</a> that make the button, and $content contains consecutive
			contents, one hidden, each wrapped with <span id=[provided id]:(def|alt)></span>
	Usage:  my ($link, $content) = swapper ({	
									linktext => 'Swap With Something Else',
									linktext_alt => 'Unswap me you savage!",
									linkstyle => 'text-decoration:none',
									content => 'I am the regular content',
									content_alt => 'I am the alternate content <a href='www.boycott-riaa.org'>Click me!</a>',
									id=>'swapper1' 
								});
	print $link . "<br>" . $content;

=cut

sub swapper {
	my %args = %{ shift @_ };
	#check arguments.  i think this is better for everyone except beth
	my @valid_keys = qw/linktext linktext_alt linkstyle content content_alt id/;
	my @required_keys = qw/linktext linktext_alt content content_alt id/;
	foreach my $argname (keys %args) {
  		grep {$_ eq $argname} @valid_keys
			or croak "Unknown argument name '$argname' to collapser";
	}
	foreach my $required (@required_keys) {
		grep {$_ eq $required} (keys %args)
			or croak "Required key: '$required' not specified";
	}
	my ($linktext, $linktext_alt, $content, $content_alt, $id) = ($args{'linktext'}, $args{'linktext_alt'}, $args{'content'}, $args{'content_alt'}, $args{'id'});
	my $linkstyle = $args{'linkstyle'} || "";
	_check_id($id);
	my $state = _get_pref($id);
	my ($def_display, $alt_display) = ("", "");
	if($state eq "alt") { $def_display = "display:none"; }
	else { $alt_display = "display:none"; }
	$linkstyle =~ s/;\s*$//g;
	
	my $link = <<HTML;
	<a href='#' style='$linkstyle;$def_display' onclick=' 
		Effects.swapElements("${id}_swap", "${id}_unswap"); 
		Effects.swapElements("${id}_def", "${id}_alt");
		UserPrefs.set("$id", "alt");
		UserPrefs.setCookie();
		return false;'
		id='${id}_swap'>$linktext</a>
	<a href='#' style='$linkstyle;$alt_display', onclick='
		Effects.swapElements("${id}_unswap", "${id}_swap"); 
		Effects.swapElements("${id}_alt", "${id}_def");
		UserPrefs.set("$id", "def");
		UserPrefs.setCookie();
		return false;'
		id='${id}_unswap'>$linktext_alt</a>
HTML

	my $wrapped_content = "<span id='${id}_def' style='$def_display'>$content</span><span id='${id}_alt' style='$alt_display'>$content_alt</span>";
	return ($link, $wrapped_content);
}

=head2 cycler
	
	Returns a link and target content, where use of the link by the user
	will cause that content to cycle amongst alternate content, which will be displayed in a consecutively hidden fashion
	
	Args:  a hash reference with the keys:
			id: a unique alphanumeric key
			linktexts: an array reference containing the various texts (or html) to display as the cycler button link
			linkstyle: (optional) a string containing common style for the link
			contents: an array reference containing the contents to be cycled, in HTML format
	
	Returns: ($link, $content), where $link is the html for the two consecutive <a>links</a> that make the button, and $content contains consecutive
			contents, all but one hidden, each wrapped with <span id='[provided id]:(1|2|3...)'></span>
	Usage:  my ($link, $content) = cycler({	
									linktexts => ['Go to state two','Go to state three', 'Back to first state']
									linkstyle => 'text-decoration:none',
									contents => ['It's good to be state one!!', 'It's my turn, now, bitches!', 'State three is fine with me!']
									id=>'cycler1' 
								});
	print $link . "<br>" . $content;

=cut

sub cycler {
	my %args = %{ shift @_ };
	my @valid_keys = qw/linktexts linkstyle contents id/;
	my @required_keys = qw/linktexts contents id/;
	foreach my $argname (keys %args) {
  		grep {$_ eq $argname} @valid_keys
			or croak "Unknown argument name '$argname' to collapser";
	}
	foreach my $required (@required_keys) {
		grep {$_ eq $required} (keys %args)
			or croak "Required key: '$required' not specified";
	}
	my ($linktexts, $contents) = ($args{'linktexts'}, $args{'contents'});
	unless(@{$linktexts}==@{$contents} && @{$linktexts}>1) { 
		croak "'linktexts' array (@{$linktexts}) must have more than one element AND be equal in length to 'contents' array (size:@{$contents})";
	}
	my $id = $args{'id'};
	
	my $linkstyle = $args{'linkstyle'} || "";
	my $cyclesize = @{$contents};
	
	my $link = "";
	my $count = 0;
	foreach my $linktext (@{$linktexts}) {
		my $next = $count+1;
		if($count >= ($cyclesize - 1)) {$next = 0;}
		$link .= <<HTML;
		<a href='#' style='$linkstyle' onclick=' 
		Effects.swapElements("${id}_$count", "${id}_$next"); 
		Effects.swapElements("${id}_control$count", "${id}_control$next");
		return false;'
		id='${id}_control$count'>$linktext</a>
HTML
		$count++;
	}

	my $wrapped_content = "";
	my $counter = 0;
	foreach my $content (@{$contents}) {
		$wrapped_content .= "<span id='${id}_$counter'>$content</span>";
		$counter++;
	}
	return ($link, $wrapped_content);
}

=head2 notifier

Provides the html notifier box that corresponds with the notify() command in jslib: CXGN.Base.  There should be one below every page toolbar, as far as I'm concerned ;)

Usage:  print CXGN::Page::Widgets::notifier({style => "yaddayadda", append_style => "background-color:#fa0"});

Note: You can only print one notifier per page, as there is a pair of standard elementIds: SGN_NOTIFY_BOX and SGN_NOTIFY_CONTENT

=cut

sub notifier {
	my $args = shift;
	my $style= $args->{style};
	$style ||= "width:350px; display:none; background-color:#fd6;border: #fa0 2px solid; text-align:left; padding:3px;";
	my $append_style = $args->{append_style};
	$append_style ||= "";

	return <<HTML;	
<div id='SGN_NOTIFY_BOX' style='${style}$append_style'>
<table style='width:100%; margin:0px; padding:0px;'><tr>
<td style='text-align:left'>
<a href='#' style='text-decoration:none' onclick='
	document.getElementById("SGN_NOTIFY_BOX").style.display = "none";
	document.getElementById("SGN_NOTIFY_CONTENT").innerHTML = "";'>(X)</a></td>
<td style='text-align:center'>
<span id='SGN_NOTIFY_CONTENT'>Notification Area</span>
</td>
<td style='text-align:right;visibility:hidden'>(X)</span> <!--balances close tick on left side so text appears centered-->
</tr></table>
</div>
HTML
}

# Dependent 'private' subroutines
sub _check_id {
	my $id = shift;
	die "No ID specified.  You cannot use the save option without specifying a registered ID" unless ($id);
	CXGN::Page::UserPrefs->validate_key($id);
}

sub _get_pref {
	#since Widgets will be used after headers are sent, we shouldn't use the UserPrefs handle, but we can use the cookie string that we got from the handle when this module is called.  It will be faster this way, anyhow.
	my $name = shift;
	my $cookie_string = CXGN::Cookie::get_cookie("user_prefs");	
	my ($value) = $cookie_string =~ /$name=([^:]+)/;
	return $value;
}

sub _check_args {
	my ($args) = shift;
	my @valid = @{$args->{valid}};
	my @required = @{$args->{required}};
	my $args_hash_ref = $args->{args};
	die "Key required: 'args'\n" unless($args_hash_ref);

	if(@valid){
		foreach my $argname (keys %{$args_hash_ref}) {
	  		grep {$_ eq $argname} @valid
				or croak "Unknown argument name '$argname' to collapser";
		}
	}
	if(@required) {
		foreach my $required (@required) {
			grep {$_ eq $required} (keys %{$args_hash_ref})
				or croak "Required key: '$required' not specified";
		}
	}
}

###
1;# do not remove
###

=head1 AUTHOR

Chris Carpita <csc32@cornell.edu> 

=cut
