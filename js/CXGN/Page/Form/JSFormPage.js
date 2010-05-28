
/** 
* @class JSFormPage
* A Javascript SimpleFormPage for generating Ajax forms 
* @author Naama Menda <nm249@cornell.edu>
*
*This javascript object deals with dynamic printing  
*of static/editable forms
*
*JSFormPage.js object is instantiated from CXGN::Page::Form::JSFormPage.pm
*/

//JSAN.use('jQuery');
JSAN.use('Prototype');

if (!CXGN) CXGN = function() {};
if (!CXGN.Page) CXGN.Page = function() {};
if (!CXGN.Page.Form) CXGN.Page.Form = function() {};

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


CXGN.Page.Form.JSFormPage.prototype = { 
    
    render: function(action) {
       //render the form here
	if (!action) action  = "view";
	if (!this.getObjectId()) action = "new";
	//	MochiKit.Logging.log("FormId = " + this.formId);
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
	var editableForm = $(this.getEditableFormId());
	MochiKit.Logging.log("Store function found editableFormId", this.getEditableFormId());
	
	new Ajax.Request(this.getAjaxScript(), {
		parameters: $(editableForm).serialize(true) ,
		    onSuccess: function(response) {
		    var json = response.responseText;
		    var x = eval ("("+json+")");
		    if (x.error) { 
			alert(x.error); 
		    } else if (x.refering_page) { window.location = x.refering_page ; } 
		    else if (x.html) { $(form.getFormId() ).innerHTML = x.html + form.getFormButtons(); }
		    else { form.printForm("view"); }
		},
		    onFailure: function(response) {
		    alert("Script " + form.getAjaxScript() + " failed!!!" ) ;
		},
		    });
    },
    
    printForm: function( action) {
	var form = this; //'this' cannot be used inside the inner onSuccess function
	if (!action) action = 'view';
	MochiKit.Logging.log("printForm: action = " , action);
	if (!action || !this.getObjectName() || !this.getAjaxScript() )  {
	    alert("Cannot print from without a objectName, action, and ajaxScript name ! ");
	} else if  (action == 'delete') { 
	    this.printDeleteDialog();
	}else {

	    new Ajax.Request(this.getAjaxScript(), {

		    parameters: {  object_id: this.getObjectId() , action: action },
		    onSuccess: function(response) {
			var json = response.responseText;
			var x = eval ("("+json+")");
			if (x.login) { 	
			    window.location =  '/solpeople/login.pl' ;
			    x.error = undef;
			}
			if (x.error) { alert("error: " +x.error); }
			else if (x.reload) { MochiKit.Logging.log("deleted locus...", x.reload); window.location.reload(); } 
			else {
			    form.setUserType(x.user_type);
			    form.setIsOwner(x.is_owner);
			    form.setEditableFormId(x.editable_form_id);
			    //alert('Editable form: '+x.editable_form_id);
			    form.printEditLinks(action);
			    form.printFormButtons();
			    MochiKit.Logging.log("this editable_form_id is ... " , form.getEditableFormId() );
			    
			    $(form.getFormId() ).innerHTML = x.html + form.getFormButtons();
			}
		    },
			onFailure: function(response) {
			alert("Script " + form.getAjaxScript() + " failed!!!" ) ;
		    },
			});
	}
    },

    printDeleteDialog: function() {
	var deleteDialog =  
	'<b>Delete this ' + this.getObjectName()  + '?</b> '; 
	deleteDialog += '<input type =\"button\" onClick=\"javascript:' + this.getJsObjectName() + '.printForm(\'confirm_delete\')\" value=\"Confirm delete\"/><br><br>';
	this.printEditLinks('delete');
	$(this.getFormId() ).innerHTML = deleteDialog;
	
    },
    
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

    printFormButtons: function() {
	var action = this.getAction();
	var buttons='';
	//if ((this.getUserType() == "curator") || this.getIsOwner() == 1 ) {
	if (action == 'edit' ||  action == 'new' ) { 
	    buttons = '<input type=\"button\" onClick=\"javascript:' + this.getJsObjectName() + '.store()\" value=\"Store\"/>';
	    buttons +='<input type=\"button\" onClick=\"javascript:' + this.getJsObjectName() + '.render( \'edit\' )\" value=\"Reset form\"/>';
	    
	    //}
	}
	this.setFormButtons(buttons);
    },
    
    
    printEditLinks: function(action, newButton, editButton, deleteButton) {
	this.setAction(action);
	MochiKit.Logging.log("printEditLinks action = " , action );

	buttonHTML = '';

	if (action == 'edit') { 
	    buttonHTML = this.getGhostedNewButton() + this.getCancelEditButton() + this.getGhostedDeleteButton();
	}

	if (action == 'new' || action == 'view') { 
	    buttonHTML = this.getGhostedNewButton() + this.getGhostedEditButton() + this.getGhostedDeleteButton();
	}


	if (action == 'view' &&  ((this.getUserType() == 'curator') || (this.getIsOwner == 1))) { 
	    buttonHTML = this.getNewButton() + this.getEditButton() + this.getDeleteButton();
	}

	if (action == 'delete') { 
	    buttonHTML = this.getGhostedNewButton() + this.getGhostedEditButton() + this.getCancelDeleteButton();

	}

	//if (!newButton)   this.printNewButton();
	//else this.setNewButton(newButton);
	
	//if (!editButton)    this.printEditButton();
	//else this.setEditButton(editButton);
	
	//if (!deleteButton)   this.printDeleteButton();
	//else this.setDeleteButton(deleteButton);
	

	$(this.formId+ "_buttons").innerHTML = buttonHTML;
	
	this.setEditLinks(buttonHTML);
	
    },
    
    
    printNewButton: function() {
	//new link
	var action = this.getAction();
	
	
	//var newLink =  ' <span class="ghosted">[New]</span> ' ;
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
    
	
    reloadNewPage: function() {
	MochiKit.Logging.log("reloadNewPage found page: " , this.getPageName());
	window.location =  this.getPageName() + '?action=new' ; 
	
    },
      
    //////////////////////////////////////////////////////
    //accessors for object_id and object_name
    //every form object should first set the object_name and object_id. 
    //These 2 vars will be used in every server side script called 
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
    //accessors for the server side script with will handle the form components
    //and return these as a JSON object
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
    }
    ////
}
