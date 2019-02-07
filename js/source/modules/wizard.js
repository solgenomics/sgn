const wizardWrapper = `
  <div class="wizard-cont"></div>
  <div class="clearfix col-xs-12"></div>
  <div class="wizard-dataset">
    <div class="col-xs-6">
      <div class="panel panel-default wizard-panel">
      <div class="panel-heading">
        <div class="input-group">
          <select class="form-control input-sm wizard-dataset-select">
            <option selected value="" disabled>Load Dataset</option>
            <optgroup class="wizard-dataset-group" label="--------------------"></optgroup>
          </select>
          <span class="input-group-btn">
            <span><button style="width:5em;margin-left:4px;" class="btn btn-sm btn-primary">Load</button></span>
          </span>
        </div>
      </div>
        <div class="panel-footer" style="margin-top:-1px;">
          <div class="input-group">
            <input type="text" placeholder="Create New Dataset" class="form-control input-sm"/>
            <span class="input-group-btn">
              <span><button style="width:5em;margin-left:4px;" class="btn btn-sm btn-primary">Create</button></span>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>`;

const wizardColumn = `
  <div class="panel panel-default wizard-panel">
    <div class="panel-heading">
      <select class="form-control input-sm form-inline wizard-type-select">
        <option value="" disabled selected>Select Column Type</option>
        <optgroup class="wizard-types-group" label="--------------------"></optgroup>
        <optgroup class="wizard-lists-group" label="Load Selection from List:"></optgroup>
      </select>
      <span class="glyphicon glyphicon-refresh wizard-loading" 
        style="    position: absolute;z-index: 100;top: 6em;left: 0;font-size: 2em;text-align: center;width: 100%;display: block;" 
        aria-hidden="true"></span>
    </div>
    <div class="panel-heading">
      <div class="wizard-search">
        <input type="text" class="form-control input-sm" placeholder="Search">
      </div>
    </div>
    <div class="panel-body">
      <ul class="well wizard-list wizard-list-unselected">
      </ul>
      <ul class="well wizard-list wizard-list-isselected">
      </ul>
      <div style="text-align:center;">
        <div class="btn-group" style="display:inline-block;"> 
          <button class="btn btn-default btn-xs wizard-select-all">Select All</button>
          <button class="btn btn-default btn-xs wizard-select-clear">Clear</button>
        </div>
      </div>
    </div>
    <div class="panel-footer">
      <span style="float:left; width:auto;">
        <span class="wizard-count-selected">0</span>/<span class="wizard-count-all">0</span>
        <!-- selected -->
      </span>
      <span class="wizard-union-toggle" style="float:right;">Match
        <div class="btn-group"> 
          <button class="btn btn-xs btn-primary active">ANY</button>
          <button class="btn btn-default btn-xs">ALL</button>
        </div>
      </span>
      <div style="height:0; clear:both; display: table;"></div>
    </div>
    <div class="panel-footer wizard-save-to-list">
      <div class="input-group">
        <select class="form-control input-sm wizard-add-to-list-id">
          <option selected value="" disabled>Add to List...</option>
          <optgroup class="wizard-lists-group" label="--------------------"></optgroup>
        </select>
        <span class="input-group-btn">
          <span><button style="width:5em;margin-left:4px;" class="btn btn-sm btn-primary wizard-add-to-list">Add</button></span>
        </span>
      </div>
      <div class="input-group" style="margin-top:4px;">
        <input class="form-control input-sm wizard-create-list-name" type="text" placeholder="Create New List..."></input>
        <span class="input-group-btn">
          <span><button style="width:5em;margin-left:4px;" class="btn btn-primary btn-sm wizard-create-list">Create</button></span>
        </span>
      </div>
    </div>
  </div>`;

const unselectedRow = `
  <div class="btn-group wizard-list-item">
    <button type="button" class="btn btn-xs btn-success wizard-list-add">&#x2b;</button><div class="btn btn-xs btn-default wizard-list-name"></div>
  </div>`;
  
