
// JavaScript for mason/util/workflow.mas
var Workflow = {
  
  "init": function(init_target){ //Initializes a workflow (or all workflows)
    init_target = init_target || "";
    var prog_steps = document.querySelectorAll('.workflow-prog>li');
    prog_steps.forEach(function(ele,i){
      ele.onclick = Workflow.prog_click(i);
    });
    document.querySelectorAll('.workflow').forEach(function(wf){
      Workflow.focus(wf,0);
    });
  },
  
  "prog_click": function(step_index){ // onclick for progress markers
    //on progress marker click, change the focus to show that page
    function click(){
      var wf = this;
      while (!wf.classList.contains('workflow')){
        wf = wf.parentNode;
      }
      
      //if the previous workflows have not been complete, do not do anything!
      if (!this.classList.contains('workflow-complete') 
          && this!==wf.querySelector('.workflow-prog>li:not(.workflow-complete)')){
        return;
      }
      
      //change focus and check for completion
      Workflow.focus(wf,step_index);
      Workflow.check_complete(wf);
    }
    return click
  },
  
  "focus":function(wf,step_index){ // changes workflow focus page
    function change_focus(ele,i){
      if (i===step_index){
        ele.classList.add('workflow-focus');
      } else {
        ele.classList.remove('workflow-focus');
      }
      
    }
    
    var progs = wf.querySelectorAll('.workflow-prog>li');
    var conts = wf.querySelectorAll('.workflow-content>li');
    
    progs.forEach(change_focus);
    conts.forEach(change_focus);
  },
  
  "check_complete":function(wf){ // checks if the endscreens should be shown and acts accordingly
    var progs = wf.querySelectorAll('.workflow-prog>li');
    var conts = wf.querySelectorAll('.workflow-content>li');
    
    var all_complete = Array.prototype.every.call(progs, function(ele){
      return ele.classList.contains('workflow-complete');
    });
    var any_pending = Array.prototype.some.call(progs, function(ele){
      return ele.classList.contains('workflow-pending');
    });
    var any_focused = Array.prototype.some.call(progs, function(ele){
      return ele.classList.contains('workflow-focus');
    });
    
    if(all_complete && any_pending && !any_focused){
      wf.querySelector(".workflow-pending-message").classList.add("workflow-message-show");
    }
    else if (all_complete && !any_focused){
      wf.querySelector(".workflow-pending-message").classList.remove("workflow-message-show");
      wf.querySelector(".workflow-complete-message").classList.add("workflow-message-show");
    } else {
      wf.querySelector(".workflow-pending-message").classList.remove("workflow-message-show");
      wf.querySelector(".workflow-complete-message").classList.remove("workflow-message-show");
    }
  },
  
  "complete":function(wf_child,set_focus,status){ // completes a step
    set_focus = set_focus===false?false:true;
    var wf = wf_child;
    var content_li = wf_child;
    while (!wf.classList.contains('workflow')){
      if(wf.parentNode.classList.contains('workflow-content')){
        content_li = wf;
      }
      wf = wf.parentNode;
    }
    var step_index = Array.prototype.indexOf.call(wf.querySelectorAll('.workflow-content>li'),content_li);
    var all_steps = wf.querySelectorAll('.workflow-prog>li');
    var prog = all_steps[step_index];
    
    content_li.classList.add('workflow-complete');
    prog.classList.add('workflow-complete');
    
    
    if (status=="skipped"){
      content_li.classList.add('workflow-skipped');
      prog.classList.add('workflow-skipped');
      
    } else {
      content_li.classList.remove('workflow-skipped');
      prog.classList.remove('workflow-skipped');
    }
    
    if (status=="pending"){
      content_li.classList.add('workflow-pending');
      prog.classList.add('workflow-pending');
      
    } else {
      content_li.classList.remove('workflow-pending');
      prog.classList.remove('workflow-pending');
    }
    
    if (set_focus){
      Workflow.focus(wf,step_index+1);
    }
    Workflow.check_complete(wf);
    
  },
  
  "skip":function(wf_child,set_focus){ //completes a step with skipped status
    set_focus = set_focus===false?false:true;
    Workflow.complete(wf_child,set_focus,"skipped");
  },
  
  "pending":function(wf_child,set_focus){ //completes a step with pending status
    set_focus = set_focus===false?false:true;
    Workflow.complete(wf_child,set_focus,"pending");
  }
  
}
