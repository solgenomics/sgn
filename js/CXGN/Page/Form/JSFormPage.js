
/** 
* @class JSFormPage
* A Javascript SimpleFormPage for generating editable Ajax forms
* @author Naama Menda <nm249@cornell.edu>
*
*This javascript object deals with dynamic printing
*of static/editable forms
*
*JSFormPage.js object is instantiated from CXGN::Page::Form::AjaxFormPage.pm
* Depends on jquery. The page that uses this code needs to import
* those libraries.
*/

if (!CXGN) CXGN = function() {};
if (!CXGN.Page) CXGN.Page = function() {};
if (!CXGN.Page.Form) CXGN.Page.Form = function() {};

/**
   CXGN.Page.Form.JSFormPage
   The javascript form constructor
   usually called from mason/page/form.mas
   'new CXGN.Page.Form.JSFormPage'
   args are in the following order: (variabe names are not important, just the order)
   object_id (a database id)
   object_type (the name of the object, usually the table name. e.g. 'locus')
   server_side_script (the script where the form is defined. e.g. '/phenome/stock/stock_ajax_form.pl')
   form_id (the div_id of hte form)
   js_object_name (a name for this Javascript object. Allows using multiple form objects in one page)
   page_url (the url for the page. Used for reloading a new page for a new empty object)

   Optional: set an alternate new button (jsObjectName.setNewButton(new_button_url) . e.g. /stock/view/new )
   After setting the above parameters, need to call the render function: 
   jsObjectName.render
*/
CXGN.Page.Form.JSFormPage = function(id,  name,  script, formId, jsObjectName, pageName) {
    //alert('In constructor.');

    this.setObjectName(name);
    this.setObjectId(id);
    this.setAjaxScript(script);
    this.setFormId(formId);
    this.setJsObjectName(jsObjectName);
    this.setPageName(pageName);
    this.defineButtons();
};

/**
   This allows using JSFormPage as a javascript object
 */
