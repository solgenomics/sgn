
=head1 NAME

CXGN::Page::VHost

=head1 DESCRIPTION

An abstract object which helps CXGN::Page generate HTML pages. Subclass this object to add vhost-specific details (banners, toolbars, etc.) to pages. Important note: this is not and should not be a subclass of CXGN::Page.

=head1 AUTHOR

john binns - John Binns <zombieite@gmail.com>

=cut

package CXGN::Page::VHost;

use base qw | CXGN::DB::Object |;

use strict;
use warnings;

sub new {
    my $class=shift;
    my $dbh = shift;
    my $self = $class->SUPER::new($dbh);
    return $self;
}
sub html_head {
    my $self=shift;
    my($page_title, $extra)=@_;
    $page_title||='Sol Genomics Network';
    my $ret_html=<<EOHTMLEIEIO;
<head>
<title>$page_title</title>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />

<script language="JavaScript" type="text/javascript">
var docroot = '/';
JSAN = {};
JSAN.use = function() {};
</script>

$extra
</head>
EOHTMLEIEIO
    return $ret_html;
}

sub banner_logo {
    return'';
}

sub toolbar {
    return''; 
}

sub footer_html {
    return''; 
}

sub bar_top {
	return '';
}
###
1;#do not remove
###