const selectedRow = `
  <div class="btn-group wizard-list-item">
    <button type="button" class="btn btn-xs btn-danger wizard-list-rem">&#10005;</button><div class="btn btn-xs btn-default wizard-list-name"></div>
  </div>`;
  

const list_prefix = "__LIST__";

/**
 * Wizard - Creates a new Wizard object which manages a wizard
 *
 * @class
 * @classdesc This is a description of the MyClass class.
 * @param  {type} main_id    description 
 * @param  {type} col_number description 
 * @returns {type}            description 
 */ 
export function Wizard(main_id,col_number){
  
  /**
   * @typedef {Object} Wizard~objectWithName
   * @property {string} name Name of object
  */
  /**
   * @typedef {(string|Wizard~objectWithName)} Wizard~columnItem
   * @property {string} name Name of object
  */
 
  /**
   * Returns the first column contents for a given target type
   * @callback Wizard~load_initialCallback
   * @param {string} target Type of column contents to load.
   * @returns {Array.<Wizard~columnItem>} contents of column
   */
  var load_initial = (target)=>[];
  
  /**
   * Returns the column contents for a given target type and selection
   * @callback Wizard~load_selectionCallback
   * @param {string} target Type of column contents to load.
   * @param {Array.<Wizard~columnItem>} catagories Array of pervious column types in order
   * @param {Object.<string,Array.<Wizard~columnItem>>} selections Object where keys are catagories and values are arrays of items selected in those catagories
   * @param {Object.<string,boolean>} operations Object where keys are catagories and values are booleans (true if interect, false if union)
   * @returns {Array.<Wizard~columnItem>} contents of column
   */
  var load_selection = (target,catagories,selections,operations)=>[];
  
  
  /**
   * @typedef {Object} Wizard~listDetails
   * @property {string} type catagory of list
   * @property {Array.<Wizard~columnItem>} items contents of list
  */
  /**
   * Returns the list contents and type
   * @callback Wizard~load_listCallback
   * @param {string} listID ID of list to load
   * @returns {Wizard~listDetails}
   */
  var load_list = (listID)=>[];
  
  /**
   * Creates a list from a wizard selection
   * @callback Wizard~create_listCallback
   * @param {string} listName Name input by user
   * @param {Array.<Wizard~columnItem>} items items to add to list
   */
  var create_list = (listName,items)=>{};
  
  /**
   * Adds items to existing list from wizard selection
   * @callback Wizard~add_to_listCallback
   * @param {string} listID listID selected by user
   * @param {Array.<Wizard~columnItem>} items items to add to list
   */
  var add_to_list = (listID,items)=>{};
  
  
  var type_dict = {};
  var initial_types = [];
  
  var main = d3.select(main_id).html(wizardWrapper);
    
  var col_objects = [];
  for (var i = 0; i < col_number; i++) {
    col_objects.push({index:i,type:null,filter:()=>true});
    col_objects[i].items = [];
    col_objects[i].intersect = false;
    col_objects[i].loading = false;
    if(i==0) col_objects[i].fromList = undefined;
  }
  
  col_objects.forEach((col)=>{
    col.reload = ()=>{
      var preselected = [];
      col.loading = true;
      var loading_sentinel = {"n": Math.random()};
      col.loading_sentinel = loading_sentinel;
      if(col_objects.slice(0,col.index).some(c=>c.loading)) return Promise.resolve(false);
      var pre;
      if (col.fromList!==undefined) {
        pre = Promise.resolve(load_list(col.fromList))
        .then(info=>{
          preselected = info.items.map(i=>i.name!==undefined?i.name:""+i);
          set_type(col.index,info.type);
          redraw_types();
          col.fromList = undefined;
        })
      } else{
        pre = Promise.resolve(true)
      }
      return pre.then(()=>{
        if(col.type==""||col.type==null){
          return []
        }
        else if(col.index==0){
          return load_initial(col.type);
        }
        else {
          var prev = col_objects.slice(0,col.index);
          var catagories = prev.map(c=>c.type);
          var selections = {};
          var operations = {};
          prev.forEach(c=>selections[c.type]=c.items.filter(i=>i.selected).map(i=>i.value));
          prev.forEach(c=>operations[c.type]=c.intersect);
          
          return load_selection(
            col.type,
            catagories,
            selections,
            operations
          );
        }
      }).then(new_items=>{
        if(col.loading_sentinel!=loading_sentinel){
          return false;
        }
        var existing = {};
        var fresh = {};
        var freshList = [];
        col.items.forEach(i=>existing[i.name]=i);
        col.items = new_items.forEach(i=>{
          var name = i.name!==undefined?i.name:""+i;
          if(!fresh[name]){
            if(!existing[name]){
              fresh[name] = {
                name:name,
                selected:false,
                value:i
              }
            }
            else{
              fresh[name] = existing[name]
            }
            if(preselected.indexOf(name)!=-1) fresh[name].selected = true;
            freshList.push(fresh[name]);
          }
        });
        col.items = freshList;
        col.loading = false;
        return true;
      });
    };
  });
  
  //Init Columns
  var cols = main.select(".wizard-cont").selectAll(".wizard-col")
    .data(col_objects,d=>d.id);
  var allCols = cols.enter().append("div")
    .classed("wizard-col",true).classed("col-xs-3",true)
    .html(wizardColumn);
  allCols.select('.wizard-type-select').on("change",function(d){
    var val = d3.select(this).node().value;
    if (val.slice(0,list_prefix.length)==list_prefix){
      d.fromList = val.slice(list_prefix.length);
      allCols.filter(d2=>d2.index==d.index)
        .select(".wizard-lists-select")
        .property("value",val);
      d.type = null;
    }
    else {
      d.type = val;
    }
    redraw_types();
    reflow(d.index);
  }).filter(d=>d.index>0).select(".wizard-lists-group").remove();
  allCols.select('.wizard-union-toggle').on("click",function(d) {
    d.intersect = !d.intersect;
    d3.select(this).selectAll('.btn').each(function(){
      d3.select(this).classed("active",!d3.select(this).classed("active"));
      d3.select(this).classed("btn-primary",!d3.select(this).classed("btn-primary"));
      d3.select(this).classed("btn-default",!d3.select(this).classed("btn-default"));
    })
    reflow(d.index, true);
  }).style("visibility",null).filter((d,i,nodes)=>i==nodes.length-1).style("visibility","hidden");
  allCols.select(".wizard-select-all").on("click",function(d){
    d.items.forEach(i=>{i.selected=true});
    reflow(d.index,true);
  })
  allCols.select(".wizard-select-clear").on("click",function(d){
    d.items.forEach(i=>{i.selected=false});
    reflow(d.index,true);
  })
  allCols.select(".wizard-create-list").on("click",function(d){
    var listName = d3.select(".wizard-create-list-name").property("value");
    if(listName!=""){
      create_list(
        listName,
        d.selectedList.get().map(i=>i.value)
      );
    }
  });
  allCols.select(".wizard-add-to-list").on("click",function(d){
    var listID = d3.select(".wizard-add-to-list-id").property("value");
    if(listID!=""){
      add_to_list(
        listID,
        d.selectedList.get().map(i=>i.value)
      );
    }
  });
  allCols.select(".wizard-search input").on("input",function(d){
    var search_txt = d3.select(this).property("value").replace(/\s+/g, "")
      .toLowerCase();
    d.filter = (item)=>{
      var val = item.name.replace(/\s+/g, "").toLowerCase();
      if(val.indexOf(search_txt)!=-1){
        return true;
      }
      else {
        return false;
      }
    }
    reflow(d.index, false, true);
  });
  
  //set up virtual scroll sections
  allCols.each(function(coldat){
    var col = d3.select(this);
    coldat.unselectedList = virtualList(
      col.select(".wizard-list-unselected"),
      unselectedRow,23,4
    );
    coldat.selectedList = virtualList(
      col.select(".wizard-list-isselected"),
      selectedRow,23,4
    );
    coldat.unselectedList.afterDraw((li)=>{
      li.select(".wizard-list-name").text(d=>d.name);
      li.select(".wizard-list-add").on("click",function(d){
        d.selected = true;
        reflow(coldat.index,true);
      });
    });
    coldat.selectedList.afterDraw((li)=>{
      li.select(".wizard-list-name").text(d=>d.name);
      li.select(".wizard-list-rem").on("click",function(d){
        d.selected = false;
        reflow(coldat.index,true);
      });
    });
  })
  
  // Initial draw
  reflow(0);
  
  function reflow(from, dont_reload, dont_propagate){
    if(!from) from = 0;
    if(from>=col_objects.length) return;
    
    // console.log("reflow from",from,dont_reload,dont_propagate);
    
    
    allCols.filter(d=>(d.index==from&&!dont_reload)||(!dont_propagate&&d.index>from))
      .style("opacity","0.5")
      .select(".wizard-loading")
      .style("display",null);
    
    var reflowCol = allCols.filter(d=>d.index==from);
    if(allCols.empty()) return;
    var col = reflowCol.datum();
    
    var load = dont_reload===true?Promise.resolve(true):col.reload();
    
    load.then((reload_ok)=>{
      if(!reload_ok) return;
      
      if(!dont_reload){
        reflowCol.style("opacity",null)
          .select(".wizard-loading")
          .style("display","none");
      }
      
      col.unselectedList.set(col.items.filter(d=>!d.selected&&col.filter(d)));
      col.selectedList.set(col.items.filter(d=>d.selected&&col.filter(d)));
      
      reflowCol.select(".wizard-count-selected").text(d=>d.items.filter(i=>i.selected).length);
      reflowCol.select(".wizard-count-all").text(d=>d.items.length);
      
      reflowCol.select(".wizard-save-to-list")
        .style("display","none")
        .filter(d=>d.items.filter(i=>i.selected).length>0)
        .style("display",null);
      
      if(!dont_propagate) reflow(from+1);
    });
  }
  
  function virtualList(selection,template,height,margin){
    var elHeight = height+margin;
    var el = selection.node();
    var data = [];
    var totalHeight = 0;
    var afterDraw = (sel)=>{};
    el.scrollTop = 0;
    selection.append("li").attr("class","virtlist-buffer virtlist-buffer-top")
      .style("height",`0px`)
      .style("margin",`0 0 0 0`)
      .lower();
    selection.append("li").attr("class","virtlist-buffer virtlist-buffer-bottom")
      .style("height",`0px`)
      .style("margin",`0 0 0 0`)
      .raise();
    var vlist = {
      set: (newData)=>{
        data = newData;
        totalHeight = data.length*elHeight;
        vlist.redraw();
      },
      get:()=>{
        return data;
      },
      afterDraw:(f)=>{ afterDraw=f },
      redraw:()=>{
        if(el.scrollTop>totalHeight-el.clientHeight){
          el.scrollTop = totalHeight-el.clientHeight;
        }
        var initial_pos = el.scrollTop;
        
        var hidden_above = Math.max(0,Math.floor(
          el.scrollTop/elHeight-1
        ));
        var hidden_below = Math.max(0,Math.floor(
          (totalHeight-(el.scrollTop+el.clientHeight))/elHeight
        ));
                                    
        var all = selection.selectAll("li:not(.virtlist-buffer)").data(
          data.slice(hidden_above,data.length-hidden_below)
        );
        var ent = all.enter().append("li").html(template)
          .style("height",`${height}px`)
          .style("margin",`0 0 ${margin}px 0`);
        all.exit().remove();
        
        selection.select(".virtlist-buffer-top")
          .style("height",`${hidden_above*elHeight}px`)
          .lower();
        selection.select(".virtlist-buffer-bottom")
          .style("height",`${hidden_below*elHeight}px`)
          .raise();
          
        afterDraw(all.merge(ent));
        el.scrollTop = initial_pos;
      }
    };
    selection.on("scroll",()=>vlist.redraw())
    vlist.redraw();
    return vlist;
  }
  
  function set_type(index,type){
    allCols.filter(d=>d.index==index)
      .select(".wizard-type-select")
      .property("value",type)
      .each(d=>{ d.type=type });
  }
  
  function set_lists(list_dict){
    list_dict = list_dict || {};
    var lists = Object.keys(list_dict).map(k=>({id:k,name:list_dict[k]}));
    var opts = allCols.selectAll(".wizard-lists-group").selectAll("option")
      .data(lists);
    opts.enter().append("option").merge(opts)
      .attr("value",d=>list_prefix+d.id)
      .text(d=>d.name);
  }
  
  function set_types(td){
    type_dict = td || {};
    redraw_types();
  }
  
  function set_inital_types(types){
    initial_types = types;
    redraw_types();
  }
  
  function redraw_types(){
    var list = Object.keys(type_dict).map(k=>({id:k,name:type_dict[k]}));
    var used = [];
    allCols.select(".wizard-types-group").each(function(d,i){
      var select = d3.select(this.parentNode);
      var selected = select.property("value");
      var type_options = i!=0 ?
        list.filter(o=>used.indexOf(o.id)==-1)
        : list.filter(o=>initial_types.indexOf(o.id)!=-1);
      // console.log(i,type_options);
      var opts = d3.select(this).selectAll("option")
        .data(type_options,o=>o.id);
      opts.enter().append("option").merge(opts)
        .attr("value",d=>d.id)
        .text(d=>d.name);
      if (used.indexOf(selected)!=-1){
         set_type(i,"");
      }
      else if (selected!="") used.push(selected);
      opts.exit().remove();
    })
  }
  
  var wizard = {
    
    /**    
     * load_initial    
     * @memberof Wizard.prototype     
     * @param  {Wizard~load_initialCallback} f
     * @returns {this}     
     */     
    load_initial: function(f){ load_initial = f; return wizard},
    
    /**    
     * load_selection    
     * @memberof Wizard.prototype     
     * @param  {Wizard~load_selectionCallback} f     
     * @returns {this}     
     */     
    load_selection: function(f){ load_selection = f; return wizard},
    
    /**    
     * load_list    
     * @memberof Wizard.prototype     
     * @param  {Wizard~load_listCallback} f     
     * @returns {this}     
     */
    load_list: function(f){ load_list = f; return wizard},
    
    /**    
     * add_to_list    
     * @memberof Wizard.prototype     
     * @param  {Wizard~add_to_listCallback} f     
     * @returns {this}     
     */
    add_to_list: function(f){ add_to_list = f; return wizard},
    
    /**    
     * create_list    
     * @memberof Wizard.prototype     
     * @param  {Wizard~create_listCallback} f     
     * @returns {this}     
     */
    create_list: function(f){ create_list = f; return wizard},
    
    /**    
     * lists - sets or resets the availible lists to show in the wizard
     * @memberof Wizard.prototype     
     * @param  {Object} list_dict object where keys are listIDs and values are the human-readable name     
     * @returns {this}  
     */
    lists: function(list_dict){ set_lists(list_dict); return wizard},
    
    /**    
     * types - sets or resets the availible types to show in the wizard
     * @memberof Wizard.prototype     
     * @param  {Object} type_dict object where keys are type/catagory ids and values are the human-readable name     
     * @returns {this}  
     */
    types: function(type_dict){ set_types(type_dict); return wizard},
    
    /**    
     * types - sets or resets the availible types to show in the wizard
     * @memberof Wizard.prototype     
     * @param  {Array.<string>} types list of types availible in the first column
     * @returns {this}  
     */
    initial_types: function(types){set_inital_types(types); return wizard}
  };
  return wizard
}
