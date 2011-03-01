=head1 NAME

t/integration/ajax.t - Integration tests for AJAXy stuff

=head1 DESCRIPTION

Tests for AJAXy stuff.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use Test::JSON;
use JSON::Any;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my $ajax_urls = {
    "/image/ajax/image_ajax_form.pl?action=view" =>
        '{"is_owner":0,"user_type":"user","html":" <table> <tr><td>Image Name:</td><td width=\"20\">&nbsp;</td><td><b>\n</b></td></tr>\n<tr><td>Image Description: </td><td width=\"20\">&nbsp;</td><td><b>\n</b></td></tr>\n<tr><td>Uploaded by: </td><td width=\"20\">&nbsp;</td><td><b><a href=\"/solpeople/personal-info.pl?sp_person_id=\">  </a> </b></td></tr>\n </table> ","editable_form_id":null,"error":"No object_id provided"}',
    "/image/ajax/image_ajax_form.pl?action=" =>
        '{"is_owner":0,"user_type":"user","html":"<form id =\"image_form\" method=\"get\" action=\"\"> <table> <tr><td>Image Name:</td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"name\" value=\"\" size=\"15\" />\n</td></tr>\n<tr><td>Image Description: </td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"description\" value=\"\" size=\"40\" />\n</td></tr>\n<tr><td>Uploaded by: </td><td width=\"20\">&nbsp;</td><td><a href=\"/solpeople/personal-info.pl?sp_person_id=\">  </a> </td></tr>\n <tr><td colspan=\"3\" align=\"center\">  <input type=\"hidden\" id=\"\" name=\"object_id\" value=\"0\" />  <input type=\"hidden\" id=\"\" name=\"action\" value=\"store\" />  </td></tr></table> </form>","editable_form_id":"image_form","error":"No object_id provided","login":1}',
    "/image/ajax/image_ajax_form.pl" =>
             '{"is_owner":0,"user_type":"user","html":"<form id =\"image_form\" method=\"get\" action=\"\"> <table> <tr><td>Image Name:</td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"name\" value=\"\" size=\"15\" />\n</td></tr>\n<tr><td>Image Description: </td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"description\" value=\"\" size=\"40\" />\n</td></tr>\n<tr><td>Uploaded by: </td><td width=\"20\">&nbsp;</td><td><a href=\"/solpeople/personal-info.pl?sp_person_id=\">  </a> </td></tr>\n <tr><td colspan=\"3\" align=\"center\">  <input type=\"hidden\" id=\"\" name=\"object_id\" value=\"0\" />  <input type=\"hidden\" id=\"\" name=\"action\" value=\"store\" />  </td></tr></table> </form>","editable_form_id":"image_form","error":"No object_id provided","login":1}',
    "/image/ajax/image_ajax_form.pl?action=edit" =>
        '{"is_owner":0,"user_type":"user","html":"<form id =\"image_form\" method=\"get\" action=\"\"> <table> <tr><td>Image Name:</td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"name\" value=\"\" size=\"15\" />\n</td></tr>\n<tr><td>Image Description: </td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"description\" value=\"\" size=\"40\" />\n</td></tr>\n<tr><td>Uploaded by: </td><td width=\"20\">&nbsp;</td><td><a href=\"/solpeople/personal-info.pl?sp_person_id=\">  </a> </td></tr>\n <tr><td colspan=\"3\" align=\"center\">  <input type=\"hidden\" id=\"\" name=\"object_id\" value=\"\" />  <input type=\"hidden\" id=\"\" name=\"action\" value=\"store\" />  </td></tr></table> </form>","editable_form_id":"image_form","error":"No object_id provided", "login":1}',
    "/image/ajax/image_ajax_form.pl?object_id=0" =>
     '{"is_owner":0,"user_type":"user","html":"<form id =\"image_form\" method=\"get\" action=\"\"> <table> <tr><td>Image Name:</td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"name\" value=\"\" size=\"15\" />\n</td></tr>\n<tr><td>Image Description: </td><td width=\"20\">&nbsp;</td><td> <input type=\"text\" id=\"\" name=\"description\" value=\"\" size=\"40\" />\n</td></tr>\n<tr><td>Uploaded by: </td><td width=\"20\">&nbsp;</td><td><a href=\"/solpeople/personal-info.pl?sp_person_id=\">  </a> </td></tr>\n <tr><td colspan=\"3\" align=\"center\">  <input type=\"hidden\" id=\"\" name=\"object_id\" value=\"0\" />  <input type=\"hidden\" id=\"\" name=\"action\" value=\"store\" />  </td></tr></table> </form>","editable_form_id":"image_form","error":"You must have an account of type submitter to be able to submit data. Please contact SGN to change your account type.","login":1}',

};

plan( tests => 3*(scalar keys %$ajax_urls));
my $j = JSON::Any->new;
while( my ($url, $json) = each %$ajax_urls) {
    $mech->get_ok($url);
    is_valid_json($mech->content, "$url is valid JSON");
    my $out = $j->decode( $mech->content );
    is_deeply( $out, $j->decode($ajax_urls->{$url}), "$url has the expected JSON");
}