CXGN.Page.Form.JSFormPage.prototype = {
    /**
       render
       renders the form. By default the form will be static (action ='view')
       if render is called without an object_id, it will attempt to print a 'new' form, otherwise
       calls this.printForm with the 'action' arg.
       Valid 'action' is : view, edit , store, confirm delete, delete (and new)
     */
    render: function(action) {
       //render the form here
	if (!action) action  = "view";
	if (!this.getObjectId()) action = "new";
	this.printForm( action);
    },

    /**
     * store
     * store the information from the form into the database
     * -checks privileges
     * -form fields are validated
     * (if fails- form shows again with an appropriate error message)
     * args: server_side_script name, and %args
     * -calls the appropriate server side script that calls the store function
     * in the relevant perl object.
     * onSuccess - the innerHTML div is updated, else, a JSON alert is issued.
     */
    store: function() {
	//var action = 'store';
	var form = this;
	var editableForm = jQuery('#'+this.getEditableFormId());

	jQuery.ajax( {
	    method: "get",
            url: this.getAjaxScript(), 
	    data: editableForm.serialize(true) ,
	    success: function(response) {
		var x;
		if ( (typeof response=='string')) { // && (response.charAt(0)=="{") ) { 
		     x = eval("("+response+")");
		}
		 else { 
		     x = response; //x = eval("("+response+")");
		 }

		if (x.error) { 
		    alert(x.error); 
		} 
		else if (x.refering_page) { window.location = x.refering_page ; } 
		else if (x.html) { document.getElementById(form.getFormId() ).innerHTML = x.html + form.getFormButtons(); }
		else { form.printForm("view"); }
	    },
	    error: function(response) {
		alert("Action '" + action +"'  failed for storing this " + this.getObjectName() + "!!" ) ;
		
	    }
	});
    },
    /**
       printForm
       called from the render function  (and also when clicking the 'edit' or 'delete' buttons)
       arg: action (default: 'view')
       if object_id is not set for the form object (this.getObjectId) will attempt to print a 'new' form.
       If action = 'delete' will print a delete dialog
       Otherwise will make an Ajax request (this.getAjaxScript):
       If the user is not logged in - redirects to /solpeople.login.pl
       If action was 'delete', the page will be reloaded (define in the front end who can see an obsolete page, and who should see a message that this object is obsolete/was deleted, etc.)
       If action was 'view' or 'edit', the appropriate form will be printed with the defined editable links.
       If action was 'store' , and the backend did not fail nor returned a JSON error key, the form div will be updated with the current html returned in a JSON object
     */
    printForm: function( action) {
	var form = this; //'this' cannot be used inside the inner onSuccess function
	if (!action) action = 'view';
        if ( this.getObjectId() == 0 ) action = 'new';
	if (!action || !this.getObjectName() || !this.getAjaxScript() )  {
	    alert("Cannot print from without a objectName, action, and ajaxScript name ! ");
	} else if  (action == 'delete') { 
	    this.printDeleteDialog();
	}
	else {    
	    jQuery.ajax({
		url: this.getAjaxScript(),
		method: "get",
		data: {  'object_id': this.getObjectId(), 'action': action },
		success: function(response) {
		    var x;
		    
		     if ( (typeof response=='string')) { // && (response.charAt(0)=="(") ) { 
		     	x = eval("("+response+")");
		     }
		    if (( typeof response=='object')) { 
		     	x = eval(response);
		     }

		    if (x.login) { 	
			window.location =  '/solpeople/login.pl' ;
			x.error = undef;
		    }
		    if (x.error) { alert("error: " + x.error); }
		    else if (response.reload) {  
			window.location.reload(); } 
		    else {


			form.setUserType(x.user_type);
			form.setIsOwner(x.is_owner);
			form.setEditableFormId(x.editable_form_id);
			form.printEditLinks(action);
			form.printFormButtons();
			
			document.getElementById(form.getFormId() ).innerHTML = x.html + form.getFormButtons();
		    }
		},
		error: function(response) {
		    alert("Action '" + action +"'  failed for storing this " + this.getObjectName() + "!!" ) ;
		},
	    });
	}
    },

    /**
       printDeleteDialog
       action 'delete' prompts printing in the form div a delete confirmation button,
       clicking 'delete' calls printForm('confirm_delete') which will call the server side (should take care of deleting/obsoleting the object.
     */
    printDeleteDialog: function() {
	var deleteDialog =  
	'<b>Delete this ' + this.getObjectName() + ' ' +this.getObjectId()  + '?</b> '; 
	deleteDialog += '<input id=\"'+this.getJsObjectName()+'_delete_button\" class=\"btn btn-primary btn-sm\" type =\"button\" onClick=\"javascript:' + this.getJsObjectName() + '.printForm(\'confirm_delete\')\" value=\"Confirm delete\"/><br><br>';
	this.printEditLinks('delete');
	document.getElementById(this.getFormId() ).innerHTML = deleteDialog;

    },

    /**
       defineButtons
       this function is called from the constructor.
       Calls the setters for New, Edit, CancelEdit, Delete, CancelDelete buttons, 
       and ghosted New, Edit, Delete buttons (should be used if the logged in user does not have the related privileges. Should be defined in the backend)
     */
    defineButtons: function() { 
	this.setNewButton('<a href= \"javascript:onClick=' +  this.getJsObjectName() + '.reloadNewPage()  \">[New]</a> ');

	this.setGhostedNewButton(' <span class="ghosted">[New]</span> ');

	this.setEditButton(' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.printForm(\'edit\')\">[Edit]</a> ');

	this.setGhostedEditButton(' <span class=\"ghosted\">[Edit]</span> ');

	this.setCancelEditButton(' <a href= \"javascript:onClick='+this.getJsObjectName()+'.render() \">[Cancel]</a> ');

	this.setDeleteButton(' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.printForm(\'delete\')\">[Delete]</a> ');

	this.setCancelDeleteButton(' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.render()\">[Cancel Delete]</a> ');

	this.setGhostedDeleteButton(' <span class=\"ghosted\">[Delete]</span> ');
    },


    /**
       printFormButtons
       called from printForm
       prints 'store' and 'reset form' buttons for 'editable' and 'new' forms
     */
    printFormButtons: function() {
	var action = this.getAction();
	var buttons='';
	//if ((this.getUserType() == "curator") || this.getIsOwner() == 1 ) {
	if (action == 'edit' ||  action == 'new' ) { 
	    buttons = '<input id=\"'+this.getJsObjectName()+'_submit_button\" class=\"btn btn-primary btn-sm\" type=\"button\" onClick=\"javascript:' + this.getJsObjectName() + '.store()\" value=\"Store\"/>&nbsp;&nbsp;&nbsp;';
	    buttons +='<input id=\"'+this.getJsObjectName()+'_reset_button\"class=\"btn btn-default btn-sm\" type=\"button\" onClick=\"javascript:' + this.getJsObjectName() + '.render( \'edit\' )\" value=\"Reset form\"/><br/><br/>';

	    //}
	}
	this.setFormButtons(buttons);
    },

    /**
       printEditLinks
       args: action
       called from printForm
       Prints editable buttons correctly depending on the 'action'
       (e.g. if action was 'edit' will print a ghosted 'new' and 'delete' buttons, and a 'cancel edit' button instead of the 'edit' button).
       Calls setEditLinks with the buttons html
     */
    printEditLinks: function(action, newButton, editButton, deleteButton) {
	this.setAction(action);

	buttonHTML = '';

	if (action == 'edit') {
	    buttonHTML = this.getGhostedNewButton() + this.getCancelEditButton() + this.getGhostedDeleteButton();
	}

	if (action == 'new' || action == 'view') {
	    buttonHTML = this.getGhostedNewButton() + this.getGhostedEditButton() + this.getGhostedDeleteButton();
	}

	if (action == 'view' &&  ((this.getUserType() == 'curator') || (this.getIsOwner() == 1))) {
        buttonHTML = this.getNewButton() + this.getEditButton() + this.getDeleteButton();
	}

	if (action == 'delete') {
	    buttonHTML = this.getGhostedNewButton() + this.getGhostedEditButton() + this.getCancelDeleteButton();

	}

        document.getElementById(this.formId+ "_buttons").innerHTML = buttonHTML;

	this.setEditLinks(buttonHTML);

    },

    /////////////////////

    printNewButton: function() {
	//new link
	var action = this.getAction();

	var newLink = '<a href= \"javascript:onClick=' +  this.getJsObjectName() + '.reloadNewPage()  \">[New]</a>';

	if (action == "edit" || action == "delete") { 
 	    newLink = ' <span class="ghosted">[New]</span> ';
 	}
 	if (action == "new"   && (( this.getUserType() == "curator") || this.getIsOwner() ==1 )) { 
	    newLink = '<a href= \"javascript:history.back(1) \">[Cancel]</a> ';
 	}
	this.setNewButton(newLink);

    },

    printEditButton: function() {
	//edit link
	var action = this.getAction();
 	var editLink;
	if ((this.getUserType() == "curator") || this.getIsOwner() ==1 ) {
	    editLink = ' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.printForm(\'edit\')\">[Edit]</a>' ;

	}else {
	    editLink = ' <span class=\"ghosted\">[Edit]</span> ';
	}

	if (action == "edit") { 
	    editLink = ' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.printForm( \'view\')\">[Cancel edit]</a> ';
	}

	if (action ==  "new" || action == "delete") { 
	    editLink = ' <span class=\"ghosted\">[Edit]</span> ';
	}
	this.setEditButton(editLink);

    },

    printDeleteButton: function() {
	//delete link
	var action = this.getAction();
 	var deleteLink;
	// if ((this.getUserType() ==  "curator") || this.getIsOwner() ) {
	if ((this.getUserType() == "curator") || this.getIsOwner() ==1 ) {
	    deleteLink = ' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.printForm(\'delete\')\">[Delete]</a>' ;

	}else {
	    deleteLink = ' <span class=\"ghosted\">[Delete]</span> ';
	}

	if (action ==  "edit" || action == "new" ) { 
	    deleteLink = ' <span class=\"ghosted\">[Delete]</span> ';
	}
	if (action == "delete" )
	    deleteLink = ' <a href=\"javascript:onClick=' + this.getJsObjectName() + '.render()\">[Cancel Delete]</a>';
	// 	////////////////////
	this.setDeleteButton(deleteLink);

    },
    ///////////////////////////////

    /**
       reloadNewPage
       called when clicking the 'new' button.
     */
    reloadNewPage: function() {
	if (this.getPageName()) { 
	    window.location =  this.getPageName() + "?action=new" ;
	}
	else { 
	    this.printForm('new');
	}
    },

    //////////////////////////////////////////////////////

    /**accessors for object_id and object_name
    every form object should first set the object_name and object_id. 
    These 2 vars will be used in every server side script called 
    */
    setObjectId: function(objectId) { 
	this.objectId = objectId;
    },

    getObjectId: function() { 
	return this.objectId;
    },

    setObjectName: function(objectName) { 
	this.objectName = objectName;
    },

    getObjectName: function() { 
	return this.objectName;
    },
    //
    ////////////////////////////////////////////////

    /**accessors for the server side script with will handle the form components
    and return these as a JSON object
    */
    getAjaxScript: function() {
	return this.ajaxScript;
    },

    setAjaxScript: function(ajaxScript) {
	this.ajaxScript = ajaxScript;
    },
    //////////////////////////

    getPageName: function() {
	return this.pageName;
    },

    setPageName: function(pageName) {
	this.page_name = pageName;
    },

    ///
    getFormName: function() {
	return this.formName;
    },

    setFormName: function(formName) {
	this.form_name = formName;
    },

    ///

    getFormId: function() {
	return this.formId;
    },

    setFormId: function(formId) {
	this.formId = formId;
    },
    ////
    getJsObjectName: function() {
	return this.jsObjectName;
    },

    setJsObjectName: function(jsObjectName) {
	this.jsObjectName = jsObjectName;
    },

    ///
    getAction: function() {
	return this.action;
    },

    setAction: function(action) {
	this.action = action;
    },
    ///
     getIsOwner: function() {
	return this.isOwner;
    },

    setIsOwner: function(isOwner) {
	this.isOwner = isOwner;
    },
    ///
    getUserType: function() {
	return this.userType;
    },

    setUserType: function(userType) {
	this.userType = userType;
    },
    ///

    getPrimaryKey: function() {
	return this.primaryKey;
    },

    setPrimaryKey: function(primaryKey) {
	this.primaryKey = primaryKey;
    },
    ///

    getEditLinks: function() {
	return this.editLinks;
    },

    setEditLinks: function(editLinks) {
	this.editLinks = editLinks;
    },
    ////
    getNewButton: function() {
	return this.newButton;
    },

    setNewButton: function(newButton) {
	this.newButton = newButton;
    },

    setGhostedNewButton: function(ghostedNewButton) { 
	this.ghostedNewButton = ghostedNewButton;
    },

    getGhostedNewButton: function() { 
	return this.ghostedNewButton;
    },

    ////
    setCancelEditButton: function(cancelEditButton) { 
	this.cancelEditButton = cancelEditButton;
    },

    getCancelEditButton: function() { 
	return this.cancelEditButton;
    },

    setGhostedEditButton: function(ghostedEditButton) { 
	this.ghostedEditButton = ghostedEditButton;
    },

    getGhostedEditButton: function() { 
	return this.ghostedEditButton;
    },

    getEditButton: function() {
	return this.editButton;
    },

    setEditButton: function(editButton) {
	this.editButton = editButton;
    },
    ////

    getDeleteButton: function() {
	return this.deleteButton;
    },

    setDeleteButton: function(deleteButton) {
	this.deleteButton = deleteButton;
    },

    setGhostedDeleteButton: function(ghostedDeleteButton) { 
	this.ghostedDeleteButton = ghostedDeleteButton;
    },

    getGhostedDeleteButton: function() { 
	return this.ghostedDeleteButton;
    },

    setCancelDeleteButton: function(cancelDeleteButton) { 
	this.cancelDeleteButton = cancelDeleteButton;
    },

    getCancelDeleteButton: function() { 
	return this.cancelDeleteButton;
    },

    ////
    getPageName: function() {
	return this.pageName;
    },

    setPageName: function(pageName) {
	this.pageName = pageName;
    },
    ////

    getFormButtons: function() {
	return this.formButtons;
    },

    setFormButtons: function(formButtons) {
	this.formButtons = formButtons;
    },
    ////
     getEditableFormId: function() {
	return this.editableFormId;
    },

    setEditableFormId: function(editableFormId) {
	this.editableFormId = editableFormId;
    },
    ////
};
