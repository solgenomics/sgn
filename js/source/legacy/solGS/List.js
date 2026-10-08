/**
A list object template with methods for getting details about the list.
Isaak Y Tecle 
iyt2@cornell.edu
*/

class solGSList {
  constructor(listId) {
    if(listId) {
      this.listId = listId;
    }
    this.cxgnList = new CXGN.List();
  }

  getListDetail() {
    return {
      name: this.cxgnList.listNameById(this.listId),
      type: this.cxgnList.getListType(this.listId),
      list_id: this.listId,
    };
  }

  getListElementsIds() {
    var listData = this.cxgnList.getListData(this.listId);
    var listElems = listData.elements;
    var ids = [];
    for (var i = 0; i < listElems.length; i++) {
      ids.push(listElems[i][0]);
    }

    return ids;
  }

  getListElementsNames() {
    var listData = this.cxgnList.getListData(this.listId);
    var listElems = listData.elements;
    var names = [];
    for (var i = 0; i < listElems.length; i++) {
      names.push(listElems[i][1]);
    }

    return names;
  }

  getLists(listTypes) {
    var lists = this.cxgnList.getLists(listTypes);
    var privateLists = this.cxgnList.convertArrayToJson(lists.private_lists);
    privateLists = this.addDataOwnerAttr(privateLists, 'private')
    var publicLists = this.cxgnList.convertArrayToJson(lists.public_lists);
    publicLists = this.addDataOwnerAttr(publicLists, 'public')

    lists = [privateLists, publicLists]

    lists = lists.flat();
  
    return lists;

  }


  addDataStrAttr(lists) {

    for (var i = 0; i < lists.length; i++) {
      if (lists[i]) {
        lists[i]["data_str"] = 'list';
      }
    }

    return lists;
  }

  addDataOwnerAttr(lists, owner) {

    for (var i = 0; i < lists.length; i++) {
      if (lists[i]) {
        lists[i]["owner"] = owner;
      }
    }

    return lists;
  }


  addDataTypeAttr(lists) {

    for (var i = 0; i < lists.length; i++) {
        if (lists[i].type.match(/accessions/)) {
          lists[i]["data_type"] = ["Genotype"];
        } else if (lists[i].type.match(/plots/)) {
          lists[i]["data_type"] = ["Phenotype"];
        } else if (lists[i].type.match(/trials/)) {
          lists[i]["data_type"] = ["Genotype", "Phenotype"];
        }
    
    }
    
    return lists;
  }

}
