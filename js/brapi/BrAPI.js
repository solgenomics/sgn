(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
    typeof define === 'function' && define.amd ? define(factory) :
    (global.BrAPI = factory());
}(this, (function () { 'use strict';

class Task {
    constructor(key, parentKey) {
        this.status = 0;
        this.setKey(key,parentKey);
        this.result = null;
    }
    complete(result){
        if (result===undefined){
            return this.status==1;
        }
        else {
            this.result = result;
            this.status = 1;
            return true;
        }
    }
    getResult(){
        return this.status==1 ? this.result : undefined;
    }
    getKey(){
        return this.key;
    }
    setKey(key,parentKey){
        if (parentKey!=undefined){
            this.key = parentKey+encodeNumberKey(key);
        } else {
            this.key = ""+key;
        }
    }
}

class Join_Task extends Task{
    constructor(key,size) {
        super(key);
        this.result = Array.apply(undefined, Array(size));
    }
    complete(perform_check){
        if (perform_check==true){
            this.status = this.result.every(function(datum){
                return datum!==undefined;
            });
        }
        return this.status==1;
    }
    addResult(result,index){
        this.result[index] = result;
    }
}

// makes numbers sort lexicographically, really should only be used for numbers 
// up to 10^26-1, which is far higher than we need anyway
function encodeNumberKey(num){
    var str = ""+num;
    var oom = str.length;
    return String.fromCharCode(oom+64)+str;
}

// POST /allelmatrix-search
function allelematrix_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/allelematrix-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /attributes
function attributes(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/attributes";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /attributes/categories
function attributes_categories(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/attributes/categories";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /calls
function calls(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/calls";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /crops
function crops(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/crops";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /germplasm-search
function germplasm_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/germplasm-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /germplasm/{germplasmDbId}
function germplasm(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/germplasm/"+(datum_params.germplasmDbId);
        delete datum_params.germplasmDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /germplasm/{germplasmDbId}/attributes
function germplasm_attributes(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/germplasm/"+(datum_params.germplasmDbId)+"/attributes";
        delete datum_params.germplasmDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /germplasm/{germplasmDbId}/markerprofiles
function germplasm_markerprofiles(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/germplasm/"+(datum_params.germplasmDbId)+"/markerprofiles";
        delete datum_params.germplasmDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /germplasm/{germplasmDbId}/pedigree
function germplasm_pedigree(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/germplasm/"+(datum_params.germplasmDbId)+"/pedigree";
        delete datum_params.germplasmDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /germplasm/{germplasmDbId}/progeny
function germplasm_progeny(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/germplasm/"+(datum_params.germplasmDbId)+"/progeny";
        delete datum_params.germplasmDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /locations
function locations_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/locations";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /locations/{locationsDbId}
function locations(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/locations/"+datum_params.locationsDbId;
        delete datum_params.locationsDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /maps
function maps_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/maps";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /maps/{mapDbId}
function maps(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/maps/"+datum_params.mapDbId;
        delete datum_params.mapDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /maps/{mapDbId}/positions
function maps_positions_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/maps/"+datum_params.mapDbId+"/positions";
        delete datum_params.mapDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /maps/{mapDbId}/positions/{linkageGroupId}
function maps_positions(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/maps/"+datum_params.mapDbId+"/positions/"+datum_params.linkageGroupId;
        delete datum_params.mapDbId;
        delete datum_params.linkageGroupId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /markerprofiles
function markerprofiles_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/markerprofiles";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /markerprofiles/{markerprofileDbId}
function markerprofiles(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/markerprofiles/"+datum_params.markerprofileDbId;
        delete datum_params.markerprofileDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /markers-search
function markers_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/markers-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /markers/{markerDbId}
function markers(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/markers/"+datum_params.markerDbId;
        delete datum_params.markerDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /observationLevels
function observationLevels(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/observationLevels";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /ontologies
function ontologies(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/ontologies";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /phenotypes-search
function phenotypes_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/phenotypes-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /programs
function programs(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/programs";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /programs-search
function programs_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/programs-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /samples-search
function samples_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/samples-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /samples/{samplesDbId}
function samples(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/samples/"+(datum_params.samplesDbId);
        delete datum_params.samplesDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /seasons
function seasons(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/seasons";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /studies-search
function studies_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}
function studies(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+(datum_params.studiesDbId);
        delete datum_params.studiesDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}/germplasm
function studies_germplasm(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+datum_params.studiesDbId+"/germplasm";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}/layout
function studies_layout(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+datum_params.studiesDbId+"/layout";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}/observations
function studies_observations(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+datum_params.studiesDbId+"/observations";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}/observationunits
function studies_observationunits(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+datum_params.studiesDbId+"/observationunits";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}/observationvariables
function studies_observationvariables(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+datum_params.studiesDbId+"/observationvariables";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studies/{studiesDbId}/table
function studies_table(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studies/"+(datum_params.studiesDbId)+"/table";
        delete datum_params.studiesDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /studytypes
function studytypes(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/studytypes";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /traits 
function traits_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/traits";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /traits/{traitDbId}
function traits(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/traits/"+datum_params.traitDbId;
        delete datum_params.traitDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /trials
function trials_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/trials";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /trials/{trialDbId}
function trials(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/trials/"+datum_params.trialDbId;
        delete datum_params.trialDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// POST /variables-search
function variables_search(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"post",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/variables-search";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /variables
function variables_list(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/variables";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /variables/{variableDbId}
function variables(params){
    return this.brapi_call("map","get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/variables/"+datum_params.variableDbId;
        delete datum_params.variableDbId;
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}

// GET /variables/datatypes
function variables_datatypes(params,behavior){
    var behavior = behavior=="map"?behavior:"fork";
    return this.brapi_call(behavior,"get",function(datum){
        var datum_params = typeof params === "function" ? params(datum) 
                            : Object.assign({}, params);
        var url = "/variables/datatypes";
        return {'url':url, 'params':datum_params};
    }, typeof params === "function");
}



var methods = Object.freeze({
	allelematrix_search: allelematrix_search,
	attributes: attributes,
	attributes_categories: attributes_categories,
	calls: calls,
	crops: crops,
	germplasm_search: germplasm_search,
	germplasm: germplasm,
	germplasm_attributes: germplasm_attributes,
	germplasm_markerprofiles: germplasm_markerprofiles,
	germplasm_pedigree: germplasm_pedigree,
	germplasm_progeny: germplasm_progeny,
	locations_list: locations_list,
	locations: locations,
	maps_list: maps_list,
	maps: maps,
	maps_positions_list: maps_positions_list,
	maps_positions: maps_positions,
	markerprofiles_list: markerprofiles_list,
	markerprofiles: markerprofiles,
	markers_search: markers_search,
	markers: markers,
	observationLevels: observationLevels,
	ontologies: ontologies,
	phenotypes_search: phenotypes_search,
	programs: programs,
	programs_search: programs_search,
	samples_search: samples_search,
	samples: samples,
	seasons: seasons,
	studies_search: studies_search,
	studies: studies,
	studies_germplasm: studies_germplasm,
	studies_layout: studies_layout,
	studies_observations: studies_observations,
	studies_observationunits: studies_observationunits,
	studies_observationvariables: studies_observationvariables,
	studies_table: studies_table,
	studytypes: studytypes,
	traits_list: traits_list,
	traits: traits,
	trials_list: trials_list,
	trials: trials,
	variables_search: variables_search,
	variables_list: variables_list,
	variables: variables,
	variables_datatypes: variables_datatypes
});

var fetchRef;
if (typeof window === 'undefined') {
    fetchRef = require('node-fetch');
} else {
    fetchRef = window.fetch;
}

function parse_json_response(response) {
    return response.json();
}

class BrAPI_Methods {
    constructor(){}
}
for (var method_name in methods) {
    BrAPI_Methods.prototype[method_name] = methods[method_name];
}

class Context_Node extends BrAPI_Methods{
    constructor(parent_list,connection_information,node_type){
        super();
        this.isFinished = false;
        this.ranFinishHooks = false;
        this.node_type = node_type;
        this.parents = parent_list;
        this.async_hooks = [];
        this.catch_hooks = [];
        this.finish_hooks = [];
        this.task_map = {};
        this.connect = connection_information || {};
    }
    
    addTask(task){
        this.task_map[task.getKey()] = task;
    }
    
    getTask(key){
        return this.task_map[key];
    }
    
    getTasks(){
        var self = this;
        return Object.keys(self.task_map).map(function(key) {
			return self.task_map[key];
    	});
    }
    
    publishResult(task){
        this.async_hooks.forEach(function(hook){
            hook(task.getResult(),task.getKey());
        });
        this.checkFinished(true);
    }
    
    addAsyncHook(hook){
        this.async_hooks.push(hook);
        this.getTasks().filter(function(task){
            return task.complete();
        }).forEach(function(task){
            hook(task.getResult(),task.getKey());
        });
    }
    
    addCatchHook(hook){
        this.catch_hooks.push(hook);
    }
    
    addFinishHook(hook){
        this.finish_hooks.push(hook);
        if(this.ranFinishHooks){
            hook(this.getTasks()
                .sort(function(a,b){
                    return a.key <= b.key ? -1 : 1;
                })
                .map(function(task){
                    return task.getResult();
                })
            );
        }
    }
    
    checkFinished(run_on_finish){
        if (!this.isFinished){
            var parsFin = this.parents.every(function(par){return par.checkFinished(false)});
            var thisFin = this.getTasks().every(function(task){return task.complete()});
            this.isFinished = parsFin && thisFin;
        }
        if (run_on_finish && !this.ranFinishHooks && this.isFinished){
            this.ranFinishHooks=true;
            this._onFinish();
        }
        return this.isFinished
    }
    
    _onFinish(){
        var self = this;
        this.finish_hooks.forEach(function(hook){
            hook(self.getTasks()
                .sort(function(a,b){
                    return a.key <= b.key ? -1 : 1;
                })
                .map(function(task){
                    return task.getResult();
                })
            );
        });
    }
    
    fail(reason){
        if (this.catch_hooks.length<1) throw reason;
        else {
            var self = this;
            this.catch_hooks.forEach(function(hook){
                hook(reason,self);
            });
        }
    }
    
    getTaskKeyOrigin(){
        if (this.parents.length<1 
                || this.node_type=="key"
                || this.node_type=="fork" 
                || this.node_type=="reduce"){
            return this;
        } else {
            return this.parents[0].getTaskKeyOrigin();
        }
    }
    
    each(func){ this.addAsyncHook(func); return this;}
    all(func){ this.addFinishHook(func); return this;}
    catch(func){ this.addCatchHook(func); return this;}
    
    keys(keyFunc){
        return new Key_Node(this,this.connect,keyFunc);
    }
    
    fork(forkFunc){
        return new Fork_Node(this,this.connect,forkFunc);
    }
    
    join(/*other,[other]...*/){
        var parent_nodes = [this];
        [].push.apply(parent_nodes,arguments);
        return new Join_Node(parent_nodes,this.connect);
    }
    
    reduce(reductionFunc,initialValue){
        return new Reduce_Node(this,this.connect,reductionFunc,initialValue);
    }
    
    map(mapFunc){
        return new Map_Node(this,this.connect,mapFunc);
    }
    
    filter(filterFunc){
        return new Filter_Node(this,this.connect,filterFunc);
    }
    
    server(server,auth_params){
        return new Connection_Node(this,server,auth_params);
    }
    
    brapi_call(behavior,httpMethod,url_body_func,multicall){
        return new BrAPI_Behavior_Node(
            this,this.connect,behavior,httpMethod,url_body_func,multicall
        );
    }
}

class Filter_Node extends Context_Node{
    constructor(parent,connect,filterFunc){
        super([parent],connect,"filter");
        var self = this;
        parent.addAsyncHook(function(datum, key){
            if(filterFunc(datum)){
                var task = new Task(key);
                self.addTask(task);
                task.complete(datum);
                self.publishResult(task);
            } else if (self.getTasks().length == 0){
                self.checkFinished(true);
            }
        });
    }
}

class Key_Node extends Context_Node{
    constructor(parent,connect,keyFunc){
        super([parent],connect,"key");
        var self = this;
        parent.addAsyncHook(function(datum, previous){
            var task = new Task(keyFunc(datum, previous));
            self.addTask(task);
            task.complete(datum);
            self.publishResult(task);
        });
    }
}

class Map_Node extends Context_Node{
    constructor(parent,connect,mapFunc){
        super([parent],connect,"map");
        var self = this;
        parent.addAsyncHook(function(datum, key){
            var task = new Task(key);
            self.addTask(task);
            task.complete(mapFunc(datum,key));
            self.publishResult(task);
        });
    }
}

class Reduce_Node extends Context_Node{
    constructor(parent,connect,reductionFunc,initialValue){
        super([parent],connect,"reduce");
        var task = new Task(0, "");
        this.addTask(task);
        var self = this;
        parent.addFinishHook(function(data, key){
            var out_datum = reductionFunc==undefined?data:data.reduce(reductionFunc,initialValue);
            task.complete(out_datum);
            self.publishResult(task);
        });
    }
}

class Fork_Node extends Context_Node{
    constructor(parent,connect,forkFunc){
        super([parent],connect,"fork");
        var self = this;
        var forked_key = 0;
        parent.addAsyncHook(function(datum, key){
            var newData = forkFunc(datum);
            var newTasks = [];
            newData.forEach(function(newDatum){
                var task = new Task(forked_key, key);
                forked_key+=1;
                self.addTask(task);
                task.stored_result = newDatum;
                newTasks.push(task);
            });
            newTasks.forEach(function(task){
                task.complete(task.stored_result);
                self.publishResult(task);
            });
        });
    }
}

class Join_Node extends Context_Node{
    constructor(parent_nodes,connect){
        super(parent_nodes,connect,"join");
        var key_origin = parent_nodes[0].getTaskKeyOrigin();
        var different_origins = parent_nodes.some(function(p){
            return p.getTaskKeyOrigin()!==key_origin
        });
        var all_user_keyed = parent_nodes.every(function(p){
            return p.getTaskKeyOrigin().node_type=="key";
        });
        if(different_origins && !all_user_keyed){
            throw "Cannot perform join due to contexts having different key origins!";
            return;
        }
        var self = this;
        parent_nodes.forEach(function(parent,parent_index){
            parent.addAsyncHook(function(datum, key){
                var task = self.getTask(key);
                if(task==undefined){
                    task = new Join_Task(key,parent_nodes.length);
                    self.addTask(task);
                }
                task.addResult(datum,parent_index);
                if (task.complete(true)){
                    self.publishResult(task);
                }
            });
            parent.addFinishHook(function(data){
                self.getTasks().forEach(function(task){
                    if (!task.complete()){
                        var pindex = parent_nodes.indexOf(parent);
                        if (task.result[pindex]===undefined) {
                            task.addResult(null,pindex);
                        }
                        if (task.complete(true)){
                            self.publishResult(task);
                        }
                    }
                });
            });
        });
    }
}

class Connection_Node extends Context_Node{
    constructor(parent,server,auth_params){
        var base_url = server;
        if (base_url.slice(-1)=="/"){
            base_url=base_url.slice(0,-1);
        }
        super([parent],{'server':base_url},"map");
        var requrl = this.connect.server+"/token";
        var self = this;
        if (auth_params){
            fetchRef(requrl, {
                    method: 'post',
                    headers: {
                      'Content-Type': 'application/json;charset=utf-8'
                    },
                    body: JSON.stringify(auth_params)
                })
                .then(parse_json_response)
                .catch(function(reason){
                    self.fail(reason);
                    return null;
                })
                .then(function(json){
                    self.connect['auth']=json;
                    forward();
                });
        } else {
            this.connect['auth']=null;
            forward();
        }
        function forward(){
            parent.addAsyncHook(function(datum, key){
                var task = new Task(key);
                self.addTask(task);
                task.complete(datum);
                self.publishResult(task);
            });
        }
    }
}

class Initial_Connection_Node extends Connection_Node{
    data(dataArray){
        return new Data_Node(this,this.connect,dataArray);
    }
}

class Root_Node extends Context_Node{
    constructor(){
        super([],{},"fork");
        var task = new Task(0, "");
        this.addTask(task);
        task.complete(this.connect);
        this.publishResult(task);
    }
    server(server,auth_params){
        return new Initial_Connection_Node(this,server,auth_params);
    }
    data(dataArray){
        return new Data_Node(this,this.connect,dataArray);
    }
}

class Data_Node extends Context_Node{
    constructor(parent,connect,dataArray){
        super([parent],connect,"fork");
        var self = this;
        dataArray.forEach(function(datum,i){
            var task = new Task(i, "");
            self.addTask(task);
            task.stored_result = datum;
        });
        parent.addFinishHook(function(){
            self.getTasks().forEach(function(task){
                task.complete(task.stored_result);
                self.publishResult(task);
            });
        });
    }
}

class BrAPI_Behavior_Node extends Context_Node{
    constructor(parent,connect,behavior,httpMethod,url_body_func,multicall){
        super([parent],connect,behavior);
        this.behavior = behavior;
        this.d_func = url_body_func;
        this.method = httpMethod;
        var self = this;
        var hookTo = multicall ? parent.addAsyncHook : parent.addFinishHook;
        hookTo.call(parent,function(dat, key){
            var d_call = self.d_func(dat, key);
            if (self.connect.auth!=null && self.connect.auth.access_token){
                d_call.params['access_token'] = self.connect.auth.access_token;
            }
            var pageRange = [0,Infinity];
            if (d_call.params.pageRange){
                pageRange = d_call.params.pageRange;
                delete d_call.params.pageRange;
            }
            var fetch_args = {
                method: d_call.params.HTTPMethod || self.method, 
                headers: {
                    'Content-Type': 'application/json;charset=utf-8'
                }
            };
            key = multicall ? key : 0;
            self.loadPage(pageRange[0],key,d_call,fetch_args,pageRange);
        });
    }
    
    formatURLParams(params){
        var start = true;
        var param_string = "";
        for (var param in params) {
            if (start) {
                param_string+="?";
                start = false;
            } else {
                param_string+="&";
            }
            param_string+=param+"=";
            if (params[param] instanceof Array){
                param_string+=params[param].map(String).join("%2C");
            }
            else {
                param_string+=String(params[param]);
            }
        }
        return param_string
    }
    
    loadPage(page_num,unforked_key,d_call,fetch_args,pageRange,state){
        if (state==undefined){
            state = {
                'is_paginated': undefined,
                'concatenated': undefined,
                'forked_key': 0
            };
        }
        var page_url = d_call.url;
        
        if(page_num>0) d_call.params["page"] = page_num;
        
        if (fetch_args.method=="put"||fetch_args.method=="post"){
            fetch_args["body"] = JSON.stringify(d_call.params);
        }
        else{
            page_url+=this.formatURLParams(d_call.params);
        }
        
        var sentry_task = new Task(unforked_key);
        this.addTask(sentry_task);
        
        var self = this;
        fetchRef(this.connect.server+page_url,fetch_args)
            .then(parse_json_response)
            .catch(function(reason){
                self.fail(reason);
                return null;
            })
            .then(function(json){
                if(json==null){
                    sentry_task.complete(null);
                    self.publishResult(sentry_task);
                    return;
                }
                if(state.is_paginated==undefined){
                    if (json.result.data!=undefined && json.result.data instanceof Array){
                        state.is_paginated = true;
                    } else {
                        state.is_paginated = false;
                    }
                }
                if(state.is_paginated){
                    var final_page = Math.min(+json.metadata.pagination.totalPages-1,pageRange[1])-1;
                    if(self.behavior=="fork"){
                        if (page_num<final_page){
                            self.loadPage(page_num+1,unforked_key,d_call,fetch_args,pageRange,state);
                        }
                        json.result.data.slice(0,-1).forEach(function(datum){
                            var task = new Task(state.forked_key, unforked_key);
                            state.forked_key+=1;
                            datum["__response"] = json;
                            self.addTask(task);
                            task.complete(datum);
                            self.publishResult(task);
                        });
                        sentry_task.setKey(state.forked_key, unforked_key);
                        state.forked_key+=1;
                        sentry_task.complete(json.result.data[json.result.data.length-1]);
                        self.publishResult(sentry_task);
                    }
                    else {
                        if(state.concatenated==undefined){
                            state.concatenated = json;
                            delete state.concatenated.metadata.pagination;
                        } else {
                            [].push.apply(state.concatenated.result.data, json.result.data);
                        }
                        if (page_num<final_page){
                            self.loadPage(page_num+1,unforked_key,d_call,fetch_args,state);
                        } else {
                            state.concatenated.result["__response"] = json;
                            sentry_task.complete(state.concatenated.result);
                            self.publishResult(sentry_task);
                        }
                    }
                }
                else {
                    json.result["__response"] = json;
                    sentry_task.complete(json.result);
                    self.publishResult(sentry_task);
                }
            });
    };
}

function BrAPI(server,auth_params){
    var root = new Root_Node();
    return root.server(server,auth_params);
}

return BrAPI;

})));
