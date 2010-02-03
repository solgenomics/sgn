

use strict;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::Contact;
use CXGN::VHost;

my $dbh = CXGN::DB::Connection->new();
my $login=CXGN::Login->new($dbh);
my $username;
my $useremail;
if(my $user_id=$login->has_session())
{
    my $user=CXGN::People::Person->new($user_id);
    $username=$user->get_first_name()." ".$user->get_last_name();
    $useremail=$user->get_private_email();
}
$username||='';
$useremail||='';
my $vhost=CXGN::VHost->new();
my $email_address_to_display=$vhost->get_conf('email');
my $page=CXGN::Page->new("contact.pl","john");
my($name,$email,$subject,$body,$referred,$tried_once)=$page->get_arguments('moniker','wheretosendelectroniccorrespondence','thingyouarewritingabout','alotofwords','referred','tried_once');
$name||=$username;
$email||=$useremail;
$subject||='';
$body||='';
$referred||='';
if($name and $email and $subject and $body)
{
    my $body=<<END_HEREDOC;
From:
$name <$email>

Subject:
$subject

Body:
$body

END_HEREDOC
    CXGN::Contact::send_email("[contact.pl] $subject",$body,'email',$email);
    $page->message_page("Thank you. Your message has been sent.");
}
my $message="All fields are required.";
if($tried_once)
{
    $message="<span class=\"alert\">$message</span>";
}
my $subject_section;
if($referred and $subject)
{
    $subject_section=<<END_HEREDOC;
<input type="hidden" name="thingyouarewritingabout" value="$subject" />
END_HEREDOC
}
else
{
    $subject_section=<<END_HEREDOC;
<tr><td align="left" valign="top">
<strong>Subject</strong>
</td><td align="left" valign="top">
<input type="text" name="thingyouarewritingabout" size="50" value="$subject" />
</td></tr>
END_HEREDOC
}
$page->header('Contact SGN','Contact SGN');
print<<END_HEREDOC;

<div class="center">$message</div>

<!-- this form exists for obfuscatory purposes only -->
<div style="display: none; visibility: hidden">
<form action="#">
<input type="text" name="name" />
<input type="text" name="email" />
<input type="text" name="subject" />
<input type="text" name="body" />
<input type="" name=""/>
</form>
</div>

<form method="post" action="#">
<input type="hidden" name="referred" value="$referred" />
<input type="hidden" name="tried_once" value="1" />
<div style="margin-left: 30px">
<table summary="" border="0" cellpadding="5" cellspacing="5">

<tr><td align="left" valign="top">
<strong>Your name</strong>
</td><td align="left" valign="top">
<input type="text" name="moniker" size="50" value="$name" />
</td></tr>

<tr><td align="left" valign="top">
<strong>Your email</strong>
</td><td align="left" valign="top">
<input type="text" name="wheretosendelectroniccorrespondence" size="50" value="$email" />
</td></tr>

$subject_section

<tr><td align="left" valign="top">
<strong>Body</strong>
</td><td align="left" valign="top">
<textarea cols="77" rows="12" name="alotofwords">$body</textarea>
</td></tr>

<tr><td colspan="2" align="center" valign="middle">
<input type="submit" value="Submit" />
</td></tr>

</table>
</div>
</form>

<dl>

<dt>
<strong>Email</strong>
</dt>
<dd><p>
<a href=\"mailto:$email_address_to_display\">$email_address_to_display</a>
</p></dd>

<dt>
<strong>Mailing address</strong>
</dt>
<dd><p>
Sol Genomics Network<br />
Boyce Thompson Institute for Plant Research<br />
Room 221<br />
Tower Road<br />
Ithaca, NY 14853<br />
USA<br />
Phone: (607) 255-6557<br />
</p></dd>

<dt>
<strong>Mailing list</strong>
</dt>
<dd><p>
To stay informed of developments around SGN you can subscribe to our <a href="http://rubisco.sgn.cornell.edu/mailman/listinfo/sgn-announce/">email list</a>. This is a relatively low volume list (a couple of messages/month).
</p></dd>

</dl>

END_HEREDOC
$page->footer();


