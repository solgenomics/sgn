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
    this.CxgnList = new CXGN.List();
  }

  getListDetail() {
    return {
      name: this.CxgnList.listNameById(this.listId),
      type: this.CxgnList.getListType(this.listId),
      list_id: this.listId,
    };
  }

  getListElementsIds() {
    var listData = this.CxgnList.getListData(this.listId);
    var listElems = listData.elements;
    var ids = [];
    for (var i = 0; i < listElems.length; i++) {
      ids.push(listElems[i][0]);
    }

    return ids;
  }

  getListElementsNames() {
    var listData = this.CxgnList.getListData(this.listId);
    var listElems = listData.elements;
    var names = [];
    for (var i = 0; i < listElems.length; i++) {
      names.push(listElems[i][1]);
    }

    return names;
  }

  getLists(listTypes) {
    var lists = this.CxgnList.getLists(listTypes);
    var privateLists = this.CxgnList.convertArrayToJson(lists.private_lists);
    var publicLists = this.CxgnList.convertArrayToJson(lists.public_lists);
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

}
