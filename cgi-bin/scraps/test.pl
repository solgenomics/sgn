use CXGN::Page;
use CXGN::Scrap;
use Carp;


## Everything a scrap does should be enclosed in an eval{} statement to catch errors.
eval {

my $scrap = CXGN::Scrap->new();

my %args = $scrap->get_all_encoded_arguments();

print<<HTML;

<html>
	<head><title>Scrap Test</title></head>
<body style='font-family:arial, sans-serif'>
This page is a scrap. It uses <b>CXGN::Scrap</b> as opposed to <b>CXGN::Page</b> to grab arguments.  This reduces overhead for things we don't need, such as standard SGN/Secretary page headers and footers.
<br><br>
The purpose of scraps is to receive arguments and perform database-related actions behind the scenes.  Generally, a scrap receives it's request via an <b>AJAX</b> method in <b>Javascript</b>. It should return some kind of simple textual reply that can be parsed by Javascript, but it doesn't really have to print anything at all.
<br><br>
This page wouldn't be an ideal scrap for Javascript-parsing since it contains html tagging and a little css, but you get the idea.
<br><br>
Try the following link to make sure the argument-getting is working:
<a href='test.pl?something=intheway&esta_bien=1&yadda=kostanza'>This page, w/ args</a>
&nbsp;&nbsp;
<a href='test.pl'>This page, no args</a>
<br><br>
Here is a list of arguments sent to this scrap:
HTML

while(my($key, $value) = each %args) {
	print "<br><em>Key:</em> $key => <em>Value:</em> $value";
}



print <<EOF;
<br><br>
Here is the code for this page.  Notice that all of the scrap methods are enclosed in eval{} tags, so that an AJAX request does not receive an SGN error page, but rather a more simple Error expression that is parse-able:

<pre>
use CXGN::Page;
use CXGN::Scrap;
use Carp;

## Everything a scrap does should be enclosed in an eval{} statement to catch errors.
eval {

my \$scrap = CXGN::Scrap->new();

my \%args = \$scrap->get_all_encoded_arguments();

print\<\<HTML;

<html>
	<head><title>Scrap Test</title></head>

... Everything you see above ...

Here is a list of arguments sent to this scrap:
HTML

while(my(\$key, \$value) = each \%args) {
	print "Key: \$key => Value: \$value";
}

print <<HTML;
</body></html>
HTML

## This is the preferred method for scraps to generate errors.  The standard SGN error page will be very difficult for Javascript to parse, in case a die, confess, or croak gets called.
if(\$@) {
	print "Error: \$@";
	##Everytime a scrap messes up, the AJAX request will begin with "Error:".  This allows JS-side error-catching to be handled fairly easily.
}

EOF

};
## This is the preferred method for scraps to generate errors.  The standard SGN error page will be very difficult for Javascript to parse, in case a die, confess, or croak gets called.
if($@) {
	print "Error: $@";
	##Everytime a scrap messes up, the AJAX request will begin with "Error:".  This allows JS-side error-catching to be handled fairly easily.
}

