/**

=head1 User.js

Keep track of sgn user variables for use by other modules

=cut

**/


JSAN.use("CXGN.Cookie");

var User = window.User || {};

User = {
	sgn_user_id: '',
	sgn_session_id: '',
	_init: function () {
		User.sgn_user_id = Cookie.get('user_id');
		User.sgn_session_id = Cookie.get('sgn_session_id');	
	}
}
User._init();
