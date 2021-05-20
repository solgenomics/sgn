import "../legacy/d3/d3v4Min.js";


const list_prefix = "__LIST__";

/**
 * Wizard - Creates a new Wizard object.
 *
 * @class
 * @classdesc Manages a wizard and performs searches
 * @param  {type} main_id div containing Wizard divs and templates (see Wizard.basicTemplate)
 * @param  {type} col_number number of wizard columns to create
 * @returns {Object}
 */
export function Wizard(main_id,col_number){

  /**
   * @typedef {Object} Wizard~objectWithName
   * @property {string} name Name of object
   * @property {string} [url] Link for object
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
   * @param {Array.<Wizard~columnItem>} categories Array of pervious column types in order
   * @param {Object.<string,Array.<Wizard~columnItem>>} selections Object where keys are categories and values are arrays of items selected in those categories
   * @param {Object.<string,boolean>} operations Object where keys are categories and values are booleans (true if interect, false if union)
   * @returns {Array.<Wizard~columnItem>} contents of column
   */
  var load_selection = (target,categories,selections,operations)=>[];


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
   * Callback for wizard changes
   * @callback Wizard~on_changeCallback
   * @param {Array.<Wizard~columnItem>} categories Array of column types in order
   * @param {Object.<string,Array.<Wizard~columnItem>>} selections Object where keys are categories and values are arrays of items selected in those categories
   * @param {Object.<string,boolean>} operations Object where keys are categories and values are booleans (true if interect, false if union)
   */
  var on_change_cbs = [];

  /**
   * Adds items to existing list from wizard selection
   * @callback Wizard~add_to_listCallback
   * @param {string} listID listID selected by user
   * @param {string} colType column type selected by user
   * @param {Array.<Wizard~columnItem>} items items to add to list
   */
  var add_to_list = (listID,items)=>{};


  var type_dict = {};
  var initial_types = [];

  var main = d3.select(main_id);

  var unselectedHTML = main.select(".templates .wizard-unselected").html();
  var selectedHTML = main.select(".templates .wizard-selected").html();
  var columnHTML = main.select(".templates .wizard-column").html();

  var col_objects = [];
  for (var i = 0; i < col_number; i++) {
    col_objects.push({index:i,type:null,filter:()=>true});
    col_objects[i].items = [];
    col_objects[i].intersect = false;
    col_objects[i].loading = false;
    col_objects[i].load_promise = Promise.resolve(true);
    col_objects[i].reflowing = false;
  }

  col_objects.forEach((col)=>{
    col.reload = (list_content)=>{

      col.loading = true;
      var load_promise;
      var load_outdated = new Error("Load outdated.");

      load_promise = Promise.all(
          col_objects.slice(0,col.index).map(c=>c.load_promise) // Wait for previous cols to load.
        ).then(()=>{
          // Don't bother loading if the reload is no longer the most recent.
          if (col.load_promise != load_promise){
            throw load_outdated;
          }
          else if (list_content){
            return list_content;
          }
          else if(col.type==""||col.type==null){
            return []
          }
          else if(col.index==0){
            return load_initial(col.type);
          }
          else {
            var prev = col_objects.slice(0,col.index);
            var categories = prev.map(c=>c.type);
            var selections = {};
            var operations = {};
            prev.forEach(c=>selections[c.type]=c.items.filter(i=>i.selected).map(i=>i.value));
            prev.forEach(c=>operations[c.type]=c.intersect);

            return load_selection(
              col.type,
              categories,
              selections,
              operations
            );
          }
        }).then(
          new_items=>{
            // Dont update the items if the reload is no longer the most recent.
            if (col.load_promise != load_promise){
              throw load_outdated;
            }
            var existing = {};
            var fresh = {};
            var freshList = [];
            col.items.forEach(i=>existing[i.name]=i);
            new_items.forEach(i=>{
              var name = itemName(i);
              if(!fresh[name]){
                if(!existing[name]){
                  fresh[name] = {
                    name:name,
                    selected:false,
                    url: i&&i.url?i.url:null,
                    value:i
                  }
                }
                else{
                  fresh[name] = existing[name]
                }
                freshList.push(fresh[name]);
              }
            });
            col.items = freshList;
            col.loading = false;
            return true;
          },
          reason=>{throw reason}
        ).then(
          load_ok=>load_ok,
          reason=>{
            if (reason==load_outdated){
              return col.load_promise.then(()=>false);
            }
            else {
              throw reason;
            }
          }
        );

      col.load_promise = load_promise;
      return load_promise;
    };
  });

  function itemName(i){return i.name!==undefined?i.name:""+i};

  function getColumns(){
    return col_objects;
  }

  function setColumn(index, new_type, intersect, selector, list_content){
    var col = col_objects[index];

    if(new_type==col.type && intersect==undefined && selector==undefined){
      return;
    }

    col.type = new_type;

    // Prevents call loop with .wizard-type-select callback
    var select = allCols.filter(d=>d.index==index).select(".wizard-type-select");
    var selVal = select.property("value");
    if (!list_content && selVal!=new_type){
      select.property("value",new_type);
    }
    redraw_types();

    col.intersect = intersect!=undefined ? intersect : col.intersect;

    selector = selector || (()=>null);
    col.reload(list_content).then(()=>{
      if(col.type==new_type){
        col.items.forEach(i=>{
          var select = selector(i.value);
          if(select!==null) i.selected = !!select;
        })
      }
      reflow(col.index,true);
    })
  }

  function setColumnFromList(index,listID){
    allCols.filter(d=>d.index==index)
      .style("opacity","0.5")
      .select(".wizard-loader")
      .style("display",null);
    load_list(listID).then(list_details=>{
      setColumn(index,list_details.type||"",null,()=>true,list_details.items||[]);
      allCols.filter(d=>d.index==index)
        .style("opacity","1")
        .select(".wizard-loader")
        .style("display","none");
    })
  }

  //Init Columns
  console.log(main);
  var cols = main.select(".wizard-columns").selectAll(".wizard-column")
    .data(col_objects,d=>d.id);
  var allCols = cols.enter().append("div")
    .classed("wizard-column",true).classed("col-xs-3",true)
    .html(columnHTML);
  allCols.select('.wizard-type-select').on("change",function(d){
    var val = d3.select(this).node().value;
    if (val.slice(0,list_prefix.length)==list_prefix){
      setColumnFromList(d.index,val.slice(list_prefix.length))
    }
    else {
      setColumn(d.index, val);
    }
    reflow(d.index);
  }).filter(d=>d.index>0).select(".wizard-lists-group").remove();
  allCols.select('.wizard-union-toggle').on("click",function(d) {
    d.intersect = !d.intersect;
    d3.select(this).selectAll('.btn:not(.disabled)').each(function(){
      d3.select(this).classed("active",!d3.select(this).classed("active"));
      d3.select(this).classed("btn-primary",!d3.select(this).classed("btn-primary"));
      d3.select(this).classed("btn-default",!d3.select(this).classed("btn-default"));
    })
    reflow(d.index, true);
  });
  allCols.select(".wizard-select-all").on("click",function(d){
      var s = d3.selectAll(".wizard-search").filter(function(e, i) { return i === d.index });
      var search_txt = s ? s.property("value").replace(/\s+/g, "").toLowerCase() : undefined;
      d.items.forEach(i=>{
          var val = i.name.replace(/\s+/g, "").toLowerCase();
          i.selected = search_txt ? val.indexOf(search_txt) != -1 : true;
      });
      reflow(d.index,true);
  })
  allCols.select(".wizard-select-clear").on("click",function(d){
    d.items.forEach(i=>{i.selected=false});
    reflow(d.index,true);
  })
  allCols.select(".wizard-create-list").on("click",function(d){
    var thiscol = allCols.filter(c_d=>c_d==d);
    var listName = thiscol.select(".wizard-create-list-name").property("value");
    if(listName!=""){
      d3.select(this).attr("disabled",true);
      thiscol.select(".wizard-create-list-name").property("value","");
      Promise.resolve(create_list(
        listName,
        d.type,
        d.selectedList.get().map(i=>i.value)
      )).then(()=>{
        d3.select(this).attr("disabled",null);
      });
    }
  });
  allCols.select(".wizard-add-to-list").on("click",function(d){
    var thiscol = allCols.filter(c_d=>c_d==d);
    var listName = thiscol.select(".wizard-create-list-name").property("value");
    var listID = thiscol.select(".wizard-add-to-list-id").property("value").slice(list_prefix.length);
    if(listID!=""){
      d3.select(this).attr("disabled",true);
      thiscol.select(".wizard-add-to-list-id").property("value","");
      Promise.resolve(add_to_list(
        listID,
        d.selectedList.get().map(i=>i.value)
      )).then(()=>{
        d3.select(this).attr("disabled",null);
      });
    }
  });
  allCols.select(".wizard-search").on("input",function(d){
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
      unselectedHTML,23,4
    );
    coldat.selectedList = virtualList(
      col.select(".wizard-list-selected"),
      selectedHTML,23,4
    );
    coldat.unselectedList.afterDraw((li)=>{
      li.select(".wizard-list-name")
        .text(d=>d.name)
        .style("pointer-events",d=>d.url?null:"none")
        .attr("href",d=>d.url);
      li.select(".wizard-list-add").on("click",function(d){
        d.selected = true;
        reflow(coldat.index,true);
      });
    });
    coldat.selectedList.afterDraw((li)=>{
      li.select(".wizard-list-name")
        .text(d=>d.name)
        .style("pointer-events",d=>d.url?null:"none")
        .attr("href",d=>d.url);
      li.select(".wizard-list-rem").on("click",function(d){
        d.selected = false;
        reflow(coldat.index,true);
      });
    });
  })

  // Initial draw
  reflow();

  function reflow(from, dont_reload, dont_propagate){
    if(!from) from = 0;
    if(from>=col_objects.length) return true;

    allCols.filter(d=>(d.index==from&&!dont_reload)||(!dont_propagate&&d.index>from))
      .style("opacity","0.5")
      .select(".wizard-loader")
      .style("display",null);

    var reflowCol = allCols.filter(d=>d.index==from);
    if(allCols.empty()) return;
    var col = reflowCol.datum();

    col.reflowing = true;

    var load = dont_reload===true?Promise.resolve(true):col.reload();
    return load.then(()=>{
      if(col.reflowing){
        if(!dont_reload){
          reflowCol.style("opacity",null)
            .select(".wizard-loader")
            .style("display","none");
        }

        col.unselectedList.set(col.items.filter(d=>!d.selected&&col.filter(d)));
        col.selectedList.set(col.items.filter(d=>d.selected&&col.filter(d)));

        reflowCol.select(".wizard-union-toggle").style("display",(d,i,n)=>{
          return d.items.filter(i=>i.selected).length>0&&d.index<col_objects.length-1?null:"none";
        })
        reflowCol.select(".wizard-count-selected").text(d=>d.items.filter(i=>i.selected).length);
        reflowCol.select(".wizard-count-all").text(d=>d.items.length);

        reflowCol.select(".wizard-save-to-list")
          .style("display","none")
          .filter(d=>d.items.filter(i=>i.selected).length>0)
          .style("display",null);

        col.reflowing = false;
        on_change();
        if(!dont_propagate) return reflow(from+1);
        return true
      }
      else {
        return false;
      }
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

  function on_change(){
    var filled_cols = col_objects.filter(c=>c.items.filter(i=>i.selected).length>0);
    var categories = filled_cols.map(c=>c.type);
    var selections = {};
    var operations = {};
    filled_cols.forEach(c=>selections[c.type]=c.items.filter(i=>i.selected).map(i=>i.value));
    filled_cols.forEach(c=>operations[c.type]=c.intersect);

    on_change_cbs.forEach(cb=>cb(
      categories,
      selections,
      operations
    ))
  }

  function set_lists(list_dict){
    list_dict = list_dict || {};
    var lists = Object.keys(list_dict).map(k=>({id:k,name:list_dict[k].name,type:list_dict[k].type}));
    lists = lists.sort((a,b)=>a.name.toLowerCase() < b.name.toLowerCase() ? -1 : b.name.toLowerCase() < a.name.toLowerCase() ? 1 : 0);
    var opts = allCols.selectAll(".wizard-lists-group").selectAll("option")
      .data(lists);
    opts.enter().append("option").merge(opts)
      .attr("value",d=>list_prefix+d.id)
      .attr("data-type",d=>d.type)
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
      //var selected = select.property("value");
      var selected = select.datum().type;
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
         setColumn(i,"");
      }
      else if (selected!="") used.push(selected);
      opts.exit().remove();
    })
  }

  var wizard = {

    setColumn: setColumn,
    getColumns: getColumns,

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
     * on_change
     * @memberof Wizard.prototype
     * @param  {Wizard~on_changeCallback} f
     * @returns {this}
     */
    on_change: function(f){
      if(f===null){
        on_change_cbs = []
      }
      else{
        on_change_cbs.push(f)
      }
      return wizard
    },

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

Wizard.basicTemplate = `
<span class="wizard-main">
  <span class="wizard-columns"></span>
  <div class="templates">
    <div class="wizard-unselected">
      <button type="button" class="wizard-list-add">&#x2b;</button>
      <a class="wizard-list-name"></a>
    </div>
    <div class="wizard-selected">
      <button type="button" class="wizard-list-rem">&#10005;</button>
      <a class="wizard-list-name"></a>
    </div>
    <div class="wizard-column">
      <span class="wizard-loader"></span>
      <select class="wizard-type-select">
      <option selected value="" disabled></option>
        <optgroup class="wizard-types-group" label=""></optgroup>
        <optgroup class="wizard-lists-group" label=""></optgroup>
      </select>
      <input type="text" class="wizard-search" placeholder="Search">
      <button class="wizard-select-all">Select All</button>
      <span>
        <span class="wizard-count-selected">0</span>/<span class="wizard-count-all">0</span>
      </span>
      <button class="wizard-select-clear">Clear</button>
      <ul class="wizard-list-unselected"></ul>
      <ul class="wizard-list-selected"></ul>
      <div class="wizard-union-toggle">Toggle</div>
      <div class="wizard-save-to-list">
        <select class="wizard-add-to-list-id">
          <option selected value="" disabled></option>
          <optgroup class="wizard-lists-group" label=""></optgroup>
        </select>
        <button class="wizard-add-to-list">Add</button>
        <input class="wizard-create-list-name" type="text"></input>
        <button class="wizard-create-list">Create</button>
      </div>
    </div>
  </div>
</span>`;
